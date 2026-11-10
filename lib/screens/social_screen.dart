import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../services/video_import.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/recipe_card.dart';
import '../widgets/ui.dart';
import '../widgets/video_source_card.dart';
import 'creator_screen.dart';
import 'import_recipe_screen.dart';

/// Alt menüdeki "Sosyal" sekmesi: TikTok, Instagram ve YouTube'dan
/// kaydedilen tarifler, platforma göre süzülebilir.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key, this.videoClient});

  final VideoInfoClient? videoClient;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  /// null: hepsi.
  SocialPlatform? _filter;

  static SocialPlatform platformOf(Recipe r) {
    final s = r.source;
    if (s == null) return SocialPlatform.other;
    final byUrl = SocialPlatform.of(s.url);
    return byUrl != SocialPlatform.other
        ? byUrl
        : SocialPlatform.fromLabel(s.platform);
  }

  void _add() => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ImportRecipeScreen(client: widget.videoClient)));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final saved = state.importedRecipes;
    final counts = <SocialPlatform, int>{};
    for (final r in saved) {
      counts.update(platformOf(r), (n) => n + 1, ifAbsent: () => 1);
    }
    final shown = _filter == null
        ? saved
        : [
            for (final r in saved)
              if (platformOf(r) == _filter) r
          ];
    final creators = recipesByCreator(state);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Text('Sosyal medyadan', style: theme.textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(
                'TikTok, Instagram ve YouTube\'da beğendiğin tarifler, '
                'dolabınla karşılaştırılmış halde.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Palette.inkSoft)),
            const SizedBox(height: 16),
            ChunkyButton(
              label: 'Link yapıştır',
              iconData: Icons.link_rounded,
              onPressed: _add,
            ),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Tümü (${saved.length})',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final p in const [
                    SocialPlatform.tiktok,
                    SocialPlatform.instagram,
                    SocialPlatform.youtube,
                  ]) ...[
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '${p.label} (${counts[p] ?? 0})',
                      dot: PlatformBadge.dotColor(p),
                      selected: _filter == p,
                      onTap: () => setState(() => _filter = p),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (saved.isEmpty)
              const _HowTo()
            else if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                    '${_filter!.label}\'dan henüz tarif kaydetmedin. '
                    'Videoda Paylaş → Buzdolabı Şefi\'ne dokunman yeter.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Palette.inkSoft)),
              )
            else ...[
              for (final r in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RecipeCard(
                      match: state.matcher.evaluate(r, state.snapshot)),
                ),
            ],
            if (creators.isNotEmpty) ...[
              const SizedBox(height: 14),
              const SectionTitle('Takip ettiğin şefler', icon: '🧑‍🍳'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in creators.entries.take(8))
                    ActionChip(
                      label: Text('@${e.key} (${e.value.length})'),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => CreatorScreen(author: e.key))),
                    ),
                ],
              ),
            ],
            if (saved.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _HowTo(compact: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.dot});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Palette.basil : Palette.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? Palette.basil : Palette.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: selected && dot == const Color(0xFF1A1A17)
                          ? Colors.white
                          : dot,
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: selected ? Colors.white : Palette.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paylaş menüsüyle nasıl kaydedileceği.
class _HowTo extends StatelessWidget {
  const _HowTo({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String n, String text) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: Palette.sand, shape: BoxShape.circle),
                child: Text(n,
                    style: const TextStyle(
                        fontFamily: Fonts.body,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Palette.basil)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(compact ? 'Nasıl kaydedilir?' : 'Henüz kaydettiğin tarif yok',
              style: TextStyle(
                  fontFamily: Fonts.serif, fontSize: 24, color: Palette.ink)),
          row('1', 'TikTok, Instagram ya da YouTube\'da tarif videosunu aç.'),
          row('2', 'Paylaş\'a dokun, listeden Buzdolabı Şefi\'ni seç.'),
          row('3',
              'Malzemeler ve adımlar çıkarılır, dolabınla karşılaştırılır.'),
          const SizedBox(height: 10),
          Text(
              'Instagram açıklamayı uygulamalara vermiyor; tarif çıkmazsa '
              'açıklamayı kopyalayıp yapıştırman yeterli.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
