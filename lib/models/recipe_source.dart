/// Videodan kaydedilen bir tarifin nereden geldiği. Tarif sahibine hak vermek
/// için hesap adı ve video linki tarifle birlikte saklanır.
class RecipeSource {
  const RecipeSource({
    required this.url,
    this.platform = 'TikTok',
    this.author,
    this.thumbnailUrl,
    this.caption,
    this.unmatched = const [],
  });

  final String url;
  final String platform;

  /// "@kullaniciadi" olmadan, sadece ad.
  final String? author;
  final String? thumbnailUrl;

  /// Tarifin çıkarıldığı ham açıklama metni.
  final String? caption;

  /// Açıklamada geçen ama kataloğumuzda karşılığı bulunamayan satırlar.
  final List<String> unmatched;

  Map<String, dynamic> toJson() => {
        'url': url,
        'platform': platform,
        if (author != null) 'author': author,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (caption != null) 'caption': caption,
        if (unmatched.isNotEmpty) 'unmatched': unmatched,
      };

  factory RecipeSource.fromJson(Map<String, dynamic> j) => RecipeSource(
        url: j['url'] as String,
        platform: j['platform'] as String? ?? 'TikTok',
        author: j['author'] as String?,
        thumbnailUrl: j['thumbnailUrl'] as String?,
        caption: j['caption'] as String?,
        unmatched: [
          for (final u in (j['unmatched'] as List? ?? const [])) u as String
        ],
      );
}
