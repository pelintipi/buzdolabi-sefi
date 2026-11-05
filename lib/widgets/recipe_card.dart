import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/recipe_detail_screen.dart';
import '../services/ingredient_repository.dart';
import '../services/recipe_matcher.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import 'recipe_image.dart';
import 'ui.dart';

/// Diyetisyen değerlendirmesinin rengi.
Color reviewColor(ReviewTone t) => switch (t) {
      ReviewTone.good => Palette.basil,
      ReviewTone.ok => Palette.inkSoft,
      ReviewTone.caution => const Color(0xFF8A6500),
    };

typedef MatchStatus = ({String icon, String text, Color color, Color soft});

MatchStatus matchStatus(RecipeMatch m, IngredientRepository repo) {
  switch (m.group) {
    case MatchGroup.ready:
      return (
        icon: '✅',
        text: m.maxServings < m.recipe.servings
            ? 'Hemen yapabilirsin · ${formatNumber(m.maxServings)} porsiyon çıkar'
            : 'Hemen yapabilirsin',
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

/// Kartta süre, kalori, protein, diyetisyen hükmü ve eşleşme durumu.
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

    final n = match.facts.perServing;
    final meta = [
      '${recipe.minutes} dk',
      '${formatNumber(n.kcal, decimals: 0)} kcal',
      '${formatNumber(n.protein, decimals: 0)} g protein',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => RecipeDetailScreen(recipeId: recipe.id))),
        child: Row(
          children: [
            RecipeImage(recipe, width: 84, radius: 16),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (highlights.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        highlights
                            .map((h) => h.label)
                            .join(' · ')
                            .toUpperCase(),
                        style: const TextStyle(
                            fontFamily: Fonts.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            letterSpacing: 0.8,
                            color: Palette.tomato),
                      ),
                    ),
                  Text(recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 3),
                  Text(n.kcal > 0 ? match.facts.review.verdict : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: reviewColor(match.facts.review.tone))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: status.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(status.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: Fonts.body,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                color: status.color)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                  favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: favorite ? Palette.tomato : Palette.lineDeep),
              tooltip: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
              onPressed: () => state.toggleFavorite(recipe.id),
            ),
          ],
        ),
      ),
    );
  }
}
