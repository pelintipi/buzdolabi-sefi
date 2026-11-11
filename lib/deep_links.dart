import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/ingredient_input_screen.dart';
import 'screens/pantry_screen.dart';
import 'screens/results_screen.dart';
import 'state/app_state.dart';

/// Ana ekran aracından (ios/HomeWidget) gelen bağlantılar:
///   buzdolabisefi://app/ne-pisirsem → "Ne pişirsem?" sonuçları
///   buzdolabisefi://app/dolap       → Dolabım (bozulmak üzere olanlar üstte)
/// iOS bağlantıyı Flutter'a ekran adı olarak verir (Info.plist →
/// FlutterDeepLinkingEnabled); burada ekrana çevrilir.
abstract final class DeepLinks {
  static const whatToCook = '/ne-pisirsem';
  static const pantry = '/dolap';

  static Route<void>? route(RouteSettings settings) {
    final name = settings.name ?? '';
    final path = (Uri.tryParse(name)?.path ?? name).toLowerCase();
    final Widget page;
    switch (path) {
      case whatToCook:
        page = const _OnlyWhenOnboarded(child: _WhatToCook());
      case pantry:
        page = const _OnlyWhenOnboarded(child: PantryScreen());
      default:
        return null;
    }
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  /// Bilinmeyen bağlantı hiçbir şey açmaz (kendini hemen kapatır).
  static Route<void> unknown(RouteSettings settings) => PageRouteBuilder<void>(
        settings: settings,
        opaque: false,
        pageBuilder: (context, _, __) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const SizedBox.shrink();
        },
      );
}

/// Dolap boşsa önce malzeme girişi, doluysa sonuçlar (ana sayfadaki
/// "Ne pişirsem?" ile aynı).
class _WhatToCook extends StatelessWidget {
  const _WhatToCook();

  @override
  Widget build(BuildContext context) {
    final empty = context.read<AppState>().pantry.isEmpty;
    return empty
        ? const IngredientInputScreen(openResultsAfter: true)
        : const ResultsScreen();
  }
}

/// Açılış anketi bitmeden araçtan gelinirse sayfa açılmaz; anket görünür.
class _OnlyWhenOnboarded extends StatelessWidget {
  const _OnlyWhenOnboarded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onboarded =
        context.select<AppState, bool>((s) => s.profile.onboarded);
    if (onboarded) return child;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    });
    return const SizedBox.shrink();
  }
}
