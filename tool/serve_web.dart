// Derlenmiş web uygulamasını (build/web) aynı Wi-Fi'deki telefona hızlı sunar:
//  - gzip: main.dart.js ~3,9 MB yerine ~1 MB gider
//  - önbellek: ikonlar, fontlar ve veriler telefonda saklanır; uygulama
//    dosyaları her açılışta yalnızca değişip değişmediği sorulur (ETag/304)
// Flutter'ın geliştirme sunucusu bunların ikisini de yapmıyor.
//   flutter build web --release --dart-define=ANKET_HER_ACILISTA=true
//   dart run tool/serve_web.dart 8091
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8091;
  final root = Directory('build/web').absolute;
  if (!root.existsSync()) {
    stderr.writeln('build/web yok; önce: flutter build web --release');
    exit(1);
  }
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  // gzip'i dart:io kendisi yapar (Accept-Encoding: gzip gelirse).
  server.autoCompress = true;
  stdout.writeln('build/web sunuluyor: http://0.0.0.0:$port');

  await for (final req in server) {
    try {
      await _handle(req, root);
    } catch (e) {
      try {
        req.response.statusCode = 500;
        await req.response.close();
      } catch (_) {}
    }
  }
}

const _types = {
  'html': 'text/html; charset=utf-8',
  'js': 'application/javascript',
  'mjs': 'application/javascript',
  'json': 'application/json',
  'wasm': 'application/wasm',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'svg': 'image/svg+xml',
  'ico': 'image/x-icon',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
  'woff2': 'font/woff2',
  'css': 'text/css',
  'map': 'application/json',
  'bin': 'application/octet-stream',
  'frag': 'application/octet-stream',
};

Future<void> _handle(HttpRequest req, Directory root) async {
  final res = req.response;
  var path = Uri.decodeComponent(req.uri.path);
  if (path.endsWith('/')) path = '${path}index.html';
  final file =
      File('${root.path}${path.replaceAll('/', Platform.pathSeparator)}');
  // Klasör dışına çıkılmasın.
  if (!file.absolute.path.startsWith(root.path) || !file.existsSync()) {
    // Tek sayfalık uygulama: bilinmeyen yol index.html'e düşer.
    if (!path.contains('.')) {
      return _send(
          req, File('${root.path}${Platform.pathSeparator}index.html'));
    }
    res.statusCode = HttpStatus.notFound;
    return res.close();
  }
  return _send(req, file);
}

Future<void> _send(HttpRequest req, File file) async {
  final res = req.response;
  final stat = file.statSync();
  final etag = '"${stat.size.toRadixString(16)}-'
      '${stat.modified.millisecondsSinceEpoch.toRadixString(16)}"';
  final ext = file.path.split('.').last.toLowerCase();
  final rel = file.path.replaceAll('\\', '/');

  // İkon, font, veri ve canvaskit uzun süre saklanır; uygulama kodu ve
  // index.html her seferinde doğrulanır (değiştiyse yenisi gelir).
  final longLived = rel.contains('/assets/') || rel.contains('/canvaskit/');
  res.headers
    ..contentType = ContentType.parse(_types[ext] ?? 'application/octet-stream')
    ..set(HttpHeaders.etagHeader, etag)
    ..set(
        HttpHeaders.cacheControlHeader,
        longLived
            ? 'public, max-age=86400'
            : 'no-cache'); // saklar ama her açılışta sorar

  if (req.headers.value(HttpHeaders.ifNoneMatchHeader) == etag) {
    res.statusCode = HttpStatus.notModified;
    return res.close();
  }
  // Zaten sıkıştırılmış biçimler tekrar sıkıştırılmaz.
  if (const {'png', 'jpg', 'jpeg', 'webp', 'woff2'}.contains(ext)) {
    res.headers.set(HttpHeaders.contentEncodingHeader, 'identity');
  }
  if (req.method == 'HEAD') return res.close();
  await res.addStream(file.openRead());
  await res.close();
}
