import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pantry_item.dart';
import '../models/user_profile.dart';
import '../services/collections.dart' show DishKind, kindOf;
import '../services/recipe_matcher.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/recipe_card.dart';
import '../widgets/recipe_image.dart';
import '../widgets/ui.dart';
import 'ingredient_input_screen.dart';
import 'recipe_detail_screen.dart';

/// Ana sayfadaki "Ne pişirsem?" butonu: dolap boşsa önce malzeme girişi.
void openWhatToCook(BuildContext context) {
  final empty = context.read<AppState>().pantry.isEmpty;
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => empty
        ? const IngredientInputScreen(openResultsAfter: true)
        : const ResultsScreen(),
  ));
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  QuickFilters _filters = const QuickFilters();
  // Ankette "protein ağırlıklı" ya da "hafif" diyenlere o sıra açılır.
  late SortMode _sort = switch (context.read<AppState>().profile.eating) {
    EatingStyle.protein => SortMode.protein,
    EatingStyle.light => SortMode.light,
    _ => SortMode.recommended,
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final all = state.matches(_filters);
    // Tür filtresi seçili değilse tatlı ve atıştırmalıklar yemeklerle
    // karışmaz; aşağıda kendi bölümlerinde gösterilir.
    final split = _filters.kind == null;
    final matches = split
        ? [
            for (final m in all)
              if (kindOf(m.recipe) == DishKind.meal) m
          ]
        : all;
    List<RecipeMatch> extras(DishKind k) {
      if (!split) return const [];
      const order = [
        MatchGroup.ready,
        MatchGroup.substitute,
        MatchGroup.almost
      ];
      return [
        for (final g in order)
          for (final m in all)
            if (m.group == g && kindOf(m.recipe) == k) m
      ];
    }

    final snacks = extras(DishKind.snack);
    final desserts = extras(DishKind.dessert);
    List<RecipeMatch> group(MatchGroup g) => [
          for (final m in matches)
            if (m.group == g) m
        ];
    final ready = group(MatchGroup.ready);
    final substitute = group(MatchGroup.substitute);
    final almost = group(MatchGroup.almost);
    final far = group(MatchGroup.far);
    final suggestions = state.matcher.unlockSuggestions(matches);
    final nothingClose = ready.isEmpty && substitute.isEmpty && almost.isEmpty;
    final nothingAtAll = nothingClose && snacks.isEmpty && desserts.isEmpty;
    // Karşılaştırma ve rozetler önce şu an yapılabilenler arasında yapılır;
    // yapılabilen 2'den azsa tek malzemesi eksik olanlar da katılır.
    final makeable = [...ready, ...substitute];
    final options = [...makeable, ...almost];
    final compared = makeable.length >= 2 ? makeable : options;
    final highlights = highlightsFor(compared);
    // Sıralamada yapılabilenler her zaman önce gelir.
    final sorted = [
      ...sortOptions(makeable, _sort),
      ...sortOptions(almost, _sort)
    ];
    final sortedCompared = sortOptions(compared, _sort);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ne pişirsem?'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Malzemeleri düzenle',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const IngredientInputScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _Summary(
            ready: ready,
            substitute: substitute,
            almost: almost,
            filtered: !_filters.isEmpty,
          ),
          const SizedBox(height: 14),
          _KindBar(
            value: _filters.kind,
            onChanged: (k) => setState(() => _filters = _filters.withKind(k)),
          ),
          const SizedBox(height: 10),
          _FilterBar(
            filters: _filters,
            onChanged: (f) => setState(() => _filters = f),
          ),
          if (compared.length >= 2) ...[
            const SizedBox(height: 14),
            _CompareCard(options: sortedCompared.take(5).toList()),
          ],
          if (suggestions.isNotEmpty && ready.length < 3) ...[
            const SizedBox(height: 14),
            _UnlockBanner(suggestion: suggestions.first),
          ],
          if (options.length >= 2) ...[
            const SizedBox(height: 14),
            _SortBar(value: _sort, onChanged: (s) => setState(() => _sort = s)),
          ],
          if (nothingAtAll)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Sym('🤔', size: 72),
                  const SizedBox(height: 8),
                  Text(
                    _filters.isEmpty
                        ? 'Şu an tam eşleşen tarif yok. Dolabına birkaç malzeme daha ekle.'
                        : _filters.kind != null &&
                                _filters.withKind(null).isEmpty
                            ? 'Bu malzemelerle şu an yapabileceğin '
                                '${_filters.kind!.label.toLowerCase()} yok. '
                                'Bir iki malzeme eklersen açılır.'
                            : 'Bu filtrelerle eşleşen tarif yok. Filtreleri gevşetmeyi dene.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  ChunkyButton(
                    label: 'Malzeme ekle',
                    icon: '🧺',
                    tone: ChunkyTone.soft,
                    expand: false,
                    height: 48,
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const IngredientInputScreen())),
                  ),
                ],
              ),
            ),
          if (_sort == SortMode.recommended) ...[
            ..._section('Hemen yapabilirsin', '✅', ready, highlights),
            ..._section(
                'Alternatifle yapabilirsin', '🔄', substitute, highlights),
            ..._section('Az kaldı', '🤏', almost, highlights),
          ] else
            ..._section('${_sort.label} önce', _sort.icon, sorted, highlights),
          ..._extraSection(DishKind.snack, snacks),
          ..._extraSection(DishKind.dessert, desserts),
          if (far.isNotEmpty)
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Sym('🛒', size: 30),
                title: Text('Biraz alışverişle (${far.length})',
                    style: theme.textTheme.titleLarge),
                initiallyExpanded: nothingClose,
                children: [for (final m in far.take(8)) RecipeCard(match: m)],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _section(String title, String icon, List<RecipeMatch> items,
      Map<String, Set<Highlight>> highlights) {
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      SectionTitle('$title (${items.length})', icon: icon),
      for (final m in items)
        RecipeCard(match: m, highlights: highlights[m.recipe.id] ?? const {}),
    ];
  }

  /// Atıştırmalık ve tatlılar: yapılabilenler önce, ilk 4'ü gösterilir;
  /// fazlası tür filtresiyle açılır.
  List<Widget> _extraSection(DishKind kind, List<RecipeMatch> items) {
    if (items.isEmpty) return const [];
    final ready = items.where((m) => m.group != MatchGroup.almost).length;
    final note = ready == items.length
        ? 'hepsi hazır'
        : ready == 0
            ? '1 malzeme eksik'
            : '$ready hazır';
    return [
      const SizedBox(height: 18),
      SectionTitle('${kind.label} (${items.length})',
          icon: kind.icon,
          trailing: TextButton(
            onPressed: () => setState(() => _filters = _filters.withKind(kind)),
            child: Text(items.length > 4 ? 'Tümü' : note),
          )),
      for (final m in items.take(4)) RecipeCard(match: m),
    ];
  }
}

/// Yemek / atıştırmalık / tatlı ayrımı.
class _KindBar extends StatelessWidget {
  const _KindBar({required this.value, required this.onChanged});

  final DishKind? value;
  final ValueChanged<DishKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String icon, String label, DishKind? kind) {
      final on = value == kind;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Sym(icon, size: 20, color: on ? Colors.white : null),
          label: Text(label),
          selected: on,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          selectedColor: Palette.basil,
          labelStyle: TextStyle(
              fontFamily: Fonts.body,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: on ? Colors.white : Palette.ink),
          side: BorderSide(color: on ? Palette.basil : Palette.line, width: 2),
          onSelected: (_) => onChanged(kind),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          chip('✨', 'Hepsi', null),
          for (final k in DishKind.values) chip(k.icon, k.short, k),
        ],
      ),
    );
  }
}

/// "Seçeneklerini karşılaştır": süre, protein ve kalori yan yana; her
/// sütunun en iyisi sarıyla vurgulanır.
class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.options});

  final List<RecipeMatch> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minMinutes =
        options.map((m) => m.recipe.minutes).reduce((a, b) => a < b ? a : b);
    final maxProtein = options
        .map((m) => m.facts.perServing.protein.round())
        .reduce((a, b) => a > b ? a : b);
    final minKcal = options
        .map((m) => m.facts.perServing.kcal.round())
        .reduce((a, b) => a < b ? a : b);

    Widget cell(String text, bool best) => SizedBox(
          width: 62,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: best ? Palette.butter : null,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(text,
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Palette.ink,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
          ),
        );
    Widget head(String icon, String label) => SizedBox(
          width: 62,
          child: Column(
            children: [
              Sym(icon, size: 24),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        );

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Sym('📊', size: 28),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Seçeneklerini karşılaştır',
                      style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              head('⏱', 'dakika'),
              head('💪', 'protein'),
              head('🔥', 'kcal'),
            ],
          ),
          for (final m in options)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => RecipeDetailScreen(recipeId: m.recipe.id))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    RecipeImage(m.recipe, width: 32, radius: 9),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.recipe.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14)),
                          Text(
                              [
                                m.facts.review.verdict,
                                if (m.group == MatchGroup.almost) '1 eksik',
                              ].join(' · '),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: m.group == MatchGroup.almost
                                      ? Palette.tomatoDeep
                                      : reviewColor(m.facts.review.tone))),
                        ],
                      ),
                    ),
                    cell('${m.recipe.minutes}', m.recipe.minutes == minMinutes),
                    // Sarı vurgu yalnızca gerçekten iyi değere: 5 g protein
                    // en yüksek olsa bile vurgulanmaz.
                    cell(
                        '${m.facts.perServing.protein.round()} g',
                        m.facts.perServing.protein.round() == maxProtein &&
                            m.facts.review.isProteinSource),
                    cell(
                        '${m.facts.perServing.kcal.round()}',
                        m.facts.perServing.kcal.round() == minKcal &&
                            m.facts.review.isLight),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({required this.value, required this.onChanged});

  final SortMode value;
  final ValueChanged<SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          Text('Sırala', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 10),
          for (final m in SortMode.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Sym(m.icon, size: 20),
                label: Text(m.label),
                selected: m == value,
                selectedColor: Palette.basil,
                labelStyle: TextStyle(
                    fontFamily: Fonts.body,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: m == value ? Colors.white : Palette.ink),
                side: BorderSide(
                    color: m == value ? Palette.basil : Palette.line, width: 2),
                onSelected: (_) => onChanged(m),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Bu malzemelerle şunları yapabilirsin": hangi malzemelerle arandığını ve
/// sonucun bir cümlelik özetini gösterir.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.ready,
    required this.substitute,
    required this.almost,
    required this.filtered,
  });

  final List<RecipeMatch> ready;
  final List<RecipeMatch> substitute;
  final List<RecipeMatch> almost;

  /// Hızlı filtre açıksa sonuç "malzemeler ve filtreler" için söylenir.
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pantry = state.pantry;
    final best = ready.isNotEmpty
        ? ready.first
        : substitute.isNotEmpty
            ? substitute.first
            : null;

    final what = filtered ? 'Bu malzemeler ve filtrelerle' : 'Bu malzemelerle';
    final (icon, title) = ready.isNotEmpty
        ? ('🎉', '$what ${ready.length} tarifi hemen yapabilirsin')
        : substitute.isNotEmpty
            ? (
                '🔄',
                '$what ${substitute.length} tarifi küçük bir değişiklikle yapabilirsin'
              )
            : almost.isNotEmpty
                ? (
                    '🤏',
                    '$what tam bir tarif yok, ama ${almost.length} tarifte sadece 1 malzeme eksik'
                  )
                : ('🤔', '$what henüz bir tarif çıkmıyor');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Palette.basil,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Sym(icon, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                    height: 1.15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in pantry.take(10))
                Builder(builder: (_) {
                  final ing = state.repo.byId(p.ingredientId);
                  return Pill(ing.name,
                      icon: ing.emoji,
                      color: const Color(0x26FFFFFF),
                      fg: Colors.white,
                      border: null);
                }),
              if (pantry.length > 10)
                Pill('+${pantry.length - 10}',
                    color: const Color(0x26FFFFFF),
                    fg: Colors.white,
                    border: null),
            ],
          ),
          if (best != null) ...[
            const SizedBox(height: 16),
            const Text('EN İYİ EŞLEŞME',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: Color(0xFFBFE3CD))),
            const SizedBox(height: 6),
            ChunkyButton(
              label: '${best.recipe.title} · ${best.recipe.minutes} dk',
              icon: best.recipe.emoji,
              tone: ChunkyTone.butter,
              height: 54,
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          RecipeDetailScreen(recipeId: best.recipe.id))),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filters, required this.onChanged});

  final QuickFilters filters;
  final ValueChanged<QuickFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String icon, String label, bool selected,
            QuickFilters Function(bool) apply) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            avatar: Sym(icon, size: 22),
            label: Text(label),
            selected: selected,
            selectedColor: Palette.basilSoft,
            side: BorderSide(
                color: selected ? Palette.basil : Palette.line, width: 2),
            onSelected: (on) => onChanged(apply(on)),
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          chip('⏱', '15 dk altı', filters.quick,
              (on) => filters.copyWith(quick: on)),
          chip('💪', 'Yüksek protein', filters.highProtein,
              (on) => filters.copyWith(highProtein: on)),
          chip('🥞', 'Kahvaltılık', filters.breakfast,
              (on) => filters.copyWith(breakfast: on)),
          chip('🥗', 'Vejetaryen', filters.vegetarian,
              (on) => filters.copyWith(vegetarian: on)),
          chip('💰', 'Ekonomik', filters.economic,
              (on) => filters.copyWith(economic: on)),
          chip('🥘', 'Tek kap', filters.onePot,
              (on) => filters.copyWith(onePot: on)),
        ],
      ),
    );
  }
}

/// Boş durumu fırsata çevirir: "Sadece süt alırsan 3 tarif açılır".
class _UnlockBanner extends StatelessWidget {
  const _UnlockBanner({required this.suggestion});

  final UnlockSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ing = suggestion.ingredient;
    return SoftCard(
      color: Palette.butterSoft,
      borderColor: Palette.butter,
      child: Row(
        children: [
          IconBubble(ing.emoji, size: 60, color: Palette.surface),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sadece ${ing.name} alırsan',
                    style: theme.textTheme.titleMedium),
                Text('${suggestion.recipeCount} tarif daha hazır olur',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChunkyButton(
                      label: 'Aldım',
                      icon: '🛒',
                      tone: ChunkyTone.butter,
                      expand: false,
                      height: 42,
                      onPressed: () {
                        context
                            .read<AppState>()
                            .upsertPantry(ing.id, level: ApproxLevel.bol);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('${ing.name} dolabına eklendi')));
                      },
                    ),
                    ChunkyButton(
                      label: 'Listeye ekle',
                      icon: '📝',
                      tone: ChunkyTone.soft,
                      expand: false,
                      height: 42,
                      onPressed: context
                              .watch<AppState>()
                              .isOnShoppingList(ing.id)
                          ? null
                          : () {
                              context.read<AppState>().addToShopping([ing.id]);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      '${ing.name} alışveriş listene eklendi')));
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
