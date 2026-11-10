import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Başka bir uygulamadan (TikTok → Paylaş → Buzdolabı Şefi) gelen içerik.
class SharedPayload {
  const SharedPayload({this.url, this.text});

  /// Paylaşılan metnin içinden link de çıkarılır: "Şuna bak https://vm.tiktok.com/x".
  /// Link kutusuna "url + malzemeler" yapıştırılırsa URL ayrılır, kalan metin
  /// tarif metni sayılır (eski davranış tüm satırı URL sanıyordu).
  factory SharedPayload.fromRaw({String? url, String? text}) {
    final found = _urlIn(url ?? '') ?? _urlIn(text ?? '');
    final parts = <String>[
      if (url != null && url.trim().isNotEmpty) url.trim(),
      if (text != null && text.trim().isNotEmpty) text.trim(),
    ];
    var rest = parts.join('\n');
    if (found != null) {
      rest = rest.replaceAll(found, '').trim();
    }
    return SharedPayload(url: found, text: rest.isEmpty ? null : rest);
  }

  final String? url;
  final String? text;

  static final _urlRe = RegExp(r'https?://[^\s<>"]+');
  static String? _urlIn(String s) => _urlRe.firstMatch(s)?.group(0);

  SocialPlatform get platform => SocialPlatform.of(url);

  bool get isTikTok => platform == SocialPlatform.tiktok;
}

/// Tarifin paylaşıldığı sosyal medya. Link adresinden anlaşılır.
enum SocialPlatform {
  tiktok('TikTok'),
  instagram('Instagram'),
  youtube('YouTube'),
  other('Video');

  const SocialPlatform(this.label);

  final String label;

  static SocialPlatform of(String? url) {
    final host = (Uri.tryParse(url ?? '')?.host ?? '').toLowerCase();
    bool on(String d) => host == d || host.endsWith('.$d');
    if (on('tiktok.com')) return tiktok;
    if (on('instagram.com') || on('instagr.am')) return instagram;
    if (on('youtube.com') || on('youtu.be')) return youtube;
    return other;
  }

  /// Kayıtlı tarifteki platform adından (eski kayıtlar "TikTok" ya da "Video").
  static SocialPlatform fromLabel(String label) =>
      values.firstWhere((p) => p.label.toLowerCase() == label.toLowerCase(),
          orElse: () => other);
}

/// TikTok ve YouTube'un herkese açık oEmbed servisinden gelen video bilgisi.
class VideoInfo {
  const VideoInfo(
      {required this.url, this.caption, this.author, this.thumbnailUrl});

  final String url;

  /// Videonun açıklaması (TikTok oEmbed'de "title" alanı).
  final String? caption;
  final String? author;
  final String? thumbnailUrl;
}

/// Video linkinden açıklama, hesap adı ve kapak görselini getirir.
/// Video dosyası indirilmez; yalnızca TikTok'un yerleştirme (embed) için
/// herkese açtığı bilgiler kullanılır.
class VideoInfoClient {
  VideoInfoClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// TikTok açıklamanın tamamını verir; YouTube yalnızca başlığı verir.
  /// Instagram'ın servisi geliştirici anahtarı istediği için çağrılmaz;
  /// orada açıklama kullanıcıdan alınır.
  ///
  /// Web'de tarayıcı CORS TikTok'u engeller; oEmbed isteği açık proxy üzerinden
  /// gider. Yerelde (mobil/desktop) doğrudan çağrılır.
  Future<VideoInfo?> fetch(String url) async {
    final platform = SocialPlatform.of(url);
    if (platform != SocialPlatform.tiktok &&
        platform != SocialPlatform.youtube) {
      return null;
    }
    // Önce verilen adresi dene (vt.tiktok.com oEmbed'de çoğu zaman yeter);
    // olmazsa kısa linki açıp tekrar dene.
    final candidates = <String>[url];
    final resolved = await _resolve(url);
    if (resolved != url) candidates.add(resolved);

    for (final candidate in candidates) {
      final info = await _oembed(candidate, platform);
      if (info != null) return info;
    }
    return null;
  }

  Future<VideoInfo?> _oembed(String url, SocialPlatform platform) async {
    final endpoint = switch (platform) {
      SocialPlatform.tiktok =>
        Uri.https('www.tiktok.com', '/oembed', {'url': url}),
      SocialPlatform.youtube =>
        Uri.https('www.youtube.com', '/oembed', {'url': url, 'format': 'json'}),
      _ => null,
    };
    if (endpoint == null) return null;
    try {
      final res = await _getJson(endpoint);
      if (res == null) return null;
      String? str(String k) {
        final v = res[k];
        if (v is! String) return null;
        final t = _unescape(v).trim();
        return t.isEmpty ? null : t;
      }

      return VideoInfo(
        url: url,
        caption: str('title'),
        author: str('author_unique_id') ?? str('author_name'),
        thumbnailUrl: str('thumbnail_url'),
      );
    } catch (e) {
      debugPrint('Video bilgisi alınamadı: $e');
      return null;
    }
  }

  /// Web'de yerel oembed_proxy (tool/oembed_proxy.mjs :8787); native'de doğrudan.
  Future<Map<String, dynamic>?> _getJson(Uri endpoint) async {
    final target = kIsWeb
        ? _proxyUri('/oembed', endpoint.queryParameters['url'] ?? '')
        : endpoint;
    final res = await _client.get(target).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final body = utf8.decode(res.bodyBytes).trim();
    if (body.isEmpty) return null;
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// Web tarayıcısından LAN'daki proxy: aynı host, port 8787.
  static Uri _proxyUri(String path, String videoUrl) {
    final base = Uri.base;
    return Uri(
      scheme: base.scheme.isEmpty ? 'http' : base.scheme,
      host: base.host.isEmpty ? '127.0.0.1' : base.host,
      port: 8787,
      path: path,
      queryParameters: {'url': videoUrl},
    );
  }

  /// vm/vt.tiktok.com kısa linklerini açıp kalıcı video adresine çevirir.
  Future<String> _resolve(String url) async {
    final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
    final short = host == 'vm.tiktok.com' ||
        host == 'vt.tiktok.com' ||
        (host == 'www.tiktok.com' && url.contains('/t/'));
    if (!short) return url;
    try {
      if (kIsWeb) {
        final res = await _client
            .get(_proxyUri('/resolve', url))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final j = jsonDecode(utf8.decode(res.bodyBytes));
          if (j is Map && j['url'] is String) return j['url'] as String;
        }
      } else {
        final res = await _client.get(Uri.parse(url), headers: const {
          'User-Agent': 'Mozilla/5.0'
        }).timeout(const Duration(seconds: 8));
        final finalUrl = res.request?.url.toString();
        if (finalUrl != null && finalUrl.isNotEmpty) return finalUrl;
      }
    } catch (e) {
      debugPrint('Kısa link açılamadı: $e');
    }
    return url;
  }

  static String _unescape(String s) => s
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
        final code = int.tryParse(m.group(1)!);
        return code == null ? m.group(0)! : String.fromCharCode(code);
      });
}

/// iOS ShareExtension / Android ACTION_SEND ile gelen paylaşımları teslim alır
/// (kanal: `buzdolabi_sefi/share`). Web'de boş döner.
class ShareInbox {
  const ShareInbox();

  static const _channel = MethodChannel('buzdolabi_sefi/share');

  Future<List<SharedPayload>> takePending() async {
    try {
      final list = await _channel.invokeListMethod<Object?>('takePending');
      return [
        for (final item in list ?? const <Object?>[])
          if (item is Map)
            SharedPayload.fromRaw(
                url: item['url'] as String?, text: item['text'] as String?),
      ].where((p) => p.url != null || p.text != null).toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      debugPrint('Paylaşımlar okunamadı: $e');
      return const [];
    }
  }
}
