import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ekran görüntüsü alınacak alanı saran RepaintBoundary'nin anahtarı.
final screenshotKey = GlobalKey();

String _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  // .../flutter/bin/cache/artifacts/engine/<platform>/flutter_tester(.exe)
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    dir = dir.parent;
  }
  return dir.path;
}

Future<void> _loadFamily(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final p in paths) {
    final f = File(p);
    if (!f.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    any = true;
  }
  if (any) await loader.load();
}

/// Testlerde varsayılan font kutucuklar çizer; okunabilir ekran görüntüsü için
/// gerçek fontlar yüklenir. Emoji fontu bulunamazsa emojiler boş kalır.
Future<void> loadRealFonts() async {
  final fonts = '${_flutterRoot()}/bin/cache/artifacts/material_fonts';
  // Uygulamanın kendi fontları (pubspec'teki aileler testlerde otomatik yüklenmez).
  await _loadFamily(
      'InstrumentSerif', ['assets/fonts/InstrumentSerif-Regular.ttf']);
  await _loadFamily('PlusJakarta', [
    for (final w in ['Medium', 'SemiBold', 'Bold', 'ExtraBold'])
      'assets/fonts/PlusJakartaSans-$w.ttf',
  ]);
  await _loadFamily('Roboto', [
    '$fonts/roboto-regular.ttf',
    '$fonts/roboto-medium.ttf',
    '$fonts/roboto-bold.ttf',
  ]);
  await _loadFamily('MaterialIcons', ['$fonts/materialicons-regular.otf']);
  await _loadFamily('Segoe UI Emoji', [r'C:\Windows\Fonts\seguiemj.ttf']);
}

class ReportStep {
  ReportStep(this.title, this.action, this.result, this.image, this.ok);

  final String title;
  final String action;
  final String result;
  final String image;
  final bool ok;
}

/// Prototip için: bir adımda dokunulan alan ve götürdüğü adım.
class Hotspot {
  Hotspot(this.from, this.rect, this.label);

  final int from;
  final Rect rect;
  final String label;
  int? to;
}

/// Her adımda ekran görüntüsü alır ve sonunda resimli bir HTML raporu yazar.
class ScreenshotReport {
  ScreenshotReport(String path, this.title) : dir = Directory(path) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  }

  final Directory dir;
  final String title;
  final steps = <ReportStep>[];
  final hotspots = <Hotspot>[];

  /// Son ekran görüntüsündeki bu alanı, bir sonraki ekran görüntüsüne giden
  /// prototip bağlantısı olarak kaydeder (dokunmaz).
  void mark(WidgetTester tester, Finder finder, String label) {
    if (steps.isEmpty) return;
    hotspots
        .add(Hotspot(steps.length - 1, tester.getRect(finder.first), label));
  }

  /// Alanı kaydeder ve dokunur.
  Future<void> tap(WidgetTester tester, Finder finder, String label) async {
    mark(tester, finder, label);
    await tester.tap(finder.first);
  }

  Future<void> capture(
    WidgetTester tester, {
    required String title,
    required String action,
    required String result,
    bool ok = true,
    bool settle = true,
  }) async {
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    // Resimler (3D ikonlar) testte kendiliğinden çözülmez; ekranda olanları yükle.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element);
      }
    });
    await tester.pump();
    final name = '${(steps.length + 1).toString().padLeft(2, '0')}.png';
    final boundary = screenshotKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/$name').writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
    for (final h in hotspots) {
      if (h.to == null && h.from == steps.length - 1) h.to = steps.length;
    }
    steps.add(ReportStep(title, action, result, name, ok));
  }

  /// Prototip verisi: her adımın görüntüsü ve dokunulabilir alanları
  /// (393 × 852 noktalık ekrana göre).
  void writePrototypeJson(Size screen) {
    final data = {
      'width': screen.width,
      'height': screen.height,
      'steps': [
        for (var i = 0; i < steps.length; i++)
          {
            'image': steps[i].image,
            'title': steps[i].title,
            'action': steps[i].action,
            'result': steps[i].result,
            'ok': steps[i].ok,
            'hotspots': [
              for (final h in hotspots)
                if (h.from == i && h.to != null)
                  {
                    'x': h.rect.left.roundToDouble(),
                    'y': h.rect.top.roundToDouble(),
                    'w': h.rect.width.roundToDouble(),
                    'h': h.rect.height.roundToDouble(),
                    'label': h.label,
                    'to': h.to,
                  },
            ],
          },
      ],
    };
    File('${dir.path}/prototip.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(data));
  }

  void writeHtml() {
    const esc = HtmlEscape();
    final passed = steps.where((s) => s.ok).length;
    final rows = StringBuffer();
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      rows.writeln('''
<section class="step ${s.ok ? 'ok' : 'bad'}">
  <img src="${s.image}" alt="${esc.convert(s.title)}">
  <div>
    <div class="num">Adım ${i + 1} · ${s.ok ? '✅ Beklendiği gibi' : '⚠️ Sorun'}</div>
    <h2>${esc.convert(s.title)}</h2>
    <p><b>Ne yaptım:</b> ${esc.convert(s.action)}</p>
    <p><b>Ne oldu:</b> ${esc.convert(s.result)}</p>
  </div>
</section>''');
    }
    File('${dir.path}/rapor.html').writeAsStringSync('''
<!doctype html><html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc.convert(title)}</title>
<style>
body{font-family:system-ui,sans-serif;margin:0;padding:24px;background:#faf7f5;color:#222}
h1{margin:0 0 4px} .sum{margin:0 0 24px;color:#555}
.step{display:flex;gap:24px;align-items:flex-start;background:#fff;border-radius:16px;
padding:16px;margin-bottom:16px;border-left:6px solid #2e7d32}
.step.bad{border-left-color:#c62828}
.step img{width:280px;border-radius:12px;border:1px solid #ddd}
.num{font-size:13px;color:#777} h2{margin:4px 0 8px;font-size:18px}
@media(max-width:640px){.step{flex-direction:column}.step img{width:100%}}
</style></head><body>
<h1>${esc.convert(title)}</h1>
<p class="sum">${steps.length} adım · $passed beklendiği gibi · ${steps.length - passed} sorun</p>
$rows
</body></html>''');
  }
}
