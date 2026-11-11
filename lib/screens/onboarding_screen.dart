import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/other_allergies.dart';
import '../widgets/ui.dart';

/// Açılış anketi: karşılama, kısa sorular (Profil'den açılınca ekstra)
/// ve "senin için ayarladıklarım" özeti. Alerji ve "evde hep olanlar"
/// burada sorulur; Profil'de sabit blok olarak durmaz.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onDone});

  /// Profil'den yeniden açıldığında kapanırken çağrılır.
  final VoidCallback? onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// Bir sorunun seçeneği.
class _Option<T> {
  const _Option(this.value, this.label, this.emoji);

  final T value;
  final String label;
  final String emoji;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  /// İlk açılışta temel sorular; kalanlar (kaç gün, tarif saklama, plan
  /// saati) ana sayfada yeri gelince ya da Profil'den sorulur.
  bool get _full => widget.onDone != null;

  late final UserProfile _saved = context.read<AppState>().profile;

  /// Profil'den "yeniden doldur" → seçenekler boş. Tema/hatırlatma korunur.
  late UserProfile _p = _full
      ? UserProfile(
          onboarded: _saved.onboarded,
          remindersOn: _saved.remindersOn,
          dailyKcal: _saved.dailyKcal,
          dailyProtein: _saved.dailyProtein,
          dailyFiber: _saved.dailyFiber,
          uiTheme: _saved.uiTheme,
          seenNavTour: _saved.seenNavTour,
        )
      : _saved;

  /// Aletler kullanıcı seçmeden işaretli gelmez (ilk açılış ve yeniden doldur).
  late Set<Appliance> _appliances = {};

  /// Her zaman boş başlar; eski cevaplar işaretli gelmez.
  late Set<Allergen> _allergies = {};

  /// "Diğer" diye yazılan alerjiler.
  List<String> _customAllergies = const [];

  /// İşaretli = evde var. Kullanıcı seçer (arama ile de ekler).
  late Set<String> _haveIds = {};

  /// Aramayla eklenen (temel listede olmayan) seçenekler.
  late List<_Option<String>> _extraHave = [];

  static const _days = [
    _Option(2, '1-2 gün', '🌱'),
    _Option(3, '3-4 gün', '🍳'),
    _Option(5, '5-6 gün', '🔥'),
    _Option(7, 'Her gün', '🏆'),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    setState(() => _page = page);
    _pages.animateToPage(page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic);
  }

  void _next() => _go(_page + 1);

  static Set<T> _toggle<T>(Set<T> s, T v) {
    final out = Set<T>.of(s);
    if (!out.remove(v)) out.add(v);
    return out;
  }

  Set<String> get _missingStaples {
    final ids = context.read<AppState>().repo.staples.map((s) => s.id);
    return {
      for (final id in ids)
        if (!_haveIds.contains(id)) id
    };
  }

  List<_Option<String>> get _haveOptions {
    final repo = context.read<AppState>().repo;
    final seen = <String>{};
    final out = <_Option<String>>[];
    for (final s in repo.staples) {
      seen.add(s.id);
      out.add(_Option(s.id, s.name, s.emoji));
    }
    for (final o in _extraHave) {
      if (seen.add(o.value)) out.add(o);
    }
    return out;
  }

  /// Anketin sonundaki profil. Aletler seçilmediyse (soru geçildiyse)
  /// varsayılan Ocak + Fırın kalır ve alet sorusu ilk pişirmeden sonra
  /// yeniden sorulur.
  UserProfile get _result => _p.copyWith(
        appliances: _appliances.isEmpty ? null : _appliances,
        appliancesAsked: _appliances.isNotEmpty,
        allergies: _allergies,
        customAllergies: _customAllergies,
        allergyAsked: true,
        missingStaples: _missingStaples,
      );

  /// [fromSurvey]: soruları gördü (veya Geç ile geçti). Karşılama
  /// "Şimdilik geç" alerjiyi sormadı → recipe dialog kalsın.
  void _finish({bool fromSurvey = false}) {
    final state = context.read<AppState>();
    final base = fromSurvey ? _result : _p;
    state.updateProfile(base.copyWith(
      onboarded: true,
      diet: (fromSurvey ? _p.eating?.diet : null) ?? _p.diet,
    ));
    if (fromSurvey) {
      final extras = [
        for (final id in _haveIds)
          if (state.repo.tryById(id) case final ing? when !ing.isStaple)
            (ingredientId: id, quantity: 1.0, level: null),
      ];
      if (extras.isNotEmpty) state.upsertPantryAll(extras);
    }
    widget.onDone?.call();
  }

  List<Widget> _questions() => [
        _Question<Goal>.multi(
          emoji: '🧑‍🍳',
          title: 'Seni buraya ne getirdi?',
          why: 'Birden çok seçebilirsin. Ana sayfayı buna göre düzenleriz.',
          options: [for (final g in Goal.values) _Option(g, g.label, g.emoji)],
          selected: _p.goals,
          onToggle: (v) =>
              setState(() => _p = _p.copyWith(goals: _toggle(_p.goals, v))),
          onNext: _next,
          minSelected: 1,
        ),
        if (_full)
          _Question<int>.single(
            emoji: '📊',
            title: 'Haftada kaç gün yemek yapıyorsun?',
            why:
                'Haftalık hedefini buna göre koyarız; seriyi tutmak zorlaşmasın.',
            options: _days,
            selected: _p.cookDaysPerWeek,
            onPick: (v) => setState(() => _p = _p.copyWith(cookDaysPerWeek: v)),
            onNext: _next,
          ),
        _Question<Household>.single(
          emoji: '🍽',
          title: 'Kimin için yemek yapıyorsun?',
          why:
              'Tarifler bu kadar kişilik açılır, miktarlar ona göre hesaplanır.',
          options: [
            for (final h in Household.values) _Option(h, h.label, h.emoji)
          ],
          selected: _p.household,
          onPick: (v) => setState(() => _p = _p.copyWith(household: v)),
          onNext: _next,
        ),
        _Question<Appliance>.multi(
          emoji: '🔥',
          title: 'Nelerle pişiriyorsun?',
          why: 'Olmayan bir aletle yapılan tarifleri sana göstermeyiz.',
          options: [
            for (final a in Appliance.values) _Option(a, a.label, a.emoji)
          ],
          selected: _appliances,
          onToggle: (v) =>
              setState(() => _appliances = _toggle(_appliances, v)),
          onNext: _next,
          minSelected: 1,
        ),
        _Question<EatingStyle>.single(
          emoji: '🥗',
          title: 'Nasıl besleniyorsun?',
          why: 'Sonuçları buna göre sıralarız; vejetaryen ve vegan seçersen '
              'uymayan tarifler hiç çıkmaz.',
          options: [
            for (final e in EatingStyle.values) _Option(e, e.label, e.emoji)
          ],
          selected: _p.eating,
          onPick: (v) => setState(() => _p = _p.copyWith(eating: v)),
          onNext: _next,
        ),
        _Question<Allergen>.multi(
          emoji: '⚠',
          title: 'Alerjin var mı?',
          why:
              'Seçtiklerini içeren tarifler hiç çıkmaz. "Kuruyemiş" hepsini gizler; '
              "yalnızca biri (ör. ceviz) içinse Diğer'e yaz. Yoksa boş bırak. "
              'Bu bilgi yalnızca telefonunda saklanır.',
          options: [
            for (final a in Allergen.values) _Option(a, a.label, a.emoji)
          ],
          selected: _allergies,
          onToggle: (v) => setState(() => _allergies = _toggle(_allergies, v)),
          onNext: _next,
          minSelected: 0,
          footer: OtherAllergies(
            values: _customAllergies,
            onChanged: (v) => setState(() => _customAllergies = v),
          ),
          extraCount: _customAllergies.length,
        ),
        _SearchableHavePage(
          options: _haveOptions,
          selected: _haveIds,
          onToggle: (id) => setState(() => _haveIds = _toggle(_haveIds, id)),
          onAddFromSearch: (ing) {
            setState(() {
              _haveIds = {..._haveIds, ing.id};
              final known = context
                      .read<AppState>()
                      .repo
                      .staples
                      .any((s) => s.id == ing.id) ||
                  _extraHave.any((o) => o.value == ing.id);
              if (!known) {
                _extraHave = [
                  ..._extraHave,
                  _Option(ing.id, ing.name, ing.emoji),
                ];
              }
            });
          },
          onNext: _next,
        ),
        if (_full)
          _Question<RecipeHabit>.multi(
            emoji: '📝',
            title: 'Tariflerini nasıl saklıyorsun?',
            why:
                'Videodan kaydediyorsan sosyal medyadan tek dokunuşla eklemeyi '
                'öne çıkarırız.',
            options: [
              for (final h in RecipeHabit.values) _Option(h, h.label, h.emoji)
            ],
            selected: _p.habits,
            onToggle: (v) =>
                setState(() => _p = _p.copyWith(habits: _toggle(_p.habits, v))),
            onNext: _next,
            minSelected: 1,
          ),
        if (_full)
          _Question<PlanTime>.single(
            emoji: '⏱',
            title: 'Yemeği genelde ne zaman düşünürsün?',
            why: 'Ana sayfayı o ana göre hazırlarız.',
            options: [
              for (final t in PlanTime.values) _Option(t, t.label, t.emoji)
            ],
            selected: _p.planTime,
            onPick: (v) => setState(() => _p = _p.copyWith(planTime: v)),
            onNext: _next,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final questions = _questions();
    final count = questions.length;
    final inQuestions = _page >= 1 && _page <= count;
    return Scaffold(
      body: SafeArea(
        top: _page != 0,
        child: Column(
          children: [
            if (inQuestions)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Geri',
                      onPressed: () => _go(_page - 1),
                    ),
                    Expanded(
                      child: ChunkyProgress(value: _page / count),
                    ),
                    TextButton(onPressed: _next, child: const Text('Geç')),
                  ],
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Welcome(
                      count: count, onStart: _next, onSkip: () => _finish()),
                  ...questions,
                  _Done(
                      profile: _result,
                      onDone: () => _finish(fromSurvey: true)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Karşılama: üstte yeşil zeminde süzülen malzemeler ve başlık, altta
/// uygulamanın üç ana işi ve "Başlayalım".
class _Welcome extends StatefulWidget {
  const _Welcome(
      {required this.count, required this.onStart, required this.onSkip});

  final int count;

  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome>
    with SingleTickerProviderStateMixin {
  late final _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 5));

  /// (emoji, yatay konum 0-1, dikey konum 0-1, boyut, eğim, faz)
  static const _foods = [
    ('🥕', 0.06, 0.08, 60.0, -0.35, 0.0),
    ('🍅', 0.80, 0.05, 62.0, 0.20, 0.3),
    ('🥚', 0.90, 0.50, 46.0, 0.30, 0.6),
    ('🧀', 0.02, 0.55, 50.0, -0.15, 0.8),
    ('🥑', 0.18, 0.92, 48.0, 0.25, 0.2),
    ('🍋', 0.70, 0.94, 44.0, -0.30, 0.5),
    ('🍄', 0.46, 0.00, 38.0, 0.10, 0.9),
    ('🌿', 0.96, 0.86, 36.0, 0.40, 0.4),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Hareketi azalt" açıksa malzemeler yerinde durur; açık değilse
    // yaklaşık 20 saniye süzülüp durur (pil ve dikkat dağıtmasın).
    if (MediaQuery.of(context).disableAnimations) {
      _float.stop();
    } else if (!_started) {
      _started = true;
      _float.repeat(count: 4);
    }
  }

  bool _started = false;

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: Palette.basil,
            padding: EdgeInsets.only(top: top + 8, bottom: 36),
            child: LayoutBuilder(builder: (context, c) {
              return Stack(
                children: [
                  for (final f in _foods)
                    AnimatedBuilder(
                      animation: _float,
                      builder: (context, child) {
                        final t = (_float.value + f.$6) * 2 * math.pi;
                        return Positioned(
                          left: f.$2 * (c.maxWidth - f.$4),
                          top: f.$3 * (c.maxHeight - f.$4 - 12) +
                              6 +
                              6 * math.sin(t),
                          child: Transform.rotate(
                              angle: f.$5 + 0.06 * math.sin(t + 1),
                              child: child),
                        );
                      },
                      child:
                          ExcludeSemantics(child: FoodIcon(f.$1, size: f.$4)),
                    ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('BUZDOLABI ŞEFİ',
                                style: TextStyle(
                                    fontFamily: Fonts.display,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    letterSpacing: 1.6,
                                    color: Color(0xFFD6E2DA))),
                          ),
                          const SizedBox(height: 14),
                          const Text('Hoş geldin!',
                              style: TextStyle(
                                  fontFamily: Fonts.serif,
                                  fontSize: 54,
                                  height: 1.0,
                                  color: Colors.white)),
                          const SizedBox(height: 10),
                          const Text(
                            'Dolabında ne varsa söyle,\nondan ne pişer biz bulalım.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: Fonts.body,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                height: 1.45,
                                color: Color(0xFFD6E2DA)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Palette.ground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Perk(IconBubble('🥘', size: 46), 'Dolabındakiyle tarif',
                    'Elindeki malzemelerle ne pişirebileceğini gösterir.'),
                const _Perk(SymBubble('🎬', size: 46), 'Sosyal medyadan kaydet',
                    'TikTok, Instagram, YouTube tarifleri tek dokunuşla.'),
                const _Perk(IconBubble('🛒', size: 46), 'Eksikler listede',
                    'Eksik malzemeler alışveriş listene kendiliğinden düşer.'),
                const SizedBox(height: 8),
                ChunkyButton(
                    label: 'Başlayalım',
                    iconData: Icons.arrow_forward_rounded,
                    tone: ChunkyTone.primary,
                    onPressed: widget.onStart),
                const SizedBox(height: 8),
                Text(
                  '${widget.count} kısa soru · '
                  '${widget.count <= 4 ? '20 saniye' : 'yarım dakika'}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Palette.inkSoft),
                ),
                TextButton(
                  onPressed: widget.onSkip,
                  child: Text('Şimdilik geç',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: Palette.inkSoft)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Karşılamadaki tek satırlık özellik.
class _Perk extends StatelessWidget {
  const _Perk(this.leading, this.title, this.text);

  final Widget leading;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(text,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Palette.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Evde olanlar: temel liste + arama ile herhangi bir malzeme.
class _SearchableHavePage extends StatefulWidget {
  const _SearchableHavePage({
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onAddFromSearch,
    required this.onNext,
  });

  final List<_Option<String>> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<Ingredient> onAddFromSearch;
  final VoidCallback onNext;

  @override
  State<_SearchableHavePage> createState() => _SearchableHavePageState();
}

class _SearchableHavePageState extends State<_SearchableHavePage> {
  final _query = TextEditingController();
  List<Ingredient> _hits = const [];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    final repo = context.read<AppState>().repo;
    setState(() => _hits = repo.search(q, limit: 12));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Center(
                    child:
                        SymBubble('🧂', size: 88, color: Palette.butterSoft)),
                const SizedBox(height: 12),
                Text('Evde genelde neler var?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                    'İşaretlediklerin her tarifte var sayılır. Listede yoksa ara.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Palette.inkSoft)),
                const SizedBox(height: 14),
                TextField(
                  controller: _query,
                  onChanged: _onQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Malzeme ara…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Temizle',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _query.clear();
                              _onQuery('');
                            },
                          ),
                  ),
                ),
                if (_hits.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final ing in _hits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OptionTile(
                        label: ing.name,
                        emoji: ing.emoji,
                        selected: widget.selected.contains(ing.id),
                        multi: true,
                        onTap: () => widget.onAddFromSearch(ing),
                      ),
                    ),
                  const Divider(height: 24),
                ],
                const SizedBox(height: 6),
                for (final o in widget.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionTile(
                      label: o.label,
                      emoji: o.emoji,
                      selected: widget.selected.contains(o.value),
                      multi: true,
                      onTap: () => widget.onToggle(o.value),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ChunkyButton(
            label: widget.selected.isEmpty
                ? 'Devam'
                : 'Devam (${widget.selected.length})',
            tone: ChunkyTone.accent,
            onPressed: widget.onNext,
          ),
        ],
      ),
    );
  }
}

/// Tek ya da çok seçimli soru sayfası.
class _Question<T> extends StatelessWidget {
  const _Question.single({
    super.key,
    required this.emoji,
    required this.title,
    required this.why,
    required this.options,
    required T? selected,
    required ValueChanged<T> this.onPick,
    required VoidCallback this.onNext,
  })  : selectedOne = selected,
        selectedMany = null,
        onToggle = null,
        minSelected = 0,
        footer = null,
        extraCount = 0;

  const _Question.multi({
    super.key,
    required this.emoji,
    required this.title,
    required this.why,
    required this.options,
    required Set<T> selected,
    required ValueChanged<T> this.onToggle,
    required VoidCallback this.onNext,
    this.minSelected = 1,
    this.footer,
    this.extraCount = 0,
  })  : selectedMany = selected,
        selectedOne = null,
        onPick = null;

  final String emoji;
  final String title;

  /// Cevabın uygulamada neyi değiştirdiği.
  final String why;
  final List<_Option<T>> options;
  final T? selectedOne;
  final Set<T>? selectedMany;
  final ValueChanged<T>? onPick;

  /// Çok seçimlide dokunulan seçenek; sahibi güncel seçime göre ekler/çıkarır.
  final ValueChanged<T>? onToggle;
  final VoidCallback? onNext;

  /// Çok seçimlide "Devam" için gereken en az seçim.
  final int minSelected;

  /// Seçeneklerin altına eklenen parça ("Diğer" alerjiler).
  final Widget? footer;

  /// Seçeneklerin dışında seçilmiş sayılanlar ("Devam (3)" sayısına girer).
  final int extraCount;

  bool get _multi => selectedMany != null;

  bool _isSelected(T v) =>
      _multi ? selectedMany!.contains(v) : selectedOne == v;

  void _tap(T v) {
    if (!_multi) {
      onPick!(v);
      return;
    }
    onToggle!(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devam = onNext == null
        ? null
        : ChunkyButton(
            label: !_multi
                ? (selectedOne == null ? 'Birini seç' : 'Devam')
                : selectedMany!.length < minSelected
                    ? 'En az birini seç'
                    : selectedMany!.length + extraCount == 0
                        ? 'Devam'
                        : 'Devam (${selectedMany!.length + extraCount})',
            tone: ChunkyTone.accent,
            onPressed: !_multi
                ? (selectedOne == null ? null : onNext)
                : (selectedMany!.length < minSelected ? null : onNext),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Center(
                    child:
                        SymBubble(emoji, size: 88, color: Palette.butterSoft)),
                const SizedBox(height: 12),
                Text(title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(why,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Palette.inkSoft)),
                const SizedBox(height: 18),
                for (final o in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionTile(
                      label: o.label,
                      emoji: o.emoji,
                      selected: _isSelected(o.value),
                      multi: _multi,
                      onTap: () => _tap(o.value),
                    ),
                  ),
                if (footer != null) footer!,
              ],
            ),
          ),
          if (devam != null) ...[
            const SizedBox(height: 8),
            devam,
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.multi,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: selected ? Palette.basilSoft : Palette.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: selected ? Palette.basil : Palette.line,
                  width: selected ? 1.6 : 1),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0F3A2A1E),
                    blurRadius: 14,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                FoodIcon(emoji, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: selected ? Palette.basil : Colors.transparent,
                    shape: multi ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: multi ? BorderRadius.circular(8) : null,
                    border: Border.all(
                        color: selected ? Palette.basil : Palette.lineDeep,
                        width: 2),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Son sayfa: cevapların uygulamada neyi değiştirdiği.
class _Done extends StatelessWidget {
  const _Done({required this.profile, required this.onDone});

  final UserProfile profile;
  final VoidCallback onDone;

  List<(String, String)> get _lines {
    final p = profile;
    return [
      if (p.cookDaysPerWeek != null)
        ('🏆', 'Haftalık hedefin: ${p.cookDaysPerWeek} pişirme'),
      if (p.household != null)
        ('🍽', 'Tarifler ${p.household!.servings} kişilik açılacak'),
      if (p.appliances.isNotEmpty)
        ('🔥', 'Mutfağın: ${p.appliances.map((a) => a.label).join(', ')}'),
      if (p.eating == EatingStyle.protein)
        ('💪', 'Proteini yüksek tarifler önde'),
      if (p.eating == EatingStyle.light) ('🪶', 'Hafif tarifler önde'),
      if (p.eating?.diet == Diet.vegetarian)
        ('🥦', 'Yalnızca vejetaryen tarifler'),
      if (p.eating?.diet == Diet.vegan) ('🌱', 'Yalnızca vegan tarifler'),
      if (p.savesVideos)
        ('🎬', 'Sosyal medyadan tarif kaydetme ana sayfada en önde'),
      if (p.planTime != null) (p.planTime!.emoji, p.planTime!.homeLine),
      if (p.allergyAsked && p.allergies.isEmpty && p.customAllergies.isEmpty)
        ('✅', 'Alerji filtresi kapalı'),
      if (p.allergies.isNotEmpty || p.customAllergies.isNotEmpty)
        (
          '⚠',
          'Gizlenen alerjenler: ${[
            ...p.allergies.map((a) => a.label),
            ...p.customAllergies
          ].join(', ')}'
        ),
      if (p.missingStaples.isNotEmpty)
        ('🧂', '${p.missingStaples.length} temel malzeme evde yok sayılacak'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        const Center(child: Sym('🎉', size: 96)),
        const SizedBox(height: 8),
        Text('Hazırsın!',
            textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text('Senin için şunları ayarladım:',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: Palette.inkSoft)),
        const SizedBox(height: 16),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < _lines.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Sym(_lines[i].$1, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_lines[i].$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Anketi Profil\'den yeniden doldurarak güncelleyebilirsin.',
            textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        const SizedBox(height: 18),
        ChunkyButton(
            label: 'Mutfağa geç',
            icon: '🍳',
            tone: ChunkyTone.accent,
            onPressed: onDone),
      ],
    );
  }
}
