// Derlenmiş web uygulamasını (build/web) aynı Wi-Fi'deki telefona hızlı sunar:
//  - gzip: main.dart.js ~3,9 MB yerine ~1 MB gider
//  - önbellek: ikonlar, fontlar ve veriler telefonda saklanır; uygulama
//    dosyaları her açılışta yalnızca değişip değişmediği sorulur (ETag/304)
// Flutter'ın geliştirme sunucusu bunların ikisini de yapmıyor.
//   flutter build web --release --dart-define=ANKET_HER_ACILISTA=true
//   dart run tool/serve_web.dart 8091
// iPhone'da kamera/paylaş için https gerekir (Safari http'de kapatır):
//   dart run tool/serve_web.dart 8443 --https
// Sertifika yoksa tool/certs altında kendinden imzalı biri üretilir.
// /proxy/... istekleri yerel video proxy'sine (8787) iletilir; böylece
// https sayfası http proxy'ye takılmaz.
import 'dart:io';

Future<void> main(List<String> args) async {
  final https = args.contains('--https');
  final nums = args.where((a) => int.tryParse(a) != null);
  final port = nums.isNotEmpty ? int.parse(nums.first) : (https ? 8443 : 8091);
  final root = Directory('build/web').absolute;
  if (!root.existsSync()) {
    stderr.writeln('build/web yok; önce: flutter build web --release');
    exit(1);
  }
  final server = https
      ? await HttpServer.bindSecure(
          InternetAddress.anyIPv4, port, await _certContext())
      : await HttpServer.bind(InternetAddress.anyIPv4, port);
  // gzip'i dart:io kendisi yapar (Accept-Encoding: gzip gelirse).
  server.autoCompress = true;
  stdout.writeln('build/web sunuluyor: ${https ? 'https' : 'http'}://0.0.0.0:$port');

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
  if (req.uri.path.startsWith('/proxy/')) return _forward(req);
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

final _proxyClient = HttpClient();

/// /proxy/oembed?url=… → http://127.0.0.1:8787/oembed?url=…
Future<void> _forward(HttpRequest req) async {
  final res = req.response;
  res.headers.set('Access-Control-Allow-Origin', '*');
  try {
    final target = req.uri.replace(
        scheme: 'http',
        host: '127.0.0.1',
        port: 8787,
        path: req.uri.path.substring('/proxy'.length));
    final up = await (await _proxyClient.getUrl(target)).close();
    res.statusCode = up.statusCode;
    res.headers.contentType = ContentType.json;
    await res.addStream(up);
  } catch (e) {
    res.statusCode = HttpStatus.badGateway;
    res.write('{"error":"video proxy kapalı: dart run tool/oembed_proxy.dart"}');
  }
  await res.close();
}

/// tool/certs/cert.pem + key.pem; yoksa openssl ile bu bilgisayarın yerel
/// IP'leri için üretilir. Kendinden imzalıdır: telefonda bir kez
/// "Ayrıntıları göster → Web sitesini ziyaret et" demek gerekir.
Future<SecurityContext> _certContext() async {
  final dir = Directory('tool/certs')..createSync(recursive: true);
  final cert = File('${dir.path}/cert.pem');
  final key = File('${dir.path}/key.pem');
  if (!cert.existsSync() || !key.existsSync()) {
    final ips = <String>['127.0.0.1'];
    for (final ni in await NetworkInterface.list(
        type: InternetAddressType.IPv4)) {
      ips.addAll(ni.addresses.map((a) => a.address));
    }
    final san = [
      'DNS:localhost',
      for (final ip in ips.toSet()) 'IP:$ip',
    ].join(',');
    final r = await Process.run('openssl', [
      'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '365',
      '-keyout', key.path, '-out', cert.path,
      '-subj', '/CN=Buzdolabi Sefi yerel',
      '-addext', 'subjectAltName=$san',
    ]);
    if (r.exitCode != 0) {
      stderr.writeln('Sertifika üretilemedi (openssl): ${r.stderr}');
      exit(1);
    }
  }
  return SecurityContext()
    ..useCertificateChain(cert.path)
    ..usePrivateKey(key.path);
}
