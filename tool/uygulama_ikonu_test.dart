// Uygulama ikonunu çizer (1024 × 1024, saydamlık yok; iOS köşeleri kendisi
// yuvarlar):  flutter test tool/uygulama_ikonu_test.dart
// Çıktı: assets/app_icon/icon_1024.png. Boyutlara bölmek için:
//   powershell -ExecutionPolicy Bypass -File tool\ikonlari_uret.ps1
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _forest = Color(0xFF1F3B2D);
const _cream = Color(0xFFF8F6F2);
const _tomato = Color(0xFFC75A35);
const _leaf = Color(0xFF6E9B6A);

class _IconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final u = s.width / 1024;
    canvas.drawRect(Offset.zero & s, Paint()..color = _forest);

    // Buzdolabı: krem gövde, dondurucu çizgisi, iki kulp.
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(352 * u, 214 * u, 320 * u, 560 * u), Radius.circular(64 * u));
    canvas.drawRRect(body, Paint()..color = _cream);
    canvas.drawRect(Rect.fromLTWH(352 * u, 392 * u, 320 * u, 14 * u),
        Paint()..color = _forest);
    final handle = Paint()..color = _forest;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(404 * u, 286 * u, 18 * u, 70 * u),
            Radius.circular(9 * u)),
        handle);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(404 * u, 448 * u, 18 * u, 120 * u),
            Radius.circular(9 * u)),
        handle);

    // Önde domates: dolabın köşesinden taşar, yaprak ve sap.
    final center = Offset(648 * u, 700 * u);
    canvas.drawCircle(center, 150 * u, Paint()..color = _forest);
    canvas.drawCircle(center, 128 * u, Paint()..color = _tomato);
    canvas.drawCircle(center.translate(-46 * u, -44 * u), 26 * u,
        Paint()..color = const Color(0x33FFFFFF));
    final leaf = Path()
      ..moveTo(648 * u, 578 * u)
      ..quadraticBezierTo(700 * u, 540 * u, 748 * u, 572 * u)
      ..quadraticBezierTo(700 * u, 604 * u, 648 * u, 578 * u)
      ..close();
    canvas.drawPath(leaf, Paint()..color = _leaf);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(640 * u, 548 * u, 16 * u, 44 * u),
            Radius.circular(8 * u)),
        Paint()..color = _leaf);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  test('uygulama ikonu', () async {
    final recorder = ui.PictureRecorder();
    _IconPainter().paint(Canvas(recorder), const Size(1024, 1024));
    final image = await recorder.endRecording().toImage(1024, 1024);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('assets/app_icon/icon_1024.png')
      ..createSync(recursive: true);
    out.writeAsBytesSync(png!.buffer.asUint8List());
    expect(out.lengthSync(), greaterThan(1000));
  });
}
