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

  bool get isTikTok {
    final host = Uri.tryParse(url ?? '')?.host ?? '';
    return host == 'tiktok.com' || host.endsWith('.tiktok.com');
  }
}

/// TikTok'un herkese açık oEmbed servisinden gelen video bilgisi.
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

  Future<VideoInfo?> fetch(String url) async {
    final endpoint = Uri.https('www.tiktok.com', '/oembed', {'url': url});
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
