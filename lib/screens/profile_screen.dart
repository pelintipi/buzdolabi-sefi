import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/other_allergies.dart';
import '../widgets/recipe_image.dart';
import '../widgets/ui.dart';
import '../services/device_services.dart';
import 'onboarding_screen.dart';
import 'privacy_screen.dart';
import 'progress_screen.dart';
import 'sef_plus_screen.dart';
import 'recipe_detail_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tüm veriler silinsin mi?'),
        content: const Text(
            'Dolabın, profilin, favorilerin ve pişirme geçmişin kalıcı olarak silinir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Vazgeç')),
          FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: Palette.tomatoDeep),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) await state.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final p = state.profile;

    Widget group(String title, String icon, String? caption, Widget child) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Sym(icon, size: 30),
                    const SizedBox(width: 8),
                    Text(title, style: theme.textTheme.titleLarge),
                  ],
                ),
                if (caption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(caption, style: theme.textTheme.bodySmall),
                  ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        );

    Widget choice(String icon, String label, bool selected,
            ValueChanged<bool> onChanged) =>
        FilterChip(
          avatar: Sym(icon, size: 22),
          label: Text(label),
          selected: selected,
          side: BorderSide(
              color: selected ? Palette.basil : Palette.line, width: 2),
          onSelected: onChanged,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(
            children: [
              SymBubble('🧑‍🍳', size: 72, color: Palette.butterSoft),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mutfağın senin', style: theme.textTheme.titleLarge),
                    Text(
                        '${state.totalCooks} pişirme · ${state.favorites.length} favori',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ChunkyButton(
            label: 'İlerlemem',
            iconData: Icons.emoji_events_outlined,
            tone: ChunkyTone.soft,
            height: 48,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const ProgressScreen())),
          ),
          const SizedBox(height: 16),
          group(
            'Seni tanıyalım',
            '📝',
            [
              if (p.household != null) p.household!.label,
              'Haftada ${state.weeklyGoal} pişirme',
              if (p.eating != null) p.eating!.label,
              if (p.planTime != null) p.planTime!.label,
            ].join(' · '),
            ChunkyButton(
              label: 'Anketi yeniden doldur',
              icon: '✨',
              tone: ChunkyTone.soft,
              height: 48,
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (ctx) =>
                    OnboardingScreen(onDone: () => Navigator.of(ctx).pop()),
              )),
            ),
          ),
          group(
            'Görünüm',
            '🌓',
            'Varsayılan: telefonun açık/koyu ayarı.',
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<UiTheme>(
                segments: [
                  for (final t in UiTheme.values)
                    ButtonSegment(value: t, label: Text(t.label)),
                ],
                selected: {p.uiTheme},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    state.updateProfile(p.copyWith(uiTheme: s.first)),
              ),
            ),
          ),
          group(
            'Hatırlatmalar',
            '🔔',
            'Plan saatinde bir öneri, bozulacak ürün varsa bir gün önceden uyarı.',
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bildirim gönder',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(p.planTime == null
                  ? 'Her gün 17:00'
                  : 'Her gün · ${p.planTime!.label}'),
              value: p.remindersOn,
              onChanged: (on) async {
                if (on) {
                  final ok = await DeviceServices.of(context)
                      .reminders
                      .requestPermission();
                  if (!ok) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Bildirim izni verilmedi. iPhone Ayarlar uygulamasında Buzdolabı Şefi bölümünden açabilirsin.')));
                    }
                    return;
                  }
                }
                state.updateProfile(p.copyWith(remindersOn: on));
              },
            ),
          ),
          group(
            'Günlük hedefler',
            '🎯',
            'İlerleme sekmesindeki "Bugün yediklerin" çubukları bunlara göre.',
            Column(
              children: [
                _TargetRow(
                  label: 'Kalori',
                  unit: 'kcal',
                  value: p.dailyKcal,
                  step: 100,
                  min: 1000,
                  max: 4000,
                  onChanged: (v) =>
                      state.updateProfile(p.copyWith(dailyKcal: v)),
                ),
                _TargetRow(
                  label: 'Protein',
                  unit: 'g',
                  value: p.dailyProtein,
                  step: 5,
                  min: 20,
                  max: 250,
                  onChanged: (v) =>
                      state.updateProfile(p.copyWith(dailyProtein: v)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: ChunkyButton(
                    label: 'Şef+',
                    icon: '⭐',
                    tone: ChunkyTone.butter,
                    height: 48,
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const SefPlusScreen())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChunkyButton(
                    label: 'Gizlilik',
                    icon: '🔒',
                    tone: ChunkyTone.soft,
                    height: 48,
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const PrivacyScreen())),
                  ),
                ),
              ],
            ),
          ),
          group(
            'Beslenme',
            '🥗',
            null,
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<Diet>(
                segments: [
                  for (final d in Diet.values)
                    ButtonSegment(value: d, label: Text(d.label)),
                ],
                selected: {p.diet},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    state.updateProfile(p.copyWith(diet: s.first)),
              ),
            ),
          ),
          group(
            'Alerjiler',
            '⚠',
            'Bunları içeren tarifler sana hiç gösterilmez.',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in Allergen.values)
                      choice(
                          a.emoji,
                          a.label,
                          p.allergies.contains(a),
                          (on) => state.updateProfile(p.copyWith(
                                allergies: on
                                    ? {...p.allergies, a}
                                    : (p.allergies.toSet()..remove(a)),
                                allergyAsked: true,
                              ))),
                  ],
                ),
                const SizedBox(height: 10),
                OtherAllergies(
                  compact: true,
                  values: p.customAllergies,
                  onChanged: (v) => state.updateProfile(
                      p.copyWith(customAllergies: v, allergyAsked: true)),
                ),
              ],
            ),
          ),
          group(
            'Mutfak aletlerin',
            '🔌',
            'Olmayan aletleri gerektiren tarifler gizlenir.',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in Appliance.values)
                  choice(
                      a.emoji,
                      a.label,
                      p.appliances.contains(a),
                      (on) => state.updateProfile(p.copyWith(
                            appliances: on
                                ? {...p.appliances, a}
                                : (p.appliances.toSet()..remove(a)),
                            appliancesAsked: true,
                          ))),
              ],
            ),
          ),
          group(
            'Evde genelde neler var?',
            '🧂',
            'İşaretlediklerin her tarifte var sayılır. Biten olursa kapat.',
            Column(
              children: [
                for (final s in state.repo.staples)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        FoodIcon(s.emoji, size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        Switch(
                          value: !p.missingStaples.contains(s.id),
                          onChanged: (has) => state.updateProfile(p.copyWith(
                            missingStaples: has
                                ? (p.missingStaples.toSet()..remove(s.id))
                                : {...p.missingStaples, s.id},
                          )),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          group(
            'Favorilerin',
            '❤',
            null,
            state.favorites.isEmpty
                ? Text(
                    'Henüz favori tarifin yok. Tarif kartındaki kalple ekleyebilirsin.',
                    style: theme.textTheme.bodyMedium)
                : Column(
                    children: [
                      for (final r in state.favorites)
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      RecipeDetailScreen(recipeId: r.id))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                RecipeImage(r, width: 44, radius: 12),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(r.title,
                                      style: theme.textTheme.titleMedium),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          SoftCard(
            onTap: () => _confirmReset(context),
            child: Row(
              children: [
                const Icon(Icons.delete_forever_rounded,
                    color: Palette.tomatoDeep),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tüm verilerimi sil',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Palette.tomatoDeep)),
                      Text('Bütün verilerin yalnızca bu cihazda saklanır.',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.label,
    required this.unit,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String unit;
  final double value;
  final double step;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15))),
        IconButton.filledTonal(
          icon: const Icon(Icons.remove_rounded),
          tooltip: '$label azalt',
          onPressed: value > min ? () => onChanged(value - step) : null,
        ),
        SizedBox(
          width: 92,
          child: Text('${value.round()} $unit',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.add_rounded),
          tooltip: '$label artır',
          onPressed: value < max ? () => onChanged(value + step) : null,
        ),
      ],
    );
  }
}
