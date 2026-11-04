import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Başka bir uygulamadan (TikTok → Paylaş → Buzdolabı Şefi) gelen içerik.
class SharedPayload {
  const SharedPayload({this.url, this.text});

  /// Paylaşılan metnin içinden link de çıkarılır: "Şuna bak https://vm.tiktok.com/x".
  factory SharedPayload.fromRaw({String? url, String? text}) {
    final found = url ?? _urlIn(text ?? '');
    var rest = text;
    if (found != null && rest != null) {
      rest = rest.replaceAll(found, '').trim();
      if (rest.isEmpty) rest = null;
    }
    return SharedPayload(url: found, text: rest);
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
  Future<VideoInfo?> fetch(String url) async {
    final endpoint = switch (SocialPlatform.of(url)) {
      SocialPlatform.tiktok =>
        Uri.https('www.tiktok.com', '/oembed', {'url': url}),
      SocialPlatform.youtube =>
        Uri.https('www.youtube.com', '/oembed', {'url': url, 'format': 'json'}),
      _ => null,
    };
    if (endpoint == null) return null;
    try {
      final res =
          await _client.get(endpoint).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      String? str(String k) {
        final v = j[k];
        return v is String && v.trim().isNotEmpty ? v.trim() : null;
      }

      return VideoInfo(
        url: url,
        caption: str('title'),
        author: str('author_unique_id') ?? str('author_name'),
        thumbnailUrl: str('thumbnail_url'),
      );
    } catch (e) {
      // Çevrimdışı, gizli video ya da tarayıcıda CORS engeli.
      debugPrint('Video bilgisi alınamadı: $e');
      return null;
    }
  }
}

/// iOS paylaşım eklentisinin (ios/ShareExtension) uygulama grubuna bıraktığı
/// paylaşımları teslim alır. Diğer platformlarda boş döner.
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
