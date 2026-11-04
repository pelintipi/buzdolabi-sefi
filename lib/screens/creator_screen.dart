import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/recipe_card.dart';
import '../widgets/ui.dart';

/// Videodan kaydedilenler, video sahibine göre (çok kaydedilen önce).
Map<String, List<Recipe>> recipesByCreator(AppState state) {
  final out = <String, List<Recipe>>{};
  for (final r in state.importedRecipes) {
    final a = r.source?.author;
    if (a == null) continue;
    out.putIfAbsent(a, () => []).add(r);
  }
  final sorted = out.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  return Map.fromEntries(sorted);
}

/// "@evdesef'in tarifleri": bir hesaptan kaydedilen bütün tarifler.
class CreatorScreen extends StatelessWidget {
  const CreatorScreen({super.key, required this.author});

  final String author;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final recipes = recipesByCreator(state)[author] ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text('@$author')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(
            children: [
              const SymBubble('🎬', size: 64, color: Palette.tomatoSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@$author\'in tarifleri',
                        style: theme.textTheme.titleLarge),
                    Text('${recipes.length} tarif kaydettin',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final r in recipes)
            RecipeCard(match: state.matcher.evaluate(r, state.snapshot)),
        ],
      ),
    );
  }
}
