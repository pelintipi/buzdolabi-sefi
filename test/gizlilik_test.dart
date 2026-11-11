// Gizlilik ekranı sağlık ve alerji bilgilerinin nerede durduğunu açıkça
// söylemeli; bu bilgiler hiçbir isteğe eklenmemeli.
//   flutter test test/gizlilik_test.dart

import 'dart:io';

import 'package:buzdolabi_sefi/screens/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gizlilik ekranında sağlık ve alerji bölümü var', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Sağlık ve alerji bilgilerin'), findsOneWidget);
    expect(find.textContaining('boyun, kilon, yaşın'), findsOneWidget);
    expect(find.textContaining('yalnızca bu telefonda'), findsOneWidget);
    expect(find.textContaining('özel nitelikli kişisel veri'), findsOneWidget);
  });

  test('dışarıya istek atan kodda vücut ya da alerji bilgisi geçmez', () {
    // Sunucuya/yapay zekaya/ürün aramaya istek atan dosyalar.
    const senders = [
      'lib/services/ai_recipe_client.dart',
      'lib/services/product_lookup.dart',
      'lib/services/video_import.dart',
      'lib/data/remote_catalog.dart',
    ];
    final forbidden = RegExp(
        r'weightKg|heightCm|\.body\b|BodyProfile|allergies|customAllergies|dailyKcal|dailyProtein|dailyFiber');
    for (final path in senders) {
      final code = File(path).readAsStringSync();
      expect(forbidden.hasMatch(code), isFalse, reason: path);
    }
  });
}
