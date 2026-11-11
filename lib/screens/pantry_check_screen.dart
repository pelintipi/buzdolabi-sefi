import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pantry_item.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/ui.dart';
import 'pantry_screen.dart' show pantryAmountText;

/// Dolap kontrolü: bir haftadır dokunulmayan malzemeler tek tek, tek
/// dokunuşla "Hâlâ var / Azaldı / Bitti". Uygulamayı açmadan pişirilen
/// yemekler yüzünden dolap gerçeklikten uzaklaşmasın diye.
class PantryCheckScreen extends StatefulWidget {
  const PantryCheckScreen({super.key});

  @override
  State<PantryCheckScreen> createState() => _PantryCheckScreenState();
}

class _PantryCheckScreenState extends State<PantryCheckScreen> {
  // Ekran açıkken liste sabit kalsın; cevaplananlar işaretlenir.
  late final List<PantryItem> _items = context.read<AppState>().staleItems;
  final _answers = <String, String>{};

  void _answer(PantryItem item, String answer) {
    final state = context.read<AppState>();
    final before = List<PantryItem>.of(state.pantry);
    switch (answer) {
      case 'var':
        state.confirmPantryItem(item.id);
      case 'azaldi':
        state.reducePantryItem(item.id);
      case 'bitti':
        state.removePantryItem(item.id);
    }
    setState(() => _answers[item.id] = answer);
    if (answer == 'bitti') {
      final name = state.repo.byId(item.ingredientId).name;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 6),
          persist: false,
          content: Text('$name dolaptan çıkarıldı'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () {
              state.restorePantry(before);
              setState(() => _answers.remove(item.id));
            },
          ),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final left = _items.where((p) => !_answers.containsKey(p.id)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Dolap kontrolü')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            left == 0
                ? 'Hepsi güncel. Öneriler artık dolabına daha uygun.'
                : 'Bu malzemelere bir haftadır bakmadın. Hâlâ duruyorlar mı? '
                    '($left kaldı)',
            style: theme.textTheme.bodyMedium?.copyWith(color: Palette.inkSoft),
          ),
          const SizedBox(height: 12),
          for (final item in _items)
            Builder(builder: (_) {
              final ing = state.repo.byId(item.ingredientId);
              final current =
                  state.pantry.where((p) => p.id == item.id).firstOrNull;
              final answer = _answers[item.id];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: answer == null ? 1 : 0.55,
                  child: SoftCard(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconBubble(ing.emoji, size: 48),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ing.name,
                                      style: theme.textTheme.titleMedium),
                                  Text(
                                    switch (answer) {
                                      'var' => 'Tamam, duruyor',
                                      'azaldi' =>
                                        'Azaldı: ${pantryAmountText(current ?? item, ing)}',
                                      'bitti' => 'Bitti, çıkarıldı',
                                      _ => pantryAmountText(item, ing),
                                    },
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Palette.inkSoft),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (answer == null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (final (key, label) in const [
                                ('var', 'Hâlâ var'),
                                ('azaldi', 'Azaldı'),
                                ('bitti', 'Bitti'),
                              ]) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: key == 'bitti'
                                          ? Palette.tomatoText
                                          : Palette.ink,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                    ),
                                    onPressed: () => _answer(item, key),
                                    child: Text(label,
                                        maxLines: 1, softWrap: false),
                                  ),
                                ),
                                if (key != 'bitti') const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          if (left == 0) ...[
            const SizedBox(height: 8),
            ChunkyButton(
              label: 'Tamam',
              tone: ChunkyTone.accent,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dolabım'ın üstünde: kontrol edilmesi gereken malzeme varsa.
class PantryCheckBanner extends StatelessWidget {
  const PantryCheckBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final stale = context.watch<AppState>().staleItems;
    if (stale.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: SoftCard(
        color: Palette.butterSoft,
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PantryCheckScreen())),
        child: Row(
          children: [
            const Sym('🧺', size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dolabını kontrol et',
                      style: theme.textTheme.titleMedium),
                  Text(
                    '${stale.length} malzemeye bir haftadır bakmadın. '
                    'Hâlâ duruyorlar mı? 30 saniye sürer.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
