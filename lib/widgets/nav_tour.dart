import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'ui.dart';

/// Alt menü adımları. [onTab] tur sırasında ilgili sekmeyi açar.
const _steps = <({int tab, String emoji, String title, String body})>[
  (
    tab: 0,
    emoji: '👋',
    title: 'Mutfağa hoş geldin',
    body: 'Alt menüden beş yere gidersin. Kısa tur: her sekme ne işe yarar.',
  ),
  (
    tab: 0,
    emoji: '🏠',
    title: 'Ana sayfa',
    body:
        'Bugün ne pişireceğini bulur, haftalık hedefini ve hızlı eklemeleri görürsün.',
  ),
  (
    tab: 1,
    emoji: '🧺',
    title: 'Dolabım',
    body: 'Elindeki malzemeleri ekle. Tarifler dolabına göre sıralanır.',
  ),
  (
    tab: 2,
    emoji: '▶',
    title: 'Sosyal',
    body: 'TikTok veya Instagram’daki tarif videosunu buradan kaydedersin.',
  ),
  (
    tab: 3,
    emoji: '📝',
    title: 'Liste',
    body:
        'Eksik malzemeler alışveriş listene düşer; “Neler alabilirim?” önerir.',
  ),
  (
    tab: 4,
    emoji: '👤',
    title: 'Profil',
    body: 'Diyet, alerji, görünüm (açık/koyu) ve hatırlatmalar burada.',
  ),
];

/// İlk girişte bir kez. Bitişte veya Geç’te `true` döner (tur bitti sayılır).
Future<bool> showNavTour(
  BuildContext context, {
  required ValueChanged<int> onTab,
}) async {
  final done = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Nav turu',
    barrierColor: const Color(0x99000000),
    pageBuilder: (ctx, anim, _) => _NavTourSheet(onTab: onTab),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: child,
    ),
  );
  return done ?? true;
}

class _NavTourSheet extends StatefulWidget {
  const _NavTourSheet({required this.onTab});

  final ValueChanged<int> onTab;

  @override
  State<_NavTourSheet> createState() => _NavTourSheetState();
}

class _NavTourSheetState extends State<_NavTourSheet> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTab(_steps[_i].tab);
    });
  }

  void _go(int i) {
    setState(() => _i = i);
    widget.onTab(_steps[i].tab);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _steps[_i];
    final last = _i == _steps.length - 1;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SoftCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SymBubble(step.emoji, size: 56, color: Palette.butterSoft),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_i + 1}/${_steps.length}',
                              style: theme.textTheme.bodySmall),
                          Text(step.title, style: theme.textTheme.titleLarge),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Geç'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(step.body, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: i == _steps.length - 1 ? 0 : 4),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= _i ? Palette.basil : Palette.line,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ChunkyButton(
                  label: last ? 'Anladım, başla' : 'Devam',
                  onPressed: () {
                    if (last) {
                      Navigator.of(context).pop(true);
                      return;
                    }
                    _go(_i + 1);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
