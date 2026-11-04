import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../services/recipe_matcher.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/recipe_card.dart';
import '../widgets/ui.dart';

const monthNames = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık'
];

/// Bu ay mevsiminde olan sebze-meyveler (Türkiye için yaklaşık).
List<Ingredient> inSeasonNow(AppState state, DateTime now) => [
      for (final i in state.repo.all)
        if (i.inSeason(now.month)) i
    ];

/// Mevsim takvimi: bu ay ucuz ve lezzetli olanlar, onlarla yapılan tarifler.
class SeasonScreen extends StatelessWidget {
  const SeasonScreen({super.key, this.now});

  /// Testlerde sabit tarih için.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final today = now ?? DateTime.now();
    final produce = inSeasonNow(state, today);
    final ids = {for (final p in produce) p.id};
    final recipes = [
      for (final m in state.matches(const QuickFilters()))
        if (m.recipe.items.any((i) => i.isMain && ids.contains(i.ingredientId)))
          m
    ]..sort((a, b) => a.problems.length.compareTo(b.problems.length));

    return Scaffold(
      appBar: AppBar(title: Text('${monthNames[today.month - 1]} mevsimi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('Bu ay mevsiminde', style: theme.textTheme.headlineSmall),
          Text('Mevsiminde olan hem daha ucuz hem daha lezzetli.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Palette.inkSoft)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in produce)
                Pill(p.name,
                    icon: p.emoji,
                    color: state.snapshot.gramsById.containsKey(p.id)
                        ? Palette.basilSoft
                        : Palette.surface),
            ],
          ),
          const SizedBox(height: 18),
          SectionTitle('Mevsim tarifleri (${recipes.length})', icon: '🌱'),
          for (final m in recipes.take(12)) RecipeCard(match: m),
          const SizedBox(height: 6),
          Text('Aylar Türkiye geneli için yaklaşıktır; bölgeye göre değişir.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
