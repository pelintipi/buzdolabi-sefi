import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'deep_links.dart';
import 'screens/home_screen.dart';
import 'screens/import_recipe_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pantry_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/shopping_screen.dart';
import 'screens/social_screen.dart';
import 'services/video_import.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/palette.dart';
import 'widgets/nav_tour.dart';
import 'widgets/ui.dart' show IconPrecache;

class BuzdolabiSefiApp extends StatelessWidget {
  const BuzdolabiSefiApp(
      {super.key, this.shareInbox = const ShareInbox(), this.videoClient});

  /// TikTok paylaşımlarını teslim alan kanal (testlerde sahte olanı verilir).
  final ShareInbox shareInbox;
  final VideoInfoClient? videoClient;

  @override
  Widget build(BuildContext context) {
    final themeMode =
        context.select<AppState, ThemeMode>((s) => s.profile.uiTheme.mode);
    return MaterialApp(
      title: 'Buzdolabı Şefi',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final changed = Palette.brightness != brightness;
        Palette.apply(brightness);
        if (changed) {
          // Palette renkleri tema dinlemeyen widget'larda da kullanılıyor;
          // açık sayfalar eski renkte kalmasın diye tamamı yeniden çizilir
          // (ekran yığını ve yazılanlar korunur).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            void mark(Element e) {
              e.markNeedsBuild();
              e.visitChildren(mark);
            }

            WidgetsBinding.instance.rootElement?.visitChildren(mark);
          });
        }
        return IconPrecache(child: child ?? const SizedBox.shrink());
      },
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Ana ekran aracından gelen bağlantılar (lib/deep_links.dart).
      onGenerateRoute: DeepLinks.route,
      onUnknownRoute: DeepLinks.unknown,
      // İlk açılışta kısa anket; bitince (ya da geçilince) ana ekran.
      home: Selector<AppState, bool>(
        selector: (_, s) => s.profile.onboarded,
        builder: (_, onboarded, __) => onboarded
            ? HomeShell(shareInbox: shareInbox, videoClient: videoClient)
            : const OnboardingScreen(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell(
      {super.key, this.shareInbox = const ShareInbox(), this.videoClient});

  final ShareInbox shareInbox;
  final VideoInfoClient? videoClient;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final AppLifecycleListener _lifecycle;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Paylaş menüsünden gelinince uygulama ya yeni açılır ya da öne gelir.
    _lifecycle = AppLifecycleListener(onResume: _checkShares);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeNavTour();
      if (mounted) await _checkShares();
    });
  }

  /// İlk girişte alt menüyü bir kez anlatır; sekmeyi adım adım açar.
  Future<void> _maybeNavTour() async {
    final state = context.read<AppState>();
    if (state.profile.seenNavTour) return;
    await showNavTour(context, onTab: (i) {
      if (mounted) setState(() => _index = i);
    });
    if (!mounted) return;
    state.updateProfile(state.profile.copyWith(seenNavTour: true));
    setState(() => _index = 0);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Paylaşım eklentisinin bıraktığı her video için tarif ekranını açar.
  Future<void> _checkShares() async {
    if (_checking) return;
    _checking = true;
    try {
      final pending = await widget.shareInbox.takePending();
      for (final payload in pending) {
        if (!mounted) return;
        setState(() => _index = 0);
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              ImportRecipeScreen(payload: payload, client: widget.videoClient),
        ));
      }
    } finally {
      _checking = false;
    }
  }

  late final _pages = [
    const HomeScreen(),
    const PantryScreen(),
    SocialScreen(videoClient: widget.videoClient),
    const ShoppingScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _NavBar(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  // Çizgi ikon (seçili değil) ve dolu ikon (seçili), tasarımdaki gibi.
  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Ana sayfa'),
    (Icons.shopping_basket_outlined, Icons.shopping_basket_rounded, 'Dolabım'),
    (Icons.play_circle_outline_rounded, Icons.play_circle_rounded, 'Sosyal'),
    (Icons.list_alt_outlined, Icons.list_alt_rounded, 'Liste'),
    (Icons.account_circle_outlined, Icons.account_circle_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final shoppingCount = context.watch<AppState>().shoppingList.length;
    return Container(
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x143A2A1E), blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onSelect(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: i == index ? Palette.basilSoft : null,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Badge(
                              isLabelVisible: i == 3 && shoppingCount > 0,
                              label: Text('$shoppingCount'),
                              backgroundColor: Palette.tomato,
                              child: Icon(
                                i == index ? _items[i].$2 : _items[i].$1,
                                size: 28,
                                color: i == index
                                    ? Palette.accent
                                    : Palette.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _items[i].$3,
                              style: TextStyle(
                                fontFamily: Fonts.display,
                                fontWeight: i == index
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 13,
                                color: i == index
                                    ? Palette.accentDeep
                                    : Palette.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
