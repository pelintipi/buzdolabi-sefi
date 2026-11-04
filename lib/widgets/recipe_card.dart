import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/recipe_detail_screen.dart';
import '../services/ingredient_repository.dart';
import '../services/recipe_matcher.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import 'ui.dart';

typedef MatchStatus = ({String icon, String text, Color color, Color soft});

MatchStatus matchStatus(RecipeMatch m, IngredientRepository repo) {
  switch (m.group) {
    case MatchGroup.ready:
      return (
        icon: '✅',
        text: 'Hemen yapabilirsin',
        color: Palette.basilDeep,
        soft: Palette.basilSoft,
      );
    case MatchGroup.substitute:
      final c = m.checks.firstWhere(
          (c) => !c.item.optional && c.state == ItemState.substituted);
      return (
        icon: '🔄',
        text: '${repo.byId(c.item.ingredientId).name} yerine '
            '${repo.byId(c.substitute!.ingredientId).name}',
        color: Palette.basilDeep,
        soft: Palette.basilSoft,
      );
    case MatchGroup.almost:
      final b = m.blocking!;
      final name = repo.byId(b.item.ingredientId).name;
      final text = b.state == ItemState.missing
          ? 'Sadece $name eksik'
          : m.maxServings >= 1
              ? '$name az · ${formatNumber(m.maxServings)} porsiyon yapabilirsin'
              : '$name yetersiz';
      return (
        icon: '🤏',
        text: text,
        color: const Color(0xFF8A6500),
        soft: Palette.butterSoft,
      );
    case MatchGroup.far:
      return (
        icon: '🛒',
        text: '${m.problems.length} malzeme eksik',
        color: Palette.tomatoDeep,
        soft: Palette.tomatoSoft,
      );
  }
}

/// Kartta yalnızca 3 ana bilgi: süre, protein, eşleşme durumu.
class RecipeCard extends StatelessWidget {
  const RecipeCard(
      {super.key, required this.match, this.highlights = const {}});

  final RecipeMatch match;

  /// "En hızlı", "En proteinli" gibi rozetler.
  final Set<Highlight> highlights;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final recipe = match.recipe;
    final favorite = state.isFavorite(recipe.id);
    final status = matchStatus(match, state.repo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => RecipeDetailScreen(recipeId: recipe.id))),
        child: Row(
          children: [
            IconBubble(recipe.emoji, size: 68, color: status.soft),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (highlights.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final h in highlights)
                            Pill(h.label,
                                icon: h.icon,
                                dense: true,
                                color: Palette.butter,
                                border: null),
                        ],
                      ),
                    ),
                  Text(recipe.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  // Üç değer tek satırda kalsın; dar ekranda biraz küçülür.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Pill('${recipe.minutes} dk', icon: '⏱', dense: true),
                        const SizedBox(width: 5),
                        Pill(
                            '${formatNumber(match.facts.perServing.protein, decimals: 0)} g',
                            icon: '💪',
                            dense: true),
                        const SizedBox(width: 5),
                        Pill(
                            '${formatNumber(match.facts.perServing.kcal, decimals: 0)} kcal',
                            icon: '🔥',
                            dense: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FoodIcon(status.icon, size: 18),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(status.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: status.color)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: favorite
                  ? const FoodIcon('❤', size: 26)
                  : const Icon(Icons.favorite_border_rounded,
                      color: Palette.lineDeep),
              tooltip: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
              onPressed: () => state.toggleFavorite(recipe.id),
            ),
          ],
        ),
      ),
    );
  }
}
