// Yerel CORS proxy (oembed_proxy.mjs'nin Dart karşılığı): TikTok/YouTube
// oEmbed + kısa link + tikwm (oEmbed çoğu videoda boş title verir).
// Node'u engelleyen güvenlik duvarlarında da çalışsın diye Dart ile çalışır:
//   dart run tool/oembed_proxy.dart
import 'dart:convert';
import 'dart:io';

const port = 8787;

final _client = HttpClient()..userAgent = 'Mozilla/5.0 BuzdolabiSefiProxy/1.0';

bool _isShortTikTok(String url) {
  final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
  return host == 'vm.tiktok.com' ||
      host == 'vt.tiktok.com' ||
      (host == 'www.tiktok.com' && url.contains('/t/'));
}

Future<({int status, String text, Uri url})> _get(String url) async {
  final req = await _client.getUrl(Uri.parse(url));
  req.followRedirects = true;
  req.maxRedirects = 10;
  final res = await req.close().timeout(const Duration(seconds: 15));
  final text = await res.transform(utf8.decoder).join();
  final last =
      res.redirects.isEmpty ? Uri.parse(url) : res.redirects.last.location;
  final finalUrl = last.isAbsolute ? last : Uri.parse(url).resolveUri(last);
  return (status: res.statusCode, text: text, url: finalUrl);
}

String? _youTubeId(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return null;
  if (u.host.toLowerCase().endsWith('youtu.be')) {
    return u.pathSegments.isEmpty ? null : u.pathSegments.first;
  }
  final v = u.queryParameters['v'];
  if (v != null && v.isNotEmpty) return v;
  final seg = u.pathSegments;
  final i = seg.indexWhere((s) => s == 'shorts' || s == 'live' || s == 'embed');
  return i >= 0 && i + 1 < seg.length ? seg[i + 1] : null;
}

Future<String> _getYt(String url) async {
  final req = await _client.getUrl(Uri.parse(url));
  req.headers
    ..set('Accept-Language', 'tr-TR,tr;q=0.9')
    ..set('Cookie', 'CONSENT=YES+1');
  final res = await req.close().timeout(const Duration(seconds: 15));
  return res.transform(utf8.decoder).join();
}

Map<String, dynamic>? _json(String text) {
  try {
    final v = jsonDecode(text);
    return v is Map<String, dynamic> ? v : null;
  } catch (_) {
    return null;
  }
}

String? _nonEmpty(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

Future<String> _resolveUrl(String videoUrl) async {
  if (!_isShortTikTok(videoUrl)) return videoUrl;
  try {
    final r = await _get(videoUrl);
    return r.url.toString();
  } catch (_) {
    return videoUrl;
  }
}

Future<Map<String, dynamic>?> _tikwm(String videoUrl) async {
  final r = await _get(
      'https://www.tikwm.com/api/?url=${Uri.encodeComponent(videoUrl)}');
  final j = _json(r.text);
  if (r.status != 200 || j == null || j['code'] != 0 || j['data'] is! Map) {
    return null;
  }
  final d = j['data'] as Map;
  final title = _nonEmpty(d['title']) ?? _nonEmpty(d['desc']);
  if (title == null) return null;
  final author = d['author'] is Map ? d['author'] as Map : const {};
  return {
    'version': '1.0',
    'type': 'video',
    'title': title,
    'author_unique_id': author['unique_id'] ?? author['nickname'],
    'author_name': author['nickname'],
    'thumbnail_url': d['cover'] ?? d['origin_cover'],
    'provider_name': 'TikTok',
    'provider_url': 'https://www.tiktok.com',
  };
}

Future<Map<String, dynamic>?> _oembedRaw(String videoUrl) async {
  final r = await _get(
      'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(videoUrl)}');
  if (r.status != 200) return null;
  return _json(r.text);
}

/// oEmbed çoğu videoda boş title + kapak verir → tikwm ile açıklama doldurulur.
Future<Map<String, dynamic>?> _tiktok(String videoUrl) async {
  final resolved = await _resolveUrl(videoUrl);
  final oembed = await _oembedRaw(resolved) ??
      (resolved == videoUrl ? null : await _oembedRaw(videoUrl));
  final oembedTitle = _nonEmpty(oembed?['title']);
  if (oembedTitle != null) return oembed;

  final tikwm = await _tikwm(resolved) ??
      (resolved == videoUrl ? null : await _tikwm(videoUrl));
  if (tikwm != null) {
    // Kapak oEmbed'de varsa birleştir.
    if (tikwm['thumbnail_url'] == null && oembed?['thumbnail_url'] != null) {
      tikwm['thumbnail_url'] = oembed!['thumbnail_url'];
    }
    if (tikwm['author_name'] == null && oembed?['author_name'] != null) {
      tikwm['author_name'] = oembed!['author_name'];
    }
    return tikwm;
  }
  // Son çare: yalnızca kapak (açıklama yok).
  return oembed;
}

void _send(HttpResponse res, int status, String body) {
  res.statusCode = status;
  res.headers
    ..set('Content-Type', 'application/json; charset=utf-8')
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Methods', 'GET, OPTIONS')
    ..set('Access-Control-Allow-Headers', '*')
    ..set('Cache-Control', 'no-store');
  res.write(body);
  res.close();
}

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('oembed_proxy (dart) on 0.0.0.0:$port');
  await for (final req in server) {
    final res = req.response;
    if (req.method == 'OPTIONS') {
      _send(res, 204, '');
      continue;
    }
    try {
      final target = req.uri.queryParameters['url'];
      switch (req.uri.path) {
        case '/oembed':
          if (target == null) {
            _send(res, 400, '{"error":"url required"}');
          } else if (RegExp(r'youtube\.com|youtu\.be', caseSensitive: false)
              .hasMatch(target)) {
            final r = await _get('https://www.youtube.com/oembed?url='
                '${Uri.encodeComponent(target)}&format=json');
            _send(res, r.status == 200 ? 200 : r.status, r.text);
          } else {
            final info = await _tiktok(target);
            info == null
                ? _send(res, 404, '{"error":"no info"}')
                : _send(res, 200, jsonEncode(info));
          }
        case '/tikwm':
          if (target == null) {
            _send(res, 400, '{"error":"url required"}');
          } else {
            final resolved = await _resolveUrl(target);
            final info = await _tikwm(resolved) ??
                (resolved == target ? null : await _tikwm(target));
            info == null
                ? _send(res, 404, '{"error":"no caption"}')
                : _send(res, 200, jsonEncode(info));
          }
        case '/ytdesc':
          final id = target == null ? null : _youTubeId(target);
          if (id == null) {
            _send(res, 400, '{"error":"youtube url required"}');
          } else {
            final r = await _getYt('https://www.youtube.com/watch?v=$id&hl=tr');
            final m = RegExp(r'"shortDescription":"((?:[^"\\]|\\.)*)"')
                .firstMatch(r);
            final desc =
                m == null ? null : jsonDecode('"${m.group(1)}"') as String;
            desc == null || desc.trim().isEmpty
                ? _send(res, 404, '{"error":"no description"}')
                : _send(res, 200, jsonEncode({'description': desc}));
          }
        case '/resolve':
          if (target == null) {
            _send(res, 400, '{"error":"url required"}');
          } else {
            final r = await _get(target);
            _send(res, 200, jsonEncode({'url': r.url.toString()}));
          }
        default:
          _send(res, 404, '{"error":"not found"}');
      }
    } catch (e) {
      _send(res, 502, jsonEncode({'error': '$e'}));
    }
  }
}
