import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/recipe.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/recipe_image.dart';
import '../widgets/ui.dart';

/// Beceri seviyeleri: bir tekniği kaç kez pişirdiğine göre.
(String, int?) _skillLevel(int count) {
  if (count == 0) return ('Henüz denemedin', 1);
  if (count < 3) return ('Çırak', 3);
  if (count < 10) return ('Kalfa', 10);
  return ('Usta', null);
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final perWeek = state.weeklyGoal;
    final skills = state.techniqueCounts;

    return Scaffold(
      appBar: AppBar(title: const Text('İlerleme')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const _TodayCard(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Palette.butterSoft,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Palette.butter, width: 2),
            ),
            child: Row(
              children: [
                const Sym('🔥', size: 80),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${state.weeklyStreak} haftalık seri',
                          style: theme.textTheme.headlineSmall),
                      Text('Bu hafta ${state.cooksThisWeek}/$perWeek pişirme',
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 10),
                      WeeklySlots(
                          done: state.cooksThisWeek, goal: perWeek, size: 38),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                    icon: '🍽', value: '${state.totalCooks}', label: 'pişirme'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                    icon: '🌱',
                    value: formatGrams(state.totalRescuedGrams),
                    label: 'israftan kurtarıldı'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionTitle('Beceriler', icon: '🌳'),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final t in Technique.values)
                  Builder(builder: (_) {
                    final count = skills[t] ?? 0;
                    final (name, next) = _skillLevel(count);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SymBubble(t.emoji,
                              size: 48,
                              color: count > 0
                                  ? Palette.basilSoft
                                  : const Color(0xFFF0F3EE)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${t.label} · $name',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15)),
                                const SizedBox(height: 6),
                                next == null
                                    ? const Pill('En üst seviye',
                                        icon: '🏅', border: null)
                                    : ChunkyProgress(
                                        value: count / next, height: 10),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('$count',
                              style: const TextStyle(
                                  fontFamily: Fonts.display,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          if (state.recentLogs.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionTitle('Son pişirdiklerin', icon: '🍳'),
            for (final log in state.recentLogs)
              if (state.tryRecipe(log.recipeId) case final recipe?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        RecipeImage(recipe, width: 48, radius: 13),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(recipe.title,
                                  style: theme.textTheme.titleMedium),
                              Text(formatDate(log.cookedAt),
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (log.rating != null)
                          Pill('${log.rating}', icon: '⭐', bordered: false),
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

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon, required this.value, required this.label});

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        children: [
          Sym(icon, size: 44),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

const _weekdays = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'];

/// Bugün yenenlerin kalorisi ve proteini (pişirdiklerinden, yediğin porsiyon
/// kadar), son 7 günün çubukları ve fotoğraflı yemek günlüğü.
class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = state.intakeOn(now);
    final p = state.profile;
    final week = [
      for (var i = 6; i >= 0; i--)
        (
          day: DateTime(now.year, now.month, now.day - i),
          kcal: state.intakeOn(DateTime(now.year, now.month, now.day - i)).kcal,
        )
    ];
    final maxKcal = [p.dailyKcal, ...week.map((w) => w.kcal)]
        .reduce((a, b) => a > b ? a : b);
    final photos = state.photoLogs;

    Widget bar(
            String icon, String label, double value, double target, Color c) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Sym(icon, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '$label: ${formatNumber(value, decimals: 0)} / ${formatNumber(target, decimals: 0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    ChunkyProgress(
                        value: (value / target).clamp(0.0, 1.0),
                        color: c,
                        track: Palette.line,
                        height: 10),
                  ],
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bugün yediklerin', style: theme.textTheme.titleLarge),
              Text(
                  today.logs.isEmpty
                      ? 'Bir tarifi pişirip "Kaydet" deyince burada toplanır.'
                      : today.logs
                          .map((l) => state.tryRecipe(l.recipeId)?.title ?? '')
                          .join(', '),
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              bar('🔥', 'Kalori (kcal)', today.kcal, p.dailyKcal,
                  Palette.tomato),
              bar('💪', 'Protein (g)', today.protein, p.dailyProtein,
                  Palette.basil),
              const SizedBox(height: 6),
              SizedBox(
                height: 86,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final w in week)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 4 + 56 * (w.kcal / maxKcal),
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                color: w.day.day == now.day
                                    ? Palette.tomato
                                    : Palette.tomatoSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(_weekdays[w.day.weekday - 1],
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    color: Palette.inkSoft)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                  'Hedefler Profil\'den değişir. Tahmini değerlerdir, tıbbi tavsiye değildir.',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        if (photos.isNotEmpty && !kIsWeb) ...[
          const SizedBox(height: 14),
          SectionTitle('Yemek günlüğüm (${photos.length})', icon: '📷'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final l in photos.take(12))
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(l.photoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: Palette.basilSoft,
                          alignment: Alignment.center,
                          child: FoodIcon(
                              state.tryRecipe(l.recipeId)?.emoji ?? '🍽',
                              size: 40))),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
