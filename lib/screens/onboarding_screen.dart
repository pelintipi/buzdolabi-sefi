import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/ui.dart';

/// Açılış anketi: karşılama, 4 kısa soru (Profil'den açılınca 7) ve "senin için ayarladıklarım" özeti.
/// Her cevap uygulamada bir şeyi değiştirir (soru altında neyi değiştirdiği
/// yazar). Her soru geçilebilir; cevaplar Profil'den sonra da değiştirilebilir.
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

  late UserProfile _p = context.read<AppState>().profile;

  /// Aletler kullanıcı seçmeden işaretli gelmez. Profil'den yeniden
  /// doldururken daha önce kendi seçtikleri işaretli gelir.
  late Set<Appliance> _appliances =
      _p.appliancesAsked ? {..._p.appliances} : {};

  /// İlk açılışta yalnızca 4 temel soru sorulur; kalanlar (kaç gün, tarif
  /// saklama, plan saati) ana sayfada yeri gelince ya da Profil'den sorulur.
  bool get _full => widget.onDone != null;

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

  /// Tek seçimli sorularda seçim görünsün diye kısa bir bekleyişten sonra geçer.
  void _pickAndNext(UserProfile p) {
    setState(() => _p = p);
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) _next();
    });
  }

  /// Anketin sonundaki profil. Aletler seçilmediyse (soru geçildiyse)
  /// varsayılan Ocak + Fırın kalır ve alet sorusu ilk pişirmeden sonra
  /// yeniden sorulur.
  UserProfile get _result => _p.copyWith(
        appliances: _appliances.isEmpty ? null : _appliances,
        appliancesAsked: _appliances.isNotEmpty,
      );

  void _finish() {
    final state = context.read<AppState>();
    state.updateProfile(_result.copyWith(
      onboarded: true,
      diet: _p.eating?.diet ?? _p.diet,
    ));
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
        ),
        if (_full)
          _Question<int>.single(
            emoji: '📊',
            title: 'Haftada kaç gün yemek yapıyorsun?',
            why:
                'Haftalık hedefini buna göre koyarız; seriyi tutmak zorlaşmasın.',
            options: _days,
            selected: _p.cookDaysPerWeek,
            onPick: (v) => _pickAndNext(_p.copyWith(cookDaysPerWeek: v)),
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
          onPick: (v) => _pickAndNext(_p.copyWith(household: v)),
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
          onPick: (v) => _pickAndNext(_p.copyWith(eating: v)),
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
            onPick: (v) => _pickAndNext(_p.copyWith(planTime: v)),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final questions = _questions();
    final count = questions.length;
    final inQuestions = _page >= 1 && _page <= count;
    return Scaffold(
      body: SafeArea(
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
                  _Welcome(count: count, onStart: _next, onSkip: _finish),
                  ...questions,
                  _Done(profile: _result, onDone: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome(
      {required this.count, required this.onStart, required this.onSkip});

  final int count;

  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
            decoration: BoxDecoration(
              color: Palette.basil,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FoodIcon('🥚', size: 52),
                    SizedBox(width: 6),
                    FoodIcon('🥕', size: 72),
                    SizedBox(width: 6),
                    FoodIcon('🍅', size: 56),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Hoş geldin!',
                    style: TextStyle(
                        fontFamily: Fonts.serif,
                        fontSize: 46,
                        height: 1.05,
                        color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Seni biraz tanıyalım, tarifleri sana göre ayarlayalım. '
                  '$count kısa soru, ${count <= 4 ? '20 saniye' : 'yarım dakika'}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: Fonts.body,
                      fontWeight: FontWeight.w500,
                      fontSize: 15.5,
                      height: 1.45,
                      color: Color(0xFFD6E2DA)),
                ),
              ],
            ),
          ),
          const Spacer(),
          ChunkyButton(
              label: 'Başlayalım',
              icon: '✨',
              tone: ChunkyTone.butter,
              onPressed: onStart),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onSkip,
            child: Text('Şimdilik geç',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: Palette.inkSoft)),
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
  })  : selectedOne = selected,
        selectedMany = null,
        onToggle = null,
        onNext = null,
        minSelected = 0;

  const _Question.multi({
    super.key,
    required this.emoji,
    required this.title,
    required this.why,
    required this.options,
    required Set<T> selected,
    required ValueChanged<T> this.onToggle,
    required VoidCallback this.onNext,
    this.minSelected = 0,
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Center(child: SymBubble(emoji, size: 88, color: Palette.butterSoft)),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(why,
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodyMedium?.copyWith(color: Palette.inkSoft)),
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
        if (_multi) ...[
          const SizedBox(height: 6),
          ChunkyButton(
            label: selectedMany!.length < minSelected
                ? 'En az birini seç'
                : selectedMany!.isEmpty
                    ? 'Devam'
                    : 'Devam (${selectedMany!.length})',
            tone: ChunkyTone.accent,
            onPressed: selectedMany!.length < minSelected ? null : onNext,
          ),
        ],
      ],
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
                Sym(emoji, size: 34),
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
        Text('Hepsini Profil\'den istediğin zaman değiştirebilirsin.',
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
