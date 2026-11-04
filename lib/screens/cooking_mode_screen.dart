import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/recipe.dart';
import '../services/device_services.dart';
import '../services/voice_commands.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import 'cooked_screen.dart';

class _RunningTimer {
  _RunningTimer(this.label, this.endsAt);

  final String label;

  /// Bitiş anı tutulur; uygulama arka plana gidip dönse de süre doğru kalır.
  final DateTime endsAt;
  bool notified = false;
}

/// Büyük yazılı, adım adım pişirme modu. Ekran kapanmaz, birden fazla
/// zamanlayıcı aynı anda çalışabilir, kaldığı adım kaydedilir.
class CookingModeScreen extends StatefulWidget {
  const CookingModeScreen({
    super.key,
    required this.recipeId,
    required this.servings,
    required this.initialStep,
  });

  final String recipeId;
  final int servings;
  final int initialStep;

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  late final Recipe _recipe;
  late final PageController _pages;
  late int _step;
  final _timers = <_RunningTimer>[];
  Timer? _ticker;

  // Sesli mod: adımı okur, "sonraki", "geri", "tekrar", "zamanlayıcı" dinler.
  bool _voice = false;
  String _heard = '';
  SpeechService? _speech;

  @override
  void initState() {
    super.initState();
    _recipe = context.read<AppState>().recipeById(widget.recipeId);
    _step = math.max(0, math.min(widget.initialStep, _recipe.steps.length - 1));
    _pages = PageController(initialPage: _step);
    // Eklenti olmayan ortamlarda (testler, bazı tarayıcılar) sessizce geçilir.
    WakelockPlus.enable().catchError((Object _) {});
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _speech?.stopListening();
    _speech?.stopSpeaking();
    WakelockPlus.disable().catchError((Object _) {});
    _pages.dispose();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _timers.isEmpty) return;
    final now = DateTime.now();
    for (final t in _timers) {
      if (!t.notified && !now.isBefore(t.endsAt)) {
        t.notified = true;
        _alarm(t);
      }
    }
    setState(() {});
  }

  void _alarm(_RunningTimer t) {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const FoodIcon('⏲', size: 64),
        title: Text('${t.label} hazır!'),
        actions: [
          FilledButton(
            onPressed: () {
              setState(() => _timers.remove(t));
              Navigator.of(ctx).pop();
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _startTimer(RecipeStep step) {
    setState(() {
      _timers.add(_RunningTimer(
        step.timerLabel ?? 'Adım ${_step + 1}',
        DateTime.now().add(Duration(minutes: step.timerMinutes!)),
      ));
    });
  }

  void _onPageChanged(int i) {
    setState(() => _step = i);
    if (_voice) _speakStep();
    if (i < _recipe.steps.length) {
      context.read<AppState>().setActiveCooking(ActiveCooking(
          recipeId: _recipe.id, servings: widget.servings, step: i));
    }
  }

  Future<void> _toggleVoice() async {
    if (_voice) {
      setState(() => _voice = false);
      await _speech?.stopListening();
      await _speech?.stopSpeaking();
      return;
    }
    _speech ??= DeviceServices.of(context).speech;
    setState(() {
      _voice = true;
      _heard = '';
    });
    _speakStep();
    final ok = await _listen();
    if (!ok && mounted) {
      setState(() => _voice = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mikrofona ya da ses tanımaya izin verilmedi.')));
    }
  }

  Future<bool> _listen() => _speech!.listen(
        (words, isFinal) {
          if (!mounted) return;
          setState(() => _heard = words);
          final cmd = parseVoiceCommand(words);
          if (isFinal && cmd != null) _onCommand(cmd);
        },
        // iOS bir süre sessizlikten sonra dinlemeyi bırakır; sesli mod açıksa
        // yeniden başlat.
        onDone: () {
          if (mounted && _voice) {
            Future<void>.delayed(const Duration(milliseconds: 400), () {
              if (mounted && _voice) _listen();
            });
          }
        },
      );

  void _speakStep() {
    final steps = _recipe.steps;
    _speech?.speak(_step < steps.length
        ? 'Adım ${_step + 1}. ${steps[_step].text}'
        : 'Bitti, afiyet olsun!');
  }

  void _onCommand(VoiceCommand cmd) {
    final steps = _recipe.steps;
    switch (cmd) {
      case VoiceCommand.next:
        if (_step < steps.length) _go(1);
      case VoiceCommand.previous:
        if (_step > 0) _go(-1);
      case VoiceCommand.repeat:
        _speakStep();
      case VoiceCommand.timer:
        final s = _step < steps.length ? steps[_step] : null;
        if (s?.timerMinutes != null) {
          _startTimer(s!);
          _speech?.speak('${s.timerMinutes} dakikalık zamanlayıcı kuruldu.');
        } else {
          _speech?.speak('Bu adımda zamanlayıcı yok.');
        }
      case VoiceCommand.finish:
        _finish();
      case VoiceCommand.stop:
        _toggleVoice();
    }
  }

  void _go(int delta) => _pages.animateToPage(_step + delta,
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  void _finish() {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) =>
          CookedScreen(recipeId: _recipe.id, servings: widget.servings),
    ));
  }

  Future<void> _confirmExit() async {
    final navigator = Navigator.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pişirmeyi bırak?'),
        content: const Text(
            'Kaldığın adım kaydedildi, ana sayfadan devam edebilirsin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Devam et')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Çık')),
        ],
      ),
    );
    if (leave == true) navigator.pop();
  }

  void _showIngredients() {
    final repo = context.read<AppState>().repo;
    final scale = widget.servings / _recipe.servings;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            SectionTitle('Malzemeler (${widget.servings} kişilik)', icon: '🧺'),
            for (final item in _recipe.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    FoodIcon(repo.byId(item.ingredientId).emoji, size: 32),
                    const SizedBox(width: 10),
                    Text(
                        '${formatMeasureAmount(item.amount * scale, item.measure)} '
                        '${repo.byId(item.ingredientId).name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = _recipe.steps;
    final onLastPage = _step >= steps.length;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Çık',
          onPressed: _confirmExit,
        ),
        title: Row(
          children: [
            FoodIcon(_recipe.emoji, size: 32),
            const SizedBox(width: 8),
            Flexible(
                child: Text(_recipe.title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_voice ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _voice ? Palette.tomato : null),
            tooltip: _voice ? 'Sesli modu kapat' : 'Sesli mod',
            onPressed: _toggleVoice,
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: 'Malzemeler',
            onPressed: _showIngredients,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_voice)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: Palette.tomatoSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const FoodIcon('🎙', size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _heard.isEmpty
                          ? 'Dinliyorum: "sonraki", "geri", "tekrar oku", "zamanlayıcı"'
                          : 'Duydum: "$_heard"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: Palette.tomatoDeep),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Expanded(
                    child: Container(
                      height: 8,
                      margin:
                          EdgeInsets.only(right: i == steps.length - 1 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: i <= _step ? Palette.basil : Palette.basilSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_timers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _timers)
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                      decoration: BoxDecoration(
                        color: t.notified
                            ? Palette.tomatoSoft
                            : Palette.butterSoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: t.notified ? Palette.tomato : Palette.butter,
                            width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FoodIcon('⏱', size: 24),
                          const SizedBox(width: 6),
                          Text(
                              '${t.label} ${formatTimer(t.endsAt.difference(now))}',
                              style: const TextStyle(
                                  fontFamily: Fonts.display,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ])),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Zamanlayıcıyı kapat',
                            onPressed: () => setState(() => _timers.remove(t)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: steps.length + 1,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, i) => i < steps.length
                  ? _StepPage(
                      index: i,
                      total: steps.length,
                      step: steps[i],
                      onStartTimer: () => _startTimer(steps[i]),
                    )
                  : _DonePage(onFinish: _finish),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  if (_step > 0)
                    ChunkyButton(
                      label: 'Geri',
                      tone: ChunkyTone.soft,
                      expand: false,
                      onPressed: () => _go(-1),
                    ),
                  if (_step > 0 && !onLastPage) const SizedBox(width: 12),
                  if (!onLastPage)
                    Expanded(
                      child: ChunkyButton(
                        label: _step == steps.length - 1 ? 'Bitir' : 'Sonraki',
                        onPressed: () => _go(1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.index,
    required this.total,
    required this.step,
    required this.onStartTimer,
  });

  final int index;
  final int total;
  final RecipeStep step;
  final VoidCallback onStartTimer;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Palette.basilSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('Adım ${index + 1}/$total',
                style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Palette.basilDeep)),
          ),
          const SizedBox(height: 20),
          Text(step.text,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 27, height: 1.35)),
          if (step.timerMinutes != null) ...[
            const SizedBox(height: 32),
            ChunkyButton(
              label:
                  '${step.timerLabel ?? 'Zamanlayıcı'} · ${step.timerMinutes} dk başlat',
              icon: '⏲',
              tone: ChunkyTone.butter,
              onPressed: onStartTimer,
            ),
          ],
        ],
      ),
    );
  }
}

class _DonePage extends StatelessWidget {
  const _DonePage({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FoodIcon('🎉', size: 140),
          const SizedBox(height: 12),
          Text('Afiyet olsun!',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text('Bitirdiysen dolabını güncelleyelim.',
              style: TextStyle(
                  color: Palette.inkSoft, fontWeight: FontWeight.w700)),
          const SizedBox(height: 28),
          ChunkyButton(
            label: 'Pişirdim!',
            icon: '✅',
            tone: ChunkyTone.accent,
            onPressed: onFinish,
          ),
        ],
      ),
    );
  }
}
