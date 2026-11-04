import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../models/pantry_item.dart';
import '../services/device_services.dart';
import '../services/quantity_parser.dart';
import '../services/recipe_matcher.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/amount_controls.dart';
import '../widgets/ui.dart';
import 'results_screen.dart';

const _quickIds = [
  'yumurta',
  'un',
  'sut',
  'domates',
  'sogan',
  'sivri_biber',
  'patates',
  'beyaz_peynir',
  'kasar',
  'yogurt',
  'tavuk_gogsu',
  'kiyma',
  'makarna',
  'pirinc',
  'mercimek',
  'ispanak',
  'kabak',
  'mantar',
  'ekmek',
  'tereyagi',
];

class IngredientInputScreen extends StatefulWidget {
  const IngredientInputScreen({super.key, this.openResultsAfter = false});

  /// "Ne pişirsem?" akışında kaydedince doğrudan sonuçlara geçilir.
  final bool openResultsAfter;

  @override
  State<IngredientInputScreen> createState() => _IngredientInputScreenState();
}

class _Draft {
  _Draft(this.ingredient, {this.quantity, this.level});

  final Ingredient ingredient;
  double? quantity;
  ApproxLevel? level;
}

class _IngredientInputScreenState extends State<IngredientInputScreen> {
  final _controller = TextEditingController();
  final _drafts = <_Draft>[];
  final _unrecognized = <String>[];
  List<Ingredient> _suggestions = const [];

  AppState get _state => context.read<AppState>();

  SpeechService? _speech;
  bool _listening = false;

  /// Sesle ekleme: "üç yumurta, iki domates, biraz peynir" demek yeter.
  Future<void> _toggleMic() async {
    if (_listening) {
      setState(() => _listening = false);
      await _speech?.stopListening();
      return;
    }
    _speech ??= DeviceServices.of(context).speech;
    setState(() => _listening = true);
    final ok = await _speech!.listen((words, isFinal) {
      if (!mounted) return;
      _controller.text = words;
      _onTextChanged(words);
      if (isFinal) {
        _submitText();
        setState(() => _listening = false);
      }
    }, onDone: () {
      if (mounted) setState(() => _listening = false);
    });
    if (!ok && mounted) {
      setState(() => _listening = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mikrofona ya da ses tanımaya izin verilmedi.')));
    }
  }

  /// Pişirdiğin tariflerde en sık geçen, şu an dolapta olmayan malzemeler.
  List<Ingredient> _frequent(AppState state) {
    final inPantry = {for (final p in state.pantry) p.ingredientId};
    final counts = <String, int>{};
    for (final log in state.logs) {
      final r = state.tryRecipe(log.recipeId);
      if (r == null) continue;
      for (final it in r.items) {
        if (it.optional || inPantry.contains(it.ingredientId)) continue;
        counts.update(it.ingredientId, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final ids = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return [
      for (final id in ids)
        if (state.repo.tryById(id) case final ing? when !ing.isStaple) ing
    ].take(8).toList();
  }

  @override
  void dispose() {
    _speech?.stopListening();
    _controller.dispose();
    super.dispose();
  }

  bool _has(String id) => _drafts.any((d) => d.ingredient.id == id);

  void _addDraft(Ingredient ing, {double? quantity, ApproxLevel? level}) {
    _drafts.removeWhere((d) => d.ingredient.id == ing.id);
    if (quantity == null && level == null) {
      final d = defaultAmountFor(ing);
      quantity = d.quantity;
      level = d.level;
    }
    _drafts.add(_Draft(ing, quantity: quantity, level: level));
  }

  void _onTextChanged(String text) {
    final lastChunk = text.split(RegExp(r'[,;\n]')).last;
    final words = lastChunk
        .replaceAll(RegExp(r'[\d.,]'), ' ')
        .trim()
        .split(RegExp(r'\s+'));
    final query = words.last;
    setState(() {
      _suggestions =
          query.length >= 2 ? _state.repo.search(query, limit: 6) : const [];
    });
  }

  void _submitText() {
    final entries = QuantityParser(_state.repo).parse(_controller.text);
    if (entries.isEmpty) return;
    setState(() {
      for (final e in entries) {
        final ing = e.ingredient;
        if (ing != null) {
          _addDraft(ing, quantity: e.quantity, level: e.level);
        } else {
          _unrecognized.add(e.raw);
        }
      }
      _controller.clear();
      _suggestions = const [];
    });
  }

  /// Yazılan son kelimeyi seçilen malzemeyle değiştirir; "3 yum" → "3 Yumurta".
  void _pickSuggestion(Ingredient ing) {
    final text = _controller.text;
    final cut = text.lastIndexOf(RegExp(r'[,;\n]'));
    final head = cut < 0 ? '' : text.substring(0, cut + 1);
    final chunk = (cut < 0 ? text : text.substring(cut + 1)).trimRight();
    final lastSpace = chunk.lastIndexOf(' ');
    final prefix = lastSpace < 0 ? '' : chunk.substring(0, lastSpace + 1);
    _controller.text = '$head$prefix${ing.name}';
    _submitText();
  }

  void _toggleQuick(Ingredient ing) {
    setState(() {
      if (_has(ing.id)) {
        _drafts.removeWhere((d) => d.ingredient.id == ing.id);
      } else {
        _addDraft(ing);
      }
    });
  }

  void _commit() {
    // Kutuda yazılı kalan malzemeler de alınır; + butonuna basmak şart değil.
    if (_controller.text.trim().isNotEmpty) _submitText();
    if (_drafts.isEmpty && _state.pantry.isEmpty) return;

    final state = _state;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    state.upsertPantryAll([
      for (final d in _drafts)
        (ingredientId: d.ingredient.id, quantity: d.quantity, level: d.level),
    ]);
    if (widget.openResultsAfter) {
      navigator.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const ResultsScreen()));
      return;
    }
    navigator.pop();
    final ready = state
        .matches(const QuickFilters())
        .where((m) => m.group == MatchGroup.ready)
        .length;
    messenger.showSnackBar(SnackBar(
      persist: false,
      content: Text(ready > 0
          ? 'Dolabın güncellendi. $ready tarifi hemen yapabilirsin.'
          : 'Dolabın güncellendi.'),
      action: SnackBarAction(
        label: 'Tarifleri gör',
        onPressed: () => navigator.push(
            MaterialPageRoute<void>(builder: (_) => const ResultsScreen())),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final quick = [for (final id in _quickIds) state.repo.byId(id)];
    final frequent = _frequent(state);
    final canCommit = _drafts.isNotEmpty ||
        _controller.text.trim().isNotEmpty ||
        (widget.openResultsAfter && state.pantry.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Dolabında ne var?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            'Elindekileri yaz ya da aşağıdan seç. Miktar yazmazsan biz tahmin ederiz.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Palette.inkSoft),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            onChanged: _onTextChanged,
            onSubmitted: (_) => _submitText(),
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            decoration: InputDecoration(
              hintText: 'Örn: 3 yumurta, yarım biber, biraz peynir',
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: Icon(_listening
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded),
                    color: _listening ? Palette.tomato : Palette.basil,
                    tooltip: _listening ? 'Dinlemeyi bitir' : 'Sesle ekle',
                    onPressed: _toggleMic,
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                        backgroundColor: Palette.basil,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Ekle',
                    onPressed: _submitText,
                  ),
                ]),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _suggestions)
                    ActionChip(
                      avatar: FoodIcon(s.emoji, size: 22),
                      label: Text(s.name),
                      onPressed: () => _pickSuggestion(s),
                    ),
                ],
              ),
            ),
          if (_unrecognized.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final raw in _unrecognized)
                    InputChip(
                      label: Text('Tanınmadı: $raw'),
                      backgroundColor: Palette.tomatoSoft,
                      side: BorderSide.none,
                      onDeleted: () =>
                          setState(() => _unrecognized.remove(raw)),
                    ),
                ],
              ),
            ),
          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: 18),
            SectionTitle('Eklenecekler (${_drafts.length})', icon: '🧺'),
            for (final d in _drafts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DraftTile(
                  draft: d,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => _drafts.remove(d)),
                ),
              ),
          ],
          if (_listening)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Dinliyorum… "üç yumurta, iki domates" gibi söyle.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Palette.tomato)),
            ),
          if (frequent.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionTitle('Sık kullandıkların', icon: '⏱'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ing in frequent)
                  FilterChip(
                    avatar: FoodIcon(ing.emoji, size: 22),
                    label: Text(ing.name),
                    selected: _has(ing.id),
                    showCheckmark: false,
                    onSelected: (_) => _toggleQuick(ing),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          const SectionTitle('Hızlı ekle', icon: '🛒'),
          LayoutBuilder(builder: (context, c) {
            const gap = 10.0;
            final w = (c.maxWidth - gap * 3) / 4;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final ing in quick)
                  _QuickTile(
                    ingredient: ing,
                    width: w,
                    selected: _has(ing.id),
                    onTap: () => _toggleQuick(ing),
                  ),
              ],
            );
          }),
          if (state.pantry.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Dolabında zaten ${state.pantry.length} malzeme var. '
                'Aynı malzemeyi eklersen miktarı güncellenir.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ChunkyButton(
            label: widget.openResultsAfter ? 'Tarifleri göster' : 'Dolaba ekle',
            icon: widget.openResultsAfter ? '🍽' : '🧺',
            tone: ChunkyTone.accent,
            onPressed: canCommit ? _commit : null,
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.ingredient,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final Ingredient ingredient;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          decoration: BoxDecoration(
            color: selected ? Palette.basilSoft : Palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? Palette.basil : Palette.line, width: 2),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FoodIcon(ingredient.emoji, size: 40),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 32,
                      child: Center(
                        child: Text(
                          ingredient.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              height: 1.15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  right: 0,
                  top: -4,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Palette.basil,
                    child: Icon(Icons.check_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final _Draft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ing = draft.ingredient;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          IconBubble(ing.emoji, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ing.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                _amountControl(),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Palette.inkSoft),
            tooltip: 'Çıkar',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  Widget _amountControl() {
    final ing = draft.ingredient;
    if (ing.baseUnit == BaseUnit.piece) {
      final value = draft.quantity ??
          math.max(
              1.0,
              (ing.packageAmount * (draft.level ?? ApproxLevel.biraz).fraction)
                  .roundToDouble());
      return QuantityStepper(
        value: value,
        label: ing.pieceLabel,
        onChanged: (v) {
          draft
            ..quantity = v
            ..level = null;
          onChanged();
        },
      );
    }
    final quantity = draft.quantity;
    if (quantity != null) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Pill(formatBase(ing, quantity),
              color: Palette.basilSoft, fg: Palette.basilDeep, border: null),
          TextButton(
            onPressed: () {
              draft
                ..quantity = null
                ..level = ApproxLevel.biraz;
              onChanged();
            },
            child: const Text('Yaklaşık seç'),
          ),
        ],
      );
    }
    return LevelSelector(
      value: draft.level ?? ApproxLevel.biraz,
      onChanged: (l) {
        draft.level = l;
        onChanged();
      },
    );
  }
}
