import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../services/collections.dart';
import '../services/recipe_matcher.dart';
import '../services/unit_converter.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/profile_dialogs.dart';
import '../widgets/recipe_card.dart' show reviewColor;
import '../widgets/recipe_image.dart';
import '../widgets/share_card.dart';
import '../widgets/ui.dart';
import '../widgets/text_prompt.dart';
import '../widgets/video_source_card.dart';
import 'collections_screen.dart';
import 'cooking_mode_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen(
      {super.key, required this.recipeId, this.savedBanner});

  final String recipeId;

  /// Videodan yeni kaydedildiyse üstte gösterilen onay ("Kaydedildi").
  final String? savedBanner;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late int _servings;
  _Tab _tab = _Tab.ingredients;

  @override
  void initState() {
    super.initState();
    // Ankette "kimin için" cevabı varsa tarif o kadar kişilik açılır.
    final state = context.read<AppState>();
    _servings = state.profile.household?.servings ??
        state.recipeById(widget.recipeId).servings;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskAllergies());
  }

  /// 30 saniye kuralı: alerji sorusu karşılamada değil, ilk tarif açılınca sorulur.
  Future<void> _maybeAskAllergies() async {
    final state = context.read<AppState>();
    if (!mounted || state.profile.allergyAsked) return;
    final result = await showDialog<Set<Allergen>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AllergyDialog(),
    );
    if (result == null) return;
    state.updateProfile(
        state.profile.copyWith(allergies: result, allergyAsked: true));
  }

  void _start(Recipe recipe) {
    final state = context.read<AppState>();
    state.setActiveCooking(
        ActiveCooking(recipeId: recipe.id, servings: _servings, step: 0));
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CookingModeScreen(
          recipeId: recipe.id, servings: _servings, initialStep: 0),
    ));
  }

  Future<void> _rename(Recipe recipe) async {
    final title = await askText(context,
        title: 'Tarifin adı', confirm: 'Kaydet', initial: recipe.title);
    if (title == null || title.trim().isEmpty || !mounted) return;
    context.read<AppState>().saveImported(
        Recipe.fromJson({...recipe.toJson(), 'title': title.trim()}));
  }

  Future<void> _delete(Recipe recipe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarif silinsin mi?'),
        content: Text('"${recipe.title}" kaydettiklerinden çıkarılacak.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final state = context.read<AppState>();
    Navigator.of(context).pop();
    state.deleteImported(recipe.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final recipe = state.tryRecipe(widget.recipeId);
    // Silinen tarifin ekranı kapanırken bir kare daha çizilir.
    if (recipe == null) return const Scaffold();
    final match =
        state.matcher.evaluate(recipe, state.snapshot, servings: _servings);
    final facts = match.facts;
    final scale = _servings / recipe.servings;
    // Listedeki alerjenler ve "Diğer" diye yazılanlara denk gelen malzemeler.
    final conflicts = [
      for (final a in facts.allergens.intersection(state.profile.allergies))
        a.label,
      for (final i in state.matcher.customAllergyHits(recipe, state.profile))
        i.name,
    ];
    final favorite = state.isFavorite(recipe.id);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Sym('🔖', size: 26),
            tooltip: 'Koleksiyona ekle',
            onPressed: () => showAddToCollection(context, recipe.id),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Paylaş',
            onPressed: () => showShareCard(context, recipe),
          ),
          if (recipe.isImported) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Adını değiştir',
              onPressed: () => _rename(recipe),
            ),
            IconButton(
              icon: const Sym('🗑', size: 24),
              tooltip: 'Tarifi sil',
              onPressed: () => _delete(recipe),
            ),
          ],
          IconButton(
            icon: favorite
                ? const Sym('❤', size: 26)
                : const Icon(Icons.favorite_border_rounded),
            tooltip: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
            onPressed: () => state.toggleFavorite(recipe.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          if (widget.savedBanner != null) ...[
            _SavedBanner(
              text: widget.savedBanner!,
              onCollect: () => showAddToCollection(context, recipe.id),
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, c) => RecipeImage(recipe,
                width: c.maxWidth, height: c.maxWidth * 0.68, radius: 26),
          ),
          const SizedBox(height: 16),
          Text(
            [
              categoryOf(recipe).label,
              recipe.difficulty.label,
              if (recipe.isImported) 'Videodan',
            ].join('  ·  ').toUpperCase(),
            style: const TextStyle(
                fontFamily: Fonts.body,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 1.1,
                color: Palette.tomato),
          ),
          const SizedBox(height: 4),
          Text(recipe.title, style: theme.textTheme.headlineMedium),
          if (state.lastCookMemory(recipe.id) case final memory?) ...[
            const SizedBox(height: 12),
            SoftCard(
              color: Palette.butterSoft,
              borderColor: Palette.butter,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Sym('📝', size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            'Geçen sefer',
                            if (memory.rating != null) '${memory.rating}⭐',
                          ].join(' · '),
                          style: theme.textTheme.titleSmall,
                        ),
                        if (memory.note != null)
                          Text(memory.note!, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Süre, kalori, protein ve alet: tek sade satır.
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Meta(Icons.schedule_rounded, '${recipe.minutes} dk'),
              _Meta(Icons.local_fire_department_outlined,
                  '${formatNumber(facts.perServing.kcal, decimals: 0)} kcal'),
              _Meta(Icons.fitness_center_rounded,
                  '${formatNumber(facts.perServing.protein, decimals: 0)} g protein'),
              _Meta(Icons.balance_rounded, facts.review.verdict),
              _Meta(
                  Icons.kitchen_outlined,
                  recipe.appliances.isEmpty
                      ? 'Pişirme yok'
                      : recipe.appliances.map((a) => a.label).join(', ')),
            ],
          ),
          if (recipe.source != null) ...[
            const SizedBox(height: 12),
            VideoSourceCard(source: recipe.source!, recipeTitle: recipe.title),
          ],
          if (conflicts.isNotEmpty) ...[
            const SizedBox(height: 12),
            SoftCard(
              color: Palette.tomatoSoft,
              borderColor: Palette.tomato,
              child: Row(
                children: [
                  const Sym('⚠', size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bu tarif alerjin olan şunları içeriyor: '
                      '${conflicts.join(', ')}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Palette.tomatoText),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _SectionTabs(
            value: _tab,
            stepCount: recipe.steps.length,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 14),
          if (_tab == _Tab.ingredients) ...[
            SectionTitle(
              'Malzemeler',
              icon: '🧺',
              trailing: _ServingStepper(
                value: _servings,
                onChanged: (v) => setState(() => _servings = v),
              ),
            ),
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < match.checks.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _IngredientRow(check: match.checks[i], scale: scale),
                  ],
                ],
              ),
            ),
            if (match.problems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final missing = [
                  for (final c in match.problems) c.item.ingredientId
                ];
                final allListed = missing.every(state.isOnShoppingList);
                return ChunkyButton(
                  label: allListed
                      ? 'Eksikler listende'
                      : 'Eksikleri listeye ekle (${missing.length})',
                  icon: '📝',
                  tone: ChunkyTone.soft,
                  height: 50,
                  onPressed: allListed
                      ? null
                      : () {
                          final added = state.addToShopping(missing);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  '$added malzeme alışveriş listene eklendi')));
                        },
                );
              }),
            ],
          ],
          if (_tab == _Tab.steps) ...[
            const SectionTitle('Yapılışı', icon: '🍳'),
            for (var i = 0; i < recipe.steps.length; i++)
              _StepRow(index: i, step: recipe.steps[i]),
            if (recipe.tip != null) ...[
              const SizedBox(height: 6),
              SoftCard(
                color: Palette.butterSoft,
                borderColor: Palette.butter,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Sym('💡', size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(recipe.tip!,
                            style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ],
          ],
          if (_tab == _Tab.nutrition) ...[
            const SectionTitle('Besin değeri', icon: '📊'),
            _FactsRow(facts: facts),
            const SizedBox(height: 12),
            _DietitianCard(review: facts.review),
            const SizedBox(height: 12),
            _NutritionTable(facts: facts, servings: _servings),
            const SizedBox(height: 10),
            Text(
              [
                if (facts.allergens.isNotEmpty)
                  'İçerir: ${facts.allergens.map((a) => a.label).join(', ')}.',
                'Tahmini değerlerdir; tıbbi tavsiye değildir. Günlük oranlar '
                    'Profil\'deki günlük hedeflerine göredir.',
              ].join(' '),
              style: theme.textTheme.bodySmall,
            ),
            const _HowCalculated(),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ChunkyButton(
            label: 'Pişirmeye başla',
            icon: '🍳',
            tone: ChunkyTone.accent,
            onPressed: () => _start(recipe),
          ),
        ),
      ),
    );
  }
}

class _ServingStepper extends StatelessWidget {
  const _ServingStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, VoidCallback? onTap) =>
        IconButton.filledTonal(
          style: IconButton.styleFrom(
              backgroundColor: Palette.basilSoft,
              foregroundColor: Palette.accentDeep,
              minimumSize: const Size(36, 36)),
          icon: Icon(icon, size: 20),
          tooltip: tip,
          onPressed: onTap,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove_rounded, 'Porsiyonu azalt',
            value > 1 ? () => onChanged(value - 1) : null),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('$value kişilik',
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ),
        btn(Icons.add_rounded, 'Porsiyonu artır',
            value < 12 ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.facts});

  final RecipeFacts facts;

  @override
  Widget build(BuildContext context) {
    final n = facts.perServing;
    Widget tile(String icon, String value, String label, Color color) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Sym(icon, size: 30),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontFamily: Fonts.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Palette.inkSoft)),
              ],
            ),
          ),
        );
    const gap = SizedBox(width: 8);
    return Row(
      children: [
        tile('🔥', formatNumber(n.kcal, decimals: 0), 'kcal',
            Palette.tomatoSoft),
        gap,
        tile('💪', '${formatNumber(n.protein, decimals: 0)} g', 'protein',
            Palette.basilSoft),
        gap,
        tile('🥑', '${formatNumber(n.fat, decimals: 0)} g', 'yağ',
            Palette.butterSoft),
        gap,
        tile('💰', formatMoney(facts.costPerServing), 'maliyet', Palette.sand),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.step});

  final int index;
  final RecipeStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Palette.basil, shape: BoxShape.circle),
            child: Text('${index + 1}',
                style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                Text(step.text, style: Theme.of(context).textTheme.bodyLarge),
                if (step.timerMinutes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Pill('${step.timerMinutes} dk',
                        icon: '⏲', color: Palette.butterSoft, border: null),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.check, required this.scale});

  final ItemCheck check;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppState>().repo;
    final item = check.item;
    final ing = repo.byId(item.ingredientId);
    final amount = item.amount * scale;
    final hint = halfPieceHint(amount, item.measure);
    final (badge, color) = switch (check.state) {
      ItemState.enough => ('Var', Palette.accent),
      ItemState.short => ('Az', Palette.butterText),
      ItemState.missing => item.optional
          ? ('İsteğe bağlı', Palette.inkSoft)
          : ('Yok', Palette.tomato),
      ItemState.substituted => ('Alternatif', Palette.accent),
      ItemState.staple => ('Evde var', Palette.inkSoft),
    };
    final subtitle = <String>[
      if (hint != null) hint,
      switch (check.state) {
        ItemState.short =>
          'Dolabında ${formatBase(ing, UnitConverter.gramsToBase(ing, check.availableGrams))} var',
        ItemState.substituted => check.substitute!.note,
        _ => '',
      },
    ].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          FoodIcon(ing.emoji, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${formatMeasureAmount(amount, item.measure)} ${ing.name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15.5)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(badge,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}

/// Videodan kaydedilince ekranın üstünde görünen yeşil onay.
class _SavedBanner extends StatelessWidget {
  const _SavedBanner({required this.text, required this.onCollect});

  final String text;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Palette.basil,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Sym('✅', size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Colors.white)),
          ),
          TextButton(
            onPressed: onCollect,
            style: TextButton.styleFrom(
                foregroundColor: Palette.butter,
                textStyle: const TextStyle(
                    fontFamily: Fonts.display, fontWeight: FontWeight.w800)),
            child: const Text('Koleksiyona ekle'),
          ),
        ],
      ),
    );
  }
}

enum _Tab { ingredients, steps, nutrition }

/// Tarifin üç parçası arasında geçiş: Malzemeler · Adımlar · Besin değeri.
class _SectionTabs extends StatelessWidget {
  const _SectionTabs(
      {required this.value, required this.stepCount, required this.onChanged});

  final _Tab value;
  final int stepCount;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(_Tab t, String icon, String label) {
      final selected = t == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: GestureDetector(
            onTap: () => onChanged(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Palette.basil : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Sym(icon, size: 26),
                  const SizedBox(height: 2),
                  Text(label,
                      maxLines: 1,
                      style: TextStyle(
                          fontFamily: Fonts.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: selected ? Colors.white : Palette.ink)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Palette.line, width: 1.5),
      ),
      child: Row(
        children: [
          tab(_Tab.ingredients, '🧺', 'Malzemeler'),
          tab(_Tab.steps, '🍳', 'Adımlar ($stepCount)'),
          tab(_Tab.nutrition, '📊', 'Besin değeri'),
        ],
      ),
    );
  }
}

/// "Diyetisyen gözüyle": enerjinin protein, karbonhidrat ve yağa dağılımı,
/// kısa hüküm ve öğünü dengeleme önerileri.
class _DietitianCard extends StatelessWidget {
  const _DietitianCard({required this.review});

  final NutritionReview review;

  static Color get _protein => Palette.accent;
  static const _carb = Palette.butter;
  static const _fat = Color(0xFF6E8B3D);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = [
      ('Protein', review.proteinPct, _protein, '%10-35'),
      ('Karbonhidrat', review.carbPct, _carb, '%45-65'),
      ('Yağ', review.fatPct, _fat, '%20-35'),
    ];
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DİYETİSYEN GÖZÜYLE',
              style: theme.textTheme.labelSmall
                  ?.copyWith(letterSpacing: 1.2, color: Palette.inkSoft)),
          const SizedBox(height: 4),
          Text(review.verdict,
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: reviewColor(review.tone))),
          const SizedBox(height: 4),
          Text(review.summary, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Semantics(
            label: 'Enerjinin yüzde ${review.proteinPct}\'i proteinden, '
                'yüzde ${review.carbPct}\'i karbonhidrattan, '
                'yüzde ${review.fatPct}\'i yağdan geliyor',
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      for (final p in parts)
                        if (p.$2 > 0)
                          Expanded(flex: p.$2, child: Container(color: p.$3)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Row(
              children: [
                for (final p in parts)
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: p.$3, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p.$1} %${p.$2}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5)),
                              Text('önerilen ${p.$4}',
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: Palette.inkSoft)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (review.tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final t in review.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.lightbulb_outline_rounded,
                          size: 17, color: Palette.butterText),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t, style: theme.textTheme.bodySmall)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Porsiyon başı ve seçilen kişi sayısı için toplam; günlük referansa oran.
class _NutritionTable extends StatelessWidget {
  const _NutritionTable({required this.facts, required this.servings});

  final RecipeFacts facts;
  final int servings;

  @override
  Widget build(BuildContext context) {
    final n = facts.perServing;
    // Kişinin kendi hedefleri (Profil > Günlük hedefler). Karbonhidrat ve
    // yağ, 2000 kcal'lik genel referansın (260 g / 70 g) kalori hedefine
    // göre ölçeklenmiş hâli.
    final p = context.watch<AppState>().profile;
    final k = p.dailyKcal / 2000;
    final rows = [
      ('🔥', 'Enerji', n.kcal, 'kcal', p.dailyKcal, Palette.tomato),
      ('💪', 'Protein', n.protein, 'g', p.dailyProtein, Palette.accent),
      ('🍞', 'Karbonhidrat', n.carbs, 'g', 260 * k, Palette.butterDeep),
      ('🌾', 'Lif', n.fiber, 'g', p.dailyFiber, const Color(0xFF8A6A2E)),
      ('🥑', 'Yağ', n.fat, 'g', 70 * k, const Color(0xFF6E8B3D)),
    ];
    final head = TextStyle(
        fontWeight: FontWeight.w800, fontSize: 12.5, color: Palette.inkSoft);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                  width: 78,
                  child: Text('1 porsiyon',
                      textAlign: TextAlign.right, style: head)),
              SizedBox(
                  width: 78,
                  child: Text('$servings kişilik',
                      textAlign: TextAlign.right, style: head)),
            ],
          ),
          for (final r in rows) ...[
            const Divider(height: 18),
            Row(
              children: [
                Sym(r.$1, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.$2,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      ChunkyProgress(
                        value: (r.$3 / r.$5).clamp(0.0, 1.0),
                        color: r.$6,
                        track: Palette.line,
                        height: 8,
                      ),
                      const SizedBox(height: 2),
                      Text('Günlük ihtiyacın %${(r.$3 / r.$5 * 100).round()}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                SizedBox(
                  width: 78,
                  child: Text('${formatNumber(r.$3, decimals: 0)} ${r.$4}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontFamily: Fonts.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
                SizedBox(
                  width: 78,
                  child: Text(
                      '${formatNumber(r.$3 * servings, decimals: 0)} ${r.$4}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Palette.inkSoft)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarif başlığının altındaki tek bir bilgi: ince ikon + yazı.
class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Palette.inkSoft),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(
                fontFamily: Fonts.body,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Palette.ink)),
      ],
    );
  }
}

/// "Bu değerler nasıl hesaplanıyor?": yöntemi ve sınırlarını açıkça söyler
/// (kalori takibi yapan kullanıcı farkı görürse şaşırmasın).
class _HowCalculated extends StatelessWidget {
  const _HowCalculated();

  static const lines = [
    'Tarifteki her malzemenin çiğ hâlinin besin değerleri (USDA besin '
        'tablolarına dayalı) toplanır ve porsiyon sayısına bölünür. '
        'Diyetisyenlerin ve paketli ürünlerin kullandığı yöntem budur.',
    'Pişerken su buharlaşır ve yemek hafifler ama kalori kaybolmaz; bu yüzden '
        'porsiyon başı kalori pişince de geçerlidir. 100 g başına değerler '
        'ise pişmiş yemekte daha yüksek görünür.',
    'Kızartmalarda tavadaki yağın tamamı değil, yemeğin emdiği kadarı '
        '(yaklaşık 3 yemek kaşığı) sayılır.',
    'Fırında ya da ızgarada etten bir miktar yağ süzülür; yağlı etlerde '
        'gerçek değer biraz daha düşük olabilir.',
    'En büyük fark porsiyondan gelir: tencereyi tam eşit bölmezsen ya da '
        'ürünün markası farklıysa değerler yaklaşık %10-20 değişebilir.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        iconColor: Palette.accent,
        collapsedIconColor: Palette.accent,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Icon(Icons.info_outline_rounded, color: Palette.accent),
        title: Text('Bu değerler nasıl hesaplanıyor?',
            style: theme.textTheme.titleSmall),
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $l', style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
