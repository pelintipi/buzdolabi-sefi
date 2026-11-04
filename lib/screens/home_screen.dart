import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/collections.dart';

import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import '../widgets/recipe_card.dart';
import '../widgets/video_source_card.dart';
import 'cooking_mode_screen.dart';
import 'collections_screen.dart';
import 'creator_screen.dart';
import 'leftover_screen.dart';
import 'plan_screen.dart';
import 'quick_fill_screen.dart';
import 'season_screen.dart';
import 'import_recipe_screen.dart';
import 'recipe_detail_screen.dart';
import 'results_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final active = state.activeCooking;
    final expiring = state.expiringItems;
    final now = DateTime.now();
    final goal = state.weeklyGoal;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          children: [
            const Row(
              children: [
                Text('Merhaba',
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 40,
                        height: 1.1,
                        letterSpacing: -1,
                        color: Palette.ink)),
                SizedBox(width: 10),
                FoodIcon('👋', size: 44),
              ],
            ),
            Text(
                state.profile.planTime?.homeLine ??
                    'Bugün dolabında ne var, birlikte bakalım.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontSize: 18, color: Palette.ink)),
            const SizedBox(height: 22),
            // Videodan tarif saklayanlar için TikTok kartı en üstte.
            if (state.profile.savesVideos) ...[
              const _VideoImportCard(),
              const SizedBox(height: 12),
            ],
            const _Hero(),
            const SizedBox(height: 12),
            if (!state.profile.savesVideos) ...[
              const _VideoImportCard(),
              const SizedBox(height: 16),
            ],
            const _QuickTiles(),
            const SizedBox(height: 16),
            const _CollectionsStrip(),
            const SizedBox(height: 16),
            if (state.importedRecipes.isNotEmpty) ...[
              const _SavedVideos(),
              const SizedBox(height: 16),
            ],
            if (active != null) ...[
              SoftCard(
                child: Row(
                  children: [
                    IconBubble(state.recipeById(active.recipeId).emoji,
                        size: 56, color: Palette.tomatoSoft),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kaldığın yerden devam et',
                              style: theme.textTheme.titleMedium),
                          Text(
                              '${state.recipeById(active.recipeId).title} · Adım ${active.step + 1}',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    ChunkyButton(
                      label: 'Devam',
                      tone: ChunkyTone.accent,
                      expand: false,
                      height: 42,
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => CookingModeScreen(
                          recipeId: active.recipeId,
                          servings: active.servings,
                          initialStep: active.step,
                        ),
                      )),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (expiring.isNotEmpty) ...[
              SoftCard(
                color: Palette.butterSoft,
                borderColor: Palette.butter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const FoodIcon('⏳', size: 30),
                        const SizedBox(width: 8),
                        Text('Yakında bozulacaklar',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final item in expiring.take(4))
                      Builder(builder: (_) {
                        final ing = state.repo.byId(item.ingredientId);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              FoodIcon(ing.emoji, size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(ing.name,
                                    style: theme.textTheme.bodyLarge),
                              ),
                              Pill(expiryText(item.expiresAt, now),
                                  color: Palette.tomatoSoft,
                                  fg: Palette.tomatoDeep,
                                  border: null),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 6),
                    ChunkyButton(
                      label: 'Bunları değerlendiren tarifler',
                      tone: ChunkyTone.soft,
                      height: 48,
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const ResultsScreen())),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SoftCard(
              child: Row(
                children: [
                  const FoodIcon('🔥', size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${state.weeklyStreak} haftalık seri',
                            style: theme.textTheme.titleLarge),
                        Text('Bu hafta ${state.cooksThisWeek}/$goal pişirme',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 10),
                        WeeklySlots(
                            done: state.cooksThisWeek, goal: goal, size: 36),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Karşılama kartı: sıcak mutfak tezgâhı sahnesi, başlık ve "Ne pişirsem?".
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final empty = state.pantry.isEmpty;
    return Container(
      // En az bu kadar; büyük yazı ayarında içerik kadar uzar, taşmaz.
      constraints: const BoxConstraints(minHeight: 292),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3EEE9), Color(0xFFE8DFD6)],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x143A2A1E), blurRadius: 22, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Pencereden gelen yumuşak ışık.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.55, -0.9),
                  radius: 0.95,
                  colors: [Color(0xB3FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          // Sağ kenarda buzdolabı kapağı.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 22,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFFD9D9D6),
                  const Color(0xFFBFC1BF).withValues(alpha: 0.9),
                ]),
              ),
            ),
          ),
          // Ahşap tezgâh.
          Positioned(
            right: -30,
            bottom: -18,
            child: Transform.rotate(
              angle: -0.05,
              child: Container(
                width: 250,
                height: 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFD2A579), Color(0xFFA9774C)],
                  ),
                ),
              ),
            ),
          ),
          // Kâsede sebzeler, tezgâhta havuç, soğan ve kavanoz.
          const Positioned(
              right: 58, bottom: 70, child: FoodIcon('🥗', size: 112)),
          const Positioned(
              right: 92, bottom: 132, child: FoodIcon('🍅', size: 46)),
          const Positioned(
              right: 64, bottom: 140, child: FoodIcon('🫑', size: 44)),
          const Positioned(
              right: 118, bottom: 146, child: FoodIcon('🌿', size: 40)),
          const Positioned(
              right: 26, bottom: 44, child: FoodIcon('🫙', size: 58)),
          const Positioned(
              right: 66, bottom: 10, child: FoodIcon('🧅', size: 48)),
          const Positioned(
              right: 104, bottom: 8, child: FoodIcon('🥕', size: 50)),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 250,
                  child: Text(
                    'Dolabındakilerle ne pişirebilirsin?',
                    style: TextStyle(
                      fontFamily: Fonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 27,
                      height: 1.12,
                      letterSpacing: -0.4,
                      color: Palette.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 190,
                  child: Text(
                    _subtitle(state.profile.goals, empty),
                    style: const TextStyle(
                      fontFamily: Fonts.body,
                      fontWeight: FontWeight.w500,
                      fontSize: 14.5,
                      height: 1.35,
                      color: Palette.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                ChunkyButton(
                  label: 'Ne pişirsem?',
                  iconData: Icons.search_rounded,
                  expand: false,
                  height: 56,
                  onPressed: () => openWhatToCook(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "TikTok'tan tarif kaydet" girişi.
class _VideoImportCard extends StatelessWidget {
  const _VideoImportCard();

  @override
  Widget build(BuildContext context) {
    void open() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ImportRecipeScreen()));
    return SoftCard(
      color: Palette.peach,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      onTap: open,
      child: Row(
        children: [
          const FoodIcon('🎬', size: 62),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TikTok\'tan tarif kaydet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 17.5,
                        letterSpacing: -0.4,
                        color: Palette.ink)),
                SizedBox(height: 2),
                Text('Paylaş\'a dokun, bizi seç',
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Palette.inkSoft)),
              ],
            ),
          ),
          ChunkyButton(
            label: 'Ekle',
            expand: false,
            height: 46,
            onPressed: open,
          ),
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
        SectionTitle('Videodan kaydettiklerin (${saved.length})', icon: '🎬'),
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
                    avatar: const FoodIcon('🎬', size: 18),
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
                              child: IconBubble('▶',
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

/// Dört hızlı giriş: haftalık plan, dünden kalan, mevsim, dolabı doldur.
class _QuickTiles extends StatelessWidget {
  const _QuickTiles();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final seasonal = inSeasonNow(state, now);
    void go(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));

    Widget tile(String emoji, String title, String sub, Color color,
            VoidCallback onTap) =>
        Expanded(
          child: SoftCard(
            color: color,
            borderColor: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(10, 12, 2, 12),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Row(
                children: [
                  FoodIcon(emoji, size: 42),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: Fonts.display,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                height: 1.15,
                                letterSpacing: -0.3,
                                color: Palette.ink)),
                        const SizedBox(height: 2),
                        Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: Fonts.body,
                                fontWeight: FontWeight.w500,
                                fontSize: 12.5,
                                height: 1.25,
                                color: Palette.inkSoft)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Palette.inkSoft, size: 20),
                ],
              ),
            ),
          ),
        );

    const gap = SizedBox(width: 12);
    return Column(
      children: [
        Row(
          children: [
            tile(
                '📝',
                'Haftalık plan',
                state.planIds.isEmpty
                    ? '${state.planLength} akşam'
                    : '${state.planIds.length} akşam hazır',
                Palette.peach,
                () => go(const PlanScreen())),
            gap,
            tile(
                '🧅',
                'Dünden kalan',
                state.leftovers.isEmpty
                    ? 'Pilav, makarna…'
                    : state.repo.byId(state.leftovers.first.ingredientId).name,
                Palette.blush,
                () => go(const LeftoverScreen())),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            tile(
                seasonal.isEmpty ? '🥕' : seasonal.first.emoji,
                'Mevsiminde',
                '${monthNames[now.month - 1]}: ${seasonal.take(2).map((i) => i.name).join(', ')}',
                Palette.peach,
                () => go(const SeasonScreen())),
            gap,
            tile('🫙', 'Dolabı doldur', 'Fiş, barkod', Palette.blush,
                () => go(const QuickFillScreen())),
          ],
        ),
      ],
    );
  }
}

/// Ana sayfadaki koleksiyon şeridi: Yaptıklarım, Favoriler, kendi
/// koleksiyonların ve birkaç hazır koleksiyon.
class _CollectionsStrip extends StatelessWidget {
  const _CollectionsStrip();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    void go(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    const featured = [
      'yuksek_protein',
      'hafif',
      'kategori_tatli',
      'kategori_atistirmalik'
    ];

    final items = <(String, String, String, VoidCallback)>[
      (
        '🧑‍🍳',
        'Yaptıklarım',
        '${state.cookedSummaries.length} tarif',
        () => go(const CookedHistoryScreen())
      ),
      (
        '❤',
        'Favoriler',
        '${state.favorites.length} tarif',
        () => go(const CollectionDetailScreen.favorites())
      ),
      for (final c in state.collections)
        (
          c.emoji,
          c.name,
          '${c.recipeIds.length} tarif',
          () => go(CollectionDetailScreen.user(c.id))
        ),
      for (final s in [
        for (final id in featured)
          smartCollections.firstWhere((s) => s.id == id)
      ])
        (
          s.emoji,
          s.title,
          '${state.recipesInSmart(s).length} tarif',
          () => go(CollectionDetailScreen.smart(s.id))
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Koleksiyonlar',
            icon: '🔖',
            trailing: TextButton(
                onPressed: () => go(const CollectionsScreen()),
                child: const Text('Tümü'))),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final (emoji, title, sub, onTap) = items[i];
              return SizedBox(
                width: 136,
                child: SoftCard(
                  padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FoodIcon(emoji, size: 30),
                      const Spacer(),
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: Fonts.display,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5)),
                      Text(sub,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              color: Palette.inkSoft)),
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
