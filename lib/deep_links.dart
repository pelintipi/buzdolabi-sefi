import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/ingredient_input_screen.dart';
import 'screens/pantry_screen.dart';
import 'screens/results_screen.dart';
import 'state/app_state.dart';

/// Ana ekran aracı ve Siri'den gelen bağlantılar:
///   buzdolabisefi://app/ne-pisirsem → "Ne pişirsem?" sonuçları
///   buzdolabisefi://app/dolap       → Dolabım
///   buzdolabisefi://app/ekle?metin=6%20yumurta → dolaba ekle, Dolabım'ı aç
/// iOS bağlantıyı Flutter'a ekran adı olarak verir (Info.plist →
/// FlutterDeepLinkingEnabled); burada ekrana çevrilir.
abstract final class DeepLinks {
  static const whatToCook = '/ne-pisirsem';
  static const pantry = '/dolap';
  static const addToPantry = '/ekle';

  static Route<void>? route(RouteSettings settings) {
    final name = settings.name ?? '';
    final uri = Uri.tryParse(name);
    final path = (uri?.path ?? name).toLowerCase();
    final Widget page;
    switch (path) {
      case whatToCook:
        page = const _OnlyWhenOnboarded(child: _WhatToCook());
      case pantry:
        page = const _OnlyWhenOnboarded(child: PantryScreen());
      case addToPantry:
        page = _OnlyWhenOnboarded(
            child: _AddFromSiri(text: uri?.queryParameters['metin'] ?? ''));
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

/// Siri / Kısayollar: metni dolaba ekler, sonucu gösterir, Dolabım'a geçer.
class _AddFromSiri extends StatefulWidget {
  const _AddFromSiri({required this.text});

  final String text;

  @override
  State<_AddFromSiri> createState() => _AddFromSiriState();
}

class _AddFromSiriState extends State<_AddFromSiri> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  void _apply() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();
    final text = widget.text.trim();
    if (text.isEmpty) {
      nav.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const PantryScreen()));
      return;
    }
    final unknown = state.addPantryFromText(text);
    nav.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PantryScreen()));
    final message = unknown.isEmpty
        ? 'Dolaba eklendi: $text'
        : (unknown.length == 1 && unknown.first == text
            ? '"$text" listede yok; malzemeyi elle ekleyebilirsin.'
            : 'Bir kısmı eklendi. Tanınmayan: ${unknown.join(", ")}');
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
