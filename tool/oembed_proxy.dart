// Yerel CORS proxy (oembed_proxy.mjs'nin Dart karşılığı): TikTok/YouTube
// oEmbed + kısa link. Node'u engelleyen güvenlik duvarlarında da çalışsın
// diye Flutter ile gelen Dart ile çalışır:
//   dart run tool/oembed_proxy.dart
import 'dart:convert';
import 'dart:io';

const port = 8787;

final _client = HttpClient()..userAgent = 'Mozilla/5.0 BuzdolabiSefiProxy/1.0';

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

Map<String, dynamic>? _json(String text) {
  try {
    final v = jsonDecode(text);
    return v is Map<String, dynamic> ? v : null;
  } catch (_) {
    return null;
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
  final title = ((d['title'] ?? d['desc'] ?? '') as String).trim();
  if (title.isEmpty) return null;
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

Future<Map<String, dynamic>?> _tiktok(String videoUrl) async {
  final r = await _get(
      'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(videoUrl)}');
  final j = _json(r.text);
  final title = j?['title'];
  if (r.status == 200 && title is String && title.trim().isNotEmpty) return j;
  // oEmbed çoğu videoda başlık vermiyor → tikwm.
  return await _tikwm(videoUrl) ?? j;
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
