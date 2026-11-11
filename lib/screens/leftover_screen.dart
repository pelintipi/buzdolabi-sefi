import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../models/pantry_item.dart';
import '../services/recipe_matcher.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/recipe_card.dart';
import '../widgets/ui.dart';

/// "Dünden kalan": pişmiş pilav, makarna, tavuk, bayat ekmek... Seçilen artık
/// dolaba 2 günlük eklenir ve onu değerlendiren tarifler gösterilir.
class LeftoverScreen extends StatefulWidget {
  const LeftoverScreen({super.key});

  @override
  State<LeftoverScreen> createState() => _LeftoverScreenState();
}

class _LeftoverScreenState extends State<LeftoverScreen> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    final existing = context.read<AppState>().leftovers;
    if (existing.isNotEmpty) _selected = existing.first.ingredientId;
  }

  void _pick(Ingredient ing, ApproxLevel level) {
    context.read<AppState>().upsertPantry(ing.id, level: level);
    setState(() => _selected = ing.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final options = [
      for (final i in state.repo.all)
        if (i.leftover) i
    ];
    final inPantry = {for (final p in state.leftovers) p.ingredientId: p};

    List<RecipeMatch> usingSelected() {
      final id = _selected;
      if (id == null) return const [];
      final out = [
        for (final m in state.matches(const QuickFilters()))
          if (m.recipe.items
              .any((i) => state.repo.isSameOrDescendant(id, i.ingredientId)))
            m
      ];
      // Artığı asıl malzeme olarak kullananlar önde.
      out.sort((a, b) {
        int rank(RecipeMatch m) =>
            m.recipe.items.any((i) => i.ingredientId == id && i.isMain) ? 0 : 1;
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.problems.length.compareTo(b.problems.length);
      });
      return out;
    }

    final recipes = usingSelected();
    return Scaffold(
      appBar: AppBar(title: const Text('Dünden kalan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('Neyin kaldı?', style: theme.textTheme.headlineSmall),
          Text(
              'Seç, onu değerlendiren tarifleri göstereyim. Dolabına 2 günlük eklenir.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Palette.inkSoft)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: [
              for (final ing in options)
                _LeftoverTile(
                  ingredient: ing,
                  selected: _selected == ing.id,
                  inPantry: inPantry.containsKey(ing.id),
                  onTap: () => _pick(ing, ApproxLevel.biraz),
                ),
            ],
          ),
          if (_selected != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Ne kadar?', style: theme.textTheme.titleMedium),
                const Spacer(),
                for (final level in ApproxLevel.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(switch (level) {
                        ApproxLevel.bol => 'Bolca',
                        ApproxLevel.biraz => 'Yarım',
                        ApproxLevel.az => 'Azıcık',
                      }),
                      selected: inPantry[_selected]?.level == level,
                      onSelected: (_) =>
                          _pick(state.repo.byId(_selected!), level),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SectionTitle(
                '${state.repo.byId(_selected!).name} ile (${recipes.length})',
                icon: '🍽'),
            if (recipes.isEmpty)
              Text('Bununla eşleşen tarif bulamadım.',
                  style: theme.textTheme.bodyMedium)
            else
              for (final m in recipes.take(8)) RecipeCard(match: m),
          ],
        ],
      ),
    );
  }
}

class _LeftoverTile extends StatelessWidget {
  const _LeftoverTile({
    required this.ingredient,
    required this.selected,
    required this.inPantry,
    required this.onTap,
  });

  final Ingredient ingredient;
  final bool selected;
  final bool inPantry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? Palette.basilSoft : Palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: selected ? Palette.accent : Palette.line, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FoodIcon(ingredient.emoji, size: 44),
            const SizedBox(height: 4),
            Text(ingredient.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13, height: 1.1)),
            if (inPantry)
              Text('dolabında',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: Palette.accentDeep)),
          ],
        ),
      ),
    );
  }
}
