import 'dart:async';

import '../models/user_profile.dart';
import '../services/device_services.dart';
import '../services/recipe_matcher.dart';
import '../utils/format.dart';
import 'app_state.dart';

/// Ana ekran aracında ve bildirimlerde gösterilen özet: bugün yapılabilen
/// tarifler ve bozulmak üzere olanlar. Hepsi telefonda hesaplanır.
class Digest {
  Digest(this.state, this.now);

  final AppState state;
  final DateTime now;

  late final List<RecipeMatch> ready = state
      .matches(const QuickFilters())
      .where((m) => m.problems.isEmpty)
      .take(3)
      .toList();

  late final expiring = state.expiringItems;

  /// Bozulmak üzere olan malzemeyi kullanan tarif: önce hemen yapılabilen,
  /// yoksa tek malzemesi eksik olan. ("Kıymayı değerlendir: Kıymalı Pilav")
  late final ({RecipeMatch match, String ingredient})? useUp = () {
    if (expiring.isEmpty) return null;
    final ids = [for (final p in expiring) p.ingredientId];
    final candidates = state
        .matches(const QuickFilters())
        .where((m) => m.usesExpiring && m.problems.length <= 1)
        .toList()
      ..sort((a, b) => a.problems.length.compareTo(b.problems.length));
    for (final m in candidates) {
      // En yakın tarihte bozulacak malzemeyi kullanan tarif öne çıkar.
      for (final id in ids) {
        if (m.recipe.items.any((i) => i.ingredientId == id)) {
          return (match: m, ingredient: state.repo.byId(id).name);
        }
      }
    }
    return null;
  }();

  /// iOS ana ekran aracına (WidgetKit) giden veri. ios/HomeWidget aynı
  /// anahtarları okur.
  Map<String, Object?> widgetData() => {
        'updatedAt': now.toIso8601String(),
        'readyCount': state
            .matches(const QuickFilters())
            .where((m) => m.problems.isEmpty)
            .length,
        'recipes': [
          for (final m in ready)
            {
              'title': m.recipe.title,
              'emoji': m.recipe.emoji,
              'minutes': m.recipe.minutes,
              'kcal': m.facts.perServing.kcal.round(),
            }
        ],
        'expiringCount': expiring.length,
        'expiring': [
          for (final p in expiring.take(3))
            {
              'name': state.repo.byId(p.ingredientId).name,
              'days': daysUntil(p.expiresAt!, now),
            }
        ],
        if (useUp != null)
          'useUp': {
            'ingredient': useUp!.ingredient,
            'title': useUp!.match.recipe.title,
            'emoji': useUp!.match.recipe.emoji,
            'ready': useUp!.match.problems.isEmpty,
          },
      };

  static (int, int) _hourFor(PlanTime t) => switch (t) {
        PlanTime.morning => (9, 0),
        PlanTime.noon => (12, 30),
        PlanTime.evening => (17, 0),
        PlanTime.lastMinute => (18, 30),
      };

  /// Hatırlatmalar: her gün anketteki plan saatinde bir öneri, bozulacak ürün
  /// varsa o gün sabah bir uyarı. Uygulama her açıldığında yeniden kurulur;
  /// içerik o anki dolaba göredir.
  List<Reminder> reminders() {
    if (!state.profile.remindersOn) return const [];
    final out = <Reminder>[];
    final (h, m) = _hourFor(state.profile.planTime ?? PlanTime.evening);
    var at = DateTime(now.year, now.month, now.day, h, m);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    out.add(Reminder(
      id: 1,
      title: 'Bugün ne pişirsem?',
      body: ready.isEmpty
          ? 'Dolabına bir bakalım, eksik bir malzemeyle açılan tarifler var.'
          : 'Dolabındakilerle hazır: ${ready.map((m) => m.recipe.title).join(', ')}',
      at: at,
      daily: true,
    ));
    var id = 100;
    for (final p in expiring.take(5)) {
      final ing = state.repo.byId(p.ingredientId);
      final expires = p.expiresAt!;
      // Bozulmadan bir gün önce sabah 10'da; o saat geçtiyse hiç.
      final warn = DateTime(expires.year, expires.month, expires.day - 1, 10);
      if (!warn.isAfter(now)) continue;
      out.add(Reminder(
        id: id++,
        title: '${ing.name} yarın bozuluyor',
        body: 'Değerlendiren tariflere bak, çöpe gitmesin.',
        at: warn,
      ));
    }
    return out;
  }
}

/// Durum değiştikçe (2 sn bekleyip) ana ekran aracını ve hatırlatmaları
/// günceller. iOS dışında sessizce hiçbir şey yapmaz.
class DigestSync {
  DigestSync(this.state, this.services) {
    state.addListener(_schedule);
    _schedule();
  }

  final AppState state;
  final DeviceServices services;
  Timer? _debounce;
  bool _remindersWereOn = false;

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _push);
  }

  Future<void> _push() async {
    final d = Digest(state, DateTime.now());
    await services.native.updateWidget(d.widgetData());
    if (state.profile.remindersOn) {
      _remindersWereOn = true;
      await services.reminders.replaceAll(d.reminders());
    } else if (_remindersWereOn) {
      _remindersWereOn = false;
      await services.reminders.cancelAll();
    }
  }

  void dispose() {
    _debounce?.cancel();
    state.removeListener(_schedule);
  }
}
