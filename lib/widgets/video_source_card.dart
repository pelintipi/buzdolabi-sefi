import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/recipe.dart';
import '../screens/creator_screen.dart';
import '../state/app_state.dart';
import 'package:provider/provider.dart';
import '../theme/palette.dart';
import 'ui.dart';

/// Videonun kapak görseli; yüklenemezse (çevrimdışı) renkli bir yer tutucu.
class VideoThumb extends StatelessWidget {
  const VideoThumb(
      {super.key,
      this.url,
      this.width = 74,
      this.height = 98,
      this.fallbackEmoji = '🎬'});

  final String? url;
  final double width;
  final double height;

  /// Kapak yoksa ortada gösterilen ikon (örn. yemeğin kendi ikonu).
  final String fallbackEmoji;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Palette.tomatoSoft,
      alignment: Alignment.center,
      child: FoodIcon(fallbackEmoji, size: width * 0.55),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? placeholder
            : Image.network(url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : placeholder),
      ),
    );
  }
}

/// Tarif sahibine hak veren kart: kapak, hesap adı ve videoya dönüş linki.
/// Altında tarifin otomatik çıkarıldığı uyarısı ve tanınamayan malzemeler.
class VideoSourceCard extends StatelessWidget {
  const VideoSourceCard({super.key, required this.source});

  final RecipeSource source;

  Future<void> _open(BuildContext context) async {
    final ok = await launchUrl(Uri.parse(source.url),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Video açılamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VideoThumb(url: source.thumbnailUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        source.author == null
                            ? '${source.platform} videosu'
                            : '@${source.author}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium),
                    Text('${source.platform} videosundan kaydedildi',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    ChunkyButton(
                      label: 'Videoyu izle',
                      icon: '▶',
                      tone: ChunkyTone.soft,
                      expand: false,
                      height: 42,
                      onPressed: () => _open(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Palette.butterSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Sym('💡', size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tarifi video açıklamasından otomatik çıkardım. '
                    'Miktarları videoyla bir karşılaştır.',
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: Palette.ink),
                  ),
                ),
              ],
            ),
          ),
          if (source.author != null) _CreatorLink(author: source.author!),
          if (source.unmatched.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Tanıyamadığım malzemeler', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final u in source.unmatched)
                  Pill(u, dense: true, color: Palette.ground),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Aynı hesaptan birden çok tarif kaydedildiyse koleksiyona bağlantı.
class _CreatorLink extends StatelessWidget {
  const _CreatorLink({required this.author});

  final String author;

  @override
  Widget build(BuildContext context) {
    final count =
        recipesByCreator(context.watch<AppState>())[author]?.length ?? 0;
    if (count < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton.icon(
        icon: const Sym('🎬', size: 20),
        label: Text('@$author\'in $count tarifi'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => CreatorScreen(author: author))),
      ),
    );
  }
}
