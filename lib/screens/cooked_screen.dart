import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../services/device_services.dart';
import '../services/recipe_matcher.dart';
import '../services/unit_converter.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/profile_dialogs.dart';
import '../widgets/share_card.dart';
import '../widgets/recipe_image.dart';
import '../widgets/ui.dart';

enum _DeductMode { all, half, custom }

class _Deduction {
  const _Deduction(this.ingredientId, this.grams);

  final String ingredientId;
  final double grams;
}

/// Döngüyü kapatan ekran: dolap güncellemesi (geri alınabilir), puan, not ve ödül.
class CookedScreen extends StatefulWidget {
  const CookedScreen(
      {super.key, required this.recipeId, required this.servings});

  final String recipeId;
  final int servings;

  @override
  State<CookedScreen> createState() => _CookedScreenState();
}

class _CookedScreenState extends State<CookedScreen> {
  late final Recipe _recipe;
  late final List<_Deduction> _deductions;
  final _selected = <String>{};
  final _note = TextEditingController();
  _DeductMode _mode = _DeductMode.all;
  int? _rating;
  CookOutcome? _outcome;
  double _portions = 1;
  String? _photo;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Az önce kaydedilen pişirme (porsiyon ve fotoğraf buna yazılır).
  DateTime? get _logTime => context.read<AppState>().logs.lastOrNull?.cookedAt;

  void _setPortions(double v) {
    setState(() => _portions = v);
    final t = _logTime;
    if (t != null) {
      context
          .read<AppState>()
          .updateLog(t, (l) => l.copyWith(portionsEaten: v));
    }
  }

  Future<void> _addPhoto() async {
    final state = context.read<AppState>();
    final path = await DeviceServices.of(context).photos.takeDishPhoto();
    if (!mounted) return;
    if (path == null) {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Fotoğraf telefonda çalışır, tarayıcıda saklanamıyor.')));
      }
      return;
    }
    setState(() => _photo = path);
    final t = _logTime;
    if (t != null) state.updateLog(t, (l) => l.copyWith(photoPath: path));
  }

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _recipe = state.recipeById(widget.recipeId);
    final snapshot = state.snapshot;
    final match =
        state.matcher.evaluate(_recipe, snapshot, servings: widget.servings);
    _deductions = [];
    for (final c in match.checks) {
      if (c.state == ItemState.staple || c.state == ItemState.missing) continue;
      final id = c.usedIngredientId;
      if (state.isStapleAvailable(id)) continue;
      final available = c.substitute == null
          ? c.availableGrams
          : snapshot.availableFor(id, state.repo);
      final grams = math.min(c.requiredGrams, available);
      if (grams > 0) _deductions.add(_Deduction(id, grams));
    }
    _selected.addAll(_deductions.map((d) => d.ingredientId));
  }

  double _gramsFor(_Deduction d) =>
      _mode == _DeductMode.half ? d.grams / 2 : d.grams;

  void _save() {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final grams = <String, double>{};
    for (final d in _deductions) {
      if (_mode == _DeductMode.custom && !_selected.contains(d.ingredientId)) {
        continue;
      }
      grams[d.ingredientId] = (grams[d.ingredientId] ?? 0) + _gramsFor(d);
    }
    final outcome = state.recordCook(_recipe, widget.servings, grams,
        rating: _rating, note: _note.text);
    setState(() => _outcome = outcome);

    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 10),
      // Butonlu bildirimler varsayılan olarak kalıcıdır; 10 sn sonra kapansın.
      persist: false,
      content: const Text('Dolabın güncellendi'),
      action: SnackBarAction(
        label: 'Geri al',
        onPressed: () => state.restorePantry(outcome.previousPantry),
      ),
    ));

    if (!state.profile.appliancesAsked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askAppliances());
    }
  }

  Future<void> _askAppliances() async {
    final state = context.read<AppState>();
    if (!mounted) return;
    final result = await showDialog<Set<Appliance>>(
      context: context,
      builder: (_) => AppliancesDialog(initial: state.profile.appliances),
    );
    state.updateProfile(state.profile.copyWith(
        appliances: result ?? state.profile.appliances, appliancesAsked: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            RecipeImage(_recipe, width: 32, radius: 9),
            const SizedBox(width: 8),
            Flexible(
                child: Text(_recipe.title, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: _outcome == null ? _buildForm(context) : _buildReward(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.read<AppState>().repo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        const Center(child: Sym('🎉', size: 110)),
        Center(
            child:
                Text('Afiyet olsun!', style: theme.textTheme.headlineMedium)),
        const SizedBox(height: 18),
        const SectionTitle('Dolabından düşülecekler', icon: '🧺'),
        if (_deductions.isEmpty)
          const Text('Dolabından düşülecek malzeme yok.')
        else ...[
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_DeductMode>(
              segments: const [
                ButtonSegment(value: _DeductMode.all, label: Text('Tamamı')),
                ButtonSegment(value: _DeductMode.half, label: Text('Yarısı')),
                ButtonSegment(
                    value: _DeductMode.custom, label: Text('Düzenle')),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < _deductions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  Builder(builder: (_) {
                    final d = _deductions[i];
                    final ing = repo.byId(d.ingredientId);
                    final amount = formatBase(
                        ing, UnitConverter.gramsToBase(ing, _gramsFor(d)));
                    final checked = _selected.contains(d.ingredientId);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          FoodIcon(ing.emoji, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(ing.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                          if (_mode == _DeductMode.custom)
                            Checkbox(
                              value: checked,
                              onChanged: (on) => setState(() => on == true
                                  ? _selected.add(d.ingredientId)
                                  : _selected.remove(d.ingredientId)),
                            )
                          else
                            Pill('− $amount',
                                color: Palette.tomatoSoft,
                                fg: Palette.tomatoDeep,
                                border: null),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        const SectionTitle('Nasıl oldu?', icon: '⭐'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                button: true,
                label: '$i yıldız',
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _rating = i),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Opacity(
                      opacity: (_rating ?? 0) >= i ? 1 : 0.25,
                      child: const Sym('⭐', size: 48),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Not (sonraki sefere)',
            hintText: 'Örn. Tuzu azalttım',
          ),
        ),
        const SizedBox(height: 24),
        ChunkyButton(label: 'Kaydet', icon: '✅', onPressed: _save),
      ],
    );
  }

  Widget _buildReward(BuildContext context) {
    final theme = Theme.of(context);
    final o = _outcome!;
    final perWeek = context.read<AppState>().weeklyGoal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: Palette.butterSoft,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Palette.butter, width: 2),
          ),
          child: Column(
            children: [
              const Sym('🔥', size: 120),
              Text(
                o.weeklyStreak > 0
                    ? '${o.weeklyStreak} haftalık seri!'
                    : 'Bu hafta ${o.cooksThisWeek}/$perWeek pişirme',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              WeeklySlots(done: o.cooksThisWeek, goal: perWeek, size: 52),
              const SizedBox(height: 12),
              Text(
                o.cooksThisWeek >= perWeek
                    ? 'Bu haftanın hedefi tamam!'
                    : 'Seriyi sürdürmek için bu hafta ${perWeek - o.cooksThisWeek} pişirme daha',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _plateCard(context),
        const SizedBox(height: 14),
        if (o.rescuedGrams > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              child: Row(
                children: [
                  const SymBubble('🌱', size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        '${formatGrams(o.rescuedGrams)} gıdayı israftan kurtardın',
                        style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
            ),
          ),
        for (final t in _recipe.techniques)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              child: Row(
                children: [
                  SymBubble(t.emoji, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Beceri: ${t.label} +1',
                        style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        ChunkyButton(
          label: 'Hikâyede paylaş',
          icon: '📲',
          tone: ChunkyTone.butter,
          onPressed: () =>
              showShareCard(context, _recipe, photoPath: _photo),
        ),
        const SizedBox(height: 10),
        ChunkyButton(
          label: 'Ana sayfaya dön',
          icon: '🏠',
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    );
  }
}

extension on _CookedScreenState {
  /// "Senin tabağın": yenen porsiyon (günlük takip), fotoğraf ve paylaşım.
  Widget _plateCard(BuildContext context) {
    final theme = Theme.of(context);
    final n = context.read<AppState>().matcher.factsOf(_recipe).perServing;
    final photo = _photo != null && !kIsWeb ? File(_photo!) : null;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Sym('🍽', size: 32),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Senin tabağın',
                      style: theme.textTheme.titleMedium)),
              IconButton.filledTonal(
                icon: const Icon(Icons.remove_rounded),
                tooltip: 'Daha az',
                onPressed: _portions > 0.5
                    ? () => _setPortions(_portions - 0.5)
                    : null,
              ),
              Text('${formatNumber(_portions)} porsiyon',
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              IconButton.filledTonal(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Daha çok',
                onPressed: _portions < widget.servings
                    ? () => _setPortions(_portions + 0.5)
                    : null,
              ),
            ],
          ),
          Text(
              'Bugüne eklendi: ${formatNumber(n.kcal * _portions, decimals: 0)} kcal · '
              '${formatNumber(n.protein * _portions, decimals: 0)} g protein',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          if (photo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(photo,
                  height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: ChunkyButton(
                  label: photo == null ? 'Fotoğraf ekle' : 'Yeniden çek',
                  icon: '📷',
                  tone: ChunkyTone.soft,
                  height: 48,
                  onPressed: _addPhoto,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChunkyButton(
                  label: 'Hikâye',
                  icon: '📲',
                  tone: ChunkyTone.butter,
                  height: 48,
                  onPressed: () =>
                      showShareCard(context, _recipe, photoPath: _photo),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
