import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/recipe_card.dart';
import '../widgets/recipe_image.dart';
import '../widgets/ui.dart';
import 'recipe_detail_screen.dart';
import 'shopping_screen.dart';

const _dayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// Haftalık plan: dolaptakiler akşamlara paylaştırılır, eksikler tek listede.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final nights = state.planNights;
    // Dolap + önceki akşamların harcadıkları düşülmüş eksikler (tekrarsız).
    final missing = state.planner.missing(nights).toList()
      ..sort((a, b) =>
          state.repo.byId(a).name.compareTo(state.repo.byId(b).name));
    final start = state.planStart ?? DateTime.now();
    final readyCount = nights.where((n) => n.ready).length;
    final unlisted =
        missing.where((id) => !state.isOnShoppingList(id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haftalık plan'),
      ),
      body: nights.isEmpty
          ? _EmptyPlan(nights: state.planLength, onMake: state.makePlan)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                SoftCard(
                  color: Palette.basilSoft,
                  borderColor: Palette.basil,
                  child: Row(
                    children: [
                      const Sym('🗓', size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${nights.length} akşamlık plan',
                                style: theme.textTheme.titleLarge),
                            Text(
                                '$readyCount akşam dolabındakilerle hazır'
                                '${missing.isEmpty ? '' : ' · ${missing.length} malzeme alınacak'}',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < nights.length; i++)
                  Builder(builder: (context) {
                    final day = start.add(Duration(days: i));
                    final n = nights[i];
                    final status = matchStatus(n.match, state.repo);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SoftCard(
                        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    RecipeDetailScreen(recipeId: n.recipe.id))),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 58,
                              child: Column(
                                children: [
                                  Text(_dayShort[day.weekday - 1],
                                      style: const TextStyle(
                                          fontFamily: Fonts.display,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: Palette.basilDeep)),
                                  Text('${day.day}',
                                      style: const TextStyle(
                                          fontFamily: Fonts.display,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 24,
                                          height: 1)),
                                ],
                              ),
                            ),
                            RecipeImage(n.recipe, width: 52, radius: 14),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.recipe.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium),
                                  Text(
                                      '${n.recipe.minutes} dk · ${formatNumber(n.match.facts.perServing.kcal, decimals: 0)} kcal',
                                      style: theme.textTheme.bodySmall),
                                  Text(status.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                          color: status.color)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.swap_horiz_rounded),
                              tooltip: 'Başka tarif',
                              onPressed: () => state.swapPlanNight(i),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 6),
                if (missing.isNotEmpty) ...[
                  const SectionTitle('Bu haftaki planın için şunları al',
                      icon: '🛒'),
                  Text(
                    'Dolabındakiler ve önceki akşamlarda kullanılanlar düşüldü.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < missing.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          Builder(builder: (_) {
                            final ing = state.repo.byId(missing.elementAt(i));
                            final listed = state.isOnShoppingList(ing.id);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  FoodIcon(ing.emoji, size: 36),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(ing.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16)),
                                  ),
                                  if (listed)
                                    const Pill('Listede',
                                        icon: '✓', bordered: false),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ChunkyButton(
                    label: unlisted.isEmpty
                        ? 'Hepsi alışveriş listende'
                        : 'Alışveriş listesine ekle (${unlisted.length})',
                    icon: '📝',
                    tone: ChunkyTone.accent,
                    onPressed: unlisted.isEmpty
                        ? null
                        : () {
                            final added = state.addToShopping(unlisted);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  '$added malzeme alışveriş listene eklendi'),
                              action: SnackBarAction(
                                label: 'Listeye git',
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => const ShoppingScreen()),
                                ),
                              ),
                            ));
                          },
                  ),
                  const SizedBox(height: 10),
                ] else
                  SoftCard(
                    color: Palette.basilSoft,
                    borderColor: Palette.basil,
                    child: Row(
                      children: [
                        const Sym('✅', size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                              'Bu plan için alınacak ekstra malzeme yok; dolabın yetiyor.',
                              style: theme.textTheme.titleSmall),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                ChunkyButton(
                  label: 'Yeniden planla',
                  icon: '🔄',
                  tone: ChunkyTone.soft,
                  height: 50,
                  onPressed: state.makePlan,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bir malzeme bir akşam kullanıldıysa sonraki akşamlarda yeniden "var" '
                  'sayılmaz. Akşam sayısı ankette seçtiğin haftalık hedef kadar.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan({required this.nights, required this.onMake});

  final int nights;
  final VoidCallback onMake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Sym('🗓', size: 110),
          const SizedBox(height: 12),
          Text('Haftanı planlayalım', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Dolabındakilerle $nights akşamlık yemek seçerim; aynı malzemeyi iki kez '
            'saymam, eksikleri tek listede toplarım.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Palette.inkSoft),
          ),
          const SizedBox(height: 20),
          ChunkyButton(
              label: 'Planı çıkar',
              icon: '✨',
              tone: ChunkyTone.accent,
              onPressed: onMake),
        ],
      ),
    );
  }
}
