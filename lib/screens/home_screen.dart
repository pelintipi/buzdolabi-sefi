import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../services/recipe_matcher.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/recipe_card.dart';
import '../widgets/recipe_image.dart';
import '../widgets/ui.dart';
import '../widgets/video_source_card.dart';
import 'collections_screen.dart';
import 'cooking_mode_screen.dart';
import 'creator_screen.dart';
import 'import_recipe_screen.dart';
import 'ingredient_input_screen.dart';
import 'leftover_screen.dart';
import 'plan_screen.dart';
import 'progress_screen.dart';
import 'quick_fill_screen.dart';
import 'recipe_detail_screen.dart';
import 'results_screen.dart';
import 'season_screen.dart';

const _weekdayNames = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar'
];

void _go(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// Ana sayfa. Tek bir asıl soru var: "şu an ne pişirebilirim?" Cevabı en
/// üstte, görselli kartlarla; ekleme ve planlama araçları altta, sade.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final active = state.activeCooking;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            // ------------------------------------------------ Başlık
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_weekdayNames[now.weekday - 1]}, ${now.day} ${monthNames[now.month - 1]}'
                        .toUpperCase(),
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        letterSpacing: 1.2,
                        color: Palette.inkSoft),
                  ),
                ),
                if (state.profile.cookDaysPerWeek != null)
                  _StreakChip(
                    done: state.cooksThisWeek,
                    goal: state.weeklyGoal,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Merhaba', style: theme.textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(
                state.profile.planTime?.homeLine ??
                    _subtitle(state.profile.goals, state.pantry.isEmpty),
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: Palette.inkSoft)),
            const SizedBox(height: 18),
            ChunkyButton(
              label: 'Ne pişirsem?',
              iconData: Icons.search_rounded,
              height: 58,
              onPressed: () => openWhatToCook(context),
            ),

            if (active != null) ...[
              const SizedBox(height: 14),
              _ContinueCard(active: active),
            ],

            // ------------------------------------------------ Şu an yapabileceklerin
            const SizedBox(height: 26),
            const _ReadyNow(),

            if (state.expiringItems.isNotEmpty) ...[
              const SizedBox(height: 18),
              const _ExpiringCard(),
            ],

            // ------------------------------------------------ Ekle
            const SizedBox(height: 26),
            const _HomeHeading('Ekle'),
            const SizedBox(height: 10),
            const _AddActions(),

            // ------------------------------------------------ Planla
            const SizedBox(height: 26),
            const _HomeHeading('Planla'),
            const SizedBox(height: 10),
            const _PlanList(),

            if (state.importedRecipes.isNotEmpty) ...[
              const SizedBox(height: 26),
              const _SavedVideos(),
            ],

            const SizedBox(height: 26),
            _WeekCard(state: state),
          ],
        ),
      ),
    );
  }
}

/// Bölüm başlığı: serif, sağda isteğe bağlı bağlantı.
class _HomeHeading extends StatelessWidget {
  const _HomeHeading(this.text, {this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontFamily: Fonts.serif,
                  fontSize: 26,
                  height: 1.1,
                  color: Palette.ink)),
        ),
        if (action != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(action!,
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Palette.accent)),
            ),
          ),
      ],
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.done, required this.goal});

  final int done;
  final int goal;

  static const _goals = [
    (2, '1-2 gün'),
    (3, '3-4 gün'),
    (5, '5-6 gün'),
    (7, 'Her gün'),
  ];

  Future<void> _pick(BuildContext context) async {
    final state = context.read<AppState>();
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Haftada kaç gün pişirirsin?',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final (days, label) in _goals)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing: days == goal
                      ? Icon(Icons.check_rounded, color: Palette.accent)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(days),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    state.updateProfile(state.profile.copyWith(cookDaysPerWeek: picked));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.surface,
      shape: StadiumBorder(side: BorderSide(color: Palette.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pick(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_outlined,
                  size: 16, color: Palette.tomato),
              const SizedBox(width: 4),
              Text('$done/$goal bu hafta',
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Palette.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.active});

  final ActiveCooking active;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final recipe = state.recipeById(active.recipeId);
    return SoftCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          RecipeImage(recipe, width: 56, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kaldığın yerden devam et',
                    style: theme.textTheme.titleMedium),
                Text('${recipe.title} · Adım ${active.step + 1}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          ChunkyButton(
            label: 'Devam',
            expand: false,
            height: 42,
            onPressed: () => _go(
                context,
                CookingModeScreen(
                  recipeId: active.recipeId,
                  servings: active.servings,
                  initialStep: active.step,
                )),
          ),
        ],
      ),
    );
  }
}

/// "Şu an yapabileceklerin": dolaptakilerle eksiksiz yapılabilen tarifler;
/// yoksa tek eksikle yapılabilenler; dolap boşsa ekleme çağrısı.
class _ReadyNow extends StatelessWidget {
  const _ReadyNow();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    if (state.pantry.isEmpty) {
      return SoftCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dolabında ne var?',
                style: TextStyle(
                    fontFamily: Fonts.serif, fontSize: 26, color: Palette.ink)),
            const SizedBox(height: 6),
            Text(
                'Birkaç malzeme yaz, yapabileceğin tarifleri burada sıralayayım.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Palette.inkSoft)),
            const SizedBox(height: 14),
            ChunkyButton(
              label: 'Malzeme ekle',
              iconData: Icons.add_rounded,
              tone: ChunkyTone.soft,
              expand: false,
              height: 46,
              onPressed: () => _go(
                  context, const IngredientInputScreen(openResultsAfter: true)),
            ),
          ],
        ),
      );
    }
    final matches = state.matches(const QuickFilters());
    final ready = [
      for (final m in matches)
        if (m.problems.isEmpty) m
    ];
    final list = ready.isNotEmpty
        ? ready
        : [
            for (final m in matches)
              if (m.group == MatchGroup.almost) m
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeHeading(
          ready.isNotEmpty
              ? 'Şu an yapabileceklerin'
              : 'Bir malzemeyle yapabileceklerin',
          action: 'Tümü',
          onAction: () => _go(context, const ResultsScreen()),
        ),
        const SizedBox(height: 4),
        Text(
            ready.isNotEmpty
                ? '${ready.length} tarif dolabındakilerle hazır'
                : 'Eksiksiz bir tarif yok; şunlara tek malzeme lazım',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 228,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: list.length.clamp(0, 10),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _RecipeTile(match: list[i]),
          ),
        ),
      ],
    );
  }
}

/// Ana sayfadaki görselli tarif kartı.
class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.match});

  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final Recipe r = match.recipe;
    final n = match.facts.perServing;
    final status = matchStatus(match, state.repo);
    return Semantics(
      button: true,
      label: '${r.title}, ${r.minutes} dakika',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _go(context, RecipeDetailScreen(recipeId: r.id)),
        child: SizedBox(
          width: 196,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecipeImage(r, width: 196, height: 148, radius: 20),
              const SizedBox(height: 10),
              Text(r.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                  '${r.minutes} dk  ·  ${formatNumber(n.kcal, decimals: 0)} kcal  ·  ${formatNumber(n.protein, decimals: 0)} g protein',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
              if (match.problems.isNotEmpty)
                Text(status.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: status.color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpiringCard extends StatelessWidget {
  const _ExpiringCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final items = state.expiringItems;
    final names = [
      for (final p in items.take(3))
        '${state.repo.byId(p.ingredientId).name} (${expiryText(p.expiresAt, now).toLowerCase()})'
    ].join(', ');
    return SoftCard(
      color: Palette.tomatoSoft,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: Palette.tomato, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Yakında bozulacaklar',
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: Palette.tomatoDeep)),
                Text(names,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Palette.ink)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _go(context, const ResultsScreen()),
            child: const Text('Değerlendir'),
          ),
        ],
      ),
    );
  }
}

/// Ekleme yolları tek sırada: malzeme, fiş/barkod, sosyal medya, dünden kalan.
class _AddActions extends StatelessWidget {
  const _AddActions();

  @override
  Widget build(BuildContext context) {
    final videosFirst = context.watch<AppState>().profile.savesVideos;
    final actions = <(IconData, String, Widget)>[
      (Icons.edit_note_rounded, 'Malzeme', const IngredientInputScreen()),
      (Icons.receipt_long_outlined, 'Fiş, barkod', const QuickFillScreen()),
      (
        Icons.play_circle_outline_rounded,
        'Sosyal medya',
        const ImportRecipeScreen()
      ),
      (Icons.takeout_dining_outlined, 'Dünden kalan', const LeftoverScreen()),
    ];
    // Videodan tarif saklayanlar için sosyal medya öne.
    if (videosFirst) actions.insert(0, actions.removeAt(2));
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: true,
              label: actions[i].$2,
              child: GestureDetector(
                onTap: () => _go(context, actions[i].$3),
                child: Column(
                  children: [
                    Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: Palette.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Palette.line),
                      ),
                      alignment: Alignment.center,
                      child:
                          Icon(actions[i].$1, color: Palette.accent, size: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(actions[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: Fonts.body,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            color: Palette.ink)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Planlama ve keşif: tek kartta satırlar.
class _PlanList extends StatelessWidget {
  const _PlanList();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final seasonal = inSeasonNow(state, now);
    final rows = <(IconData, String, String, Widget)>[
      (
        Icons.calendar_month_outlined,
        'Haftalık plan',
        state.planIds.isEmpty
            ? '${state.planLength} akşamlık plan çıkar'
            : '${state.planIds.length} akşam planlı',
        const PlanScreen()
      ),
      (
        Icons.eco_outlined,
        'Mevsiminde',
        '${monthNames[now.month - 1]}: ${seasonal.take(3).map((i) => i.name).join(', ')}',
        const SeasonScreen()
      ),
      (
        Icons.bookmark_border_rounded,
        'Koleksiyonlar',
        'Yaptıklarım, favoriler, hazır listeler',
        const CollectionsScreen()
      ),
    ];
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 66),
            InkWell(
              onTap: () => _go(context, rows[i].$4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: Palette.sand,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(rows[i].$1, color: Palette.accent, size: 21),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rows[i].$2,
                              style: TextStyle(
                                  fontFamily: Fonts.body,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Palette.ink)),
                          Text(rows[i].$3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Palette.lineDeep),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = state.weeklyGoal;
    // Üst chip yalnızca hedef seçilince çıkar; seçim burada.
    if (state.profile.cookDaysPerWeek == null) {
      return SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Haftada kaç gün pişirirsin?',
                style: TextStyle(
                    fontFamily: Fonts.serif, fontSize: 24, color: Palette.ink)),
            Text('Seçince üstte "0/N bu hafta" görünür.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (days, label) in _StreakChip._goals)
                  ActionChip(
                    label: Text(label),
                    onPressed: () => state.updateProfile(
                        state.profile.copyWith(cookDaysPerWeek: days)),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return SoftCard(
      onTap: () => _go(context, const ProgressScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              state.weeklyStreak > 0
                  ? '${state.weeklyStreak} haftalık seri'
                  : 'Haftalık hedef',
              style: TextStyle(
                  fontFamily: Fonts.serif, fontSize: 24, color: Palette.ink)),
          Text('Bu hafta ${state.cooksThisWeek}/$goal pişirme',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          WeeklySlots(done: state.cooksThisWeek, goal: goal, size: 36),
        ],
      ),
    );
  }
}

/// Videodan kaydedilen tarifler; her birinde dolaba göre durum.
class _SavedVideos extends StatelessWidget {
  const _SavedVideos();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final snapshot = state.snapshot;
    final saved = state.importedRecipes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Sosyal medyadan kaydettiklerin (${saved.length})',
            icon: '🎬'),
        if (recipesByCreator(state).length > 1 ||
            (recipesByCreator(state).values.firstOrNull?.length ?? 0) > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in recipesByCreator(state).entries.take(6))
                  ActionChip(
                    avatar: const Sym('🎬', size: 18),
                    label: Text('@${e.key} (${e.value.length})'),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => CreatorScreen(author: e.key))),
                  ),
              ],
            ),
          ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: saved.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final r = saved[i];
              final status =
                  matchStatus(state.matcher.evaluate(r, snapshot), state.repo);
              return SizedBox(
                width: 132,
                child: SoftCard(
                  padding: const EdgeInsets.all(8),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => RecipeDetailScreen(recipeId: r.id))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          VideoThumb(
                              url: r.source?.thumbnailUrl,
                              fallbackEmoji: r.emoji,
                              width: 116,
                              height: 116),
                          const Positioned(
                              left: 6,
                              bottom: 6,
                              child: SymBubble('▶',
                                  size: 32, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(r.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              height: 1.15)),
                      const Spacer(),
                      Text(status.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              color: status.color)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Yeşil kartın alt yazısı; ankette seçilen amaca göre.
String _subtitle(Set<Goal> goals, bool emptyPantry) {
  if (goals.contains(Goal.waste)) {
    return 'Bozulmak üzere olanları önce kullanan tarifler.';
  }
  if (goals.contains(Goal.budget)) {
    return 'Markete gitmeden, elindekilerle.';
  }
  if (goals.contains(Goal.healthy)) {
    return 'Protein ve kalorisiyle karşılaştırarak seç.';
  }
  return emptyPantry
      ? 'Malzemeleri yaz, uygun tarifleri saniyeler içinde bulalım.'
      : 'Dolabına göre en uygun tarifler hazır.';
}
