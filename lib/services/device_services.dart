import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart' show BuildContext;

import 'ai_recipe_client.dart';

/// Telefonun donanımına ve iOS'a dokunan her şey burada. Ekranlar bu sınıfları
/// Provider'dan alır; testler sahtelerini verir. Hiçbiri desteklenmeyen
/// platformda (Chrome önizlemesi) çökmez, sessizce "yapılamadı" döner.
class DeviceServices {
  DeviceServices({
    ShareService? share,
    PhotoService? photos,
    SpeechService? speech,
    ReminderService? reminders,
    NativeBridge? native,
    http.Client? httpClient,
    AiRecipeClient? ai,
    this.cameraAvailable = true,
  })  : httpClient = httpClient ?? http.Client(),
        ai = ai ?? AiRecipeClient(),
        share = share ?? ShareService(),
        photos = photos ?? PhotoService(),
        speech = speech ?? SpeechService(),
        reminders = reminders ?? ReminderService(),
        native = native ?? NativeBridge();

  final ShareService share;
  final PhotoService photos;
  final SpeechService speech;
  final ReminderService reminders;
  final NativeBridge native;

  /// Barkod sorgusu gibi ağ istekleri (testlerde sahte istemci).
  final http.Client httpClient;
  final AiRecipeClient ai;

  /// Kamera önizlemesi açılabilir mi (testlerde false).
  final bool cameraAvailable;

  static DeviceServices? _fallback;

  /// Ekranlardan erişim; Provider yoksa (eski testler) gerçek servisler.
  static DeviceServices of(BuildContext context) {
    try {
      return Provider.of<DeviceServices>(context, listen: false);
    } on ProviderNotFoundException {
      return _fallback ??= DeviceServices();
    }
  }
}

// --------------------------------------------------------------- Paylaşım

class ShareService {
  Future<bool> shareText(String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
      return true;
    } catch (e) {
      debugPrint('Paylaşılamadı: $e');
      return false;
    }
  }

  /// TikTok/Instagram hikâyesi için hazırlanan görseli paylaşır.
  /// Metin eklenmez: Instagram hikâyesinde görsel+metin çoğu telefonda bozulur;
  /// marka kartın üzerinde yazılıdır.
  Future<bool> shareImage(Uint8List png, {String? text}) async {
    try {
      if (kIsWeb) {
        await SharePlus.instance.share(ShareParams(
          files: [
            XFile.fromData(png,
                mimeType: 'image/png', name: 'buzdolabi-sefi.png')
          ],
          fileNameOverrides: const ['buzdolabi-sefi.png'],
          text: text,
        ));
        return true;
      }
      final path = '${(await getTemporaryDirectory()).path}/buzdolabi-sefi.png';
      await File(path).writeAsBytes(png, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path, mimeType: 'image/png')],
      ));
      return true;
    } catch (e) {
      debugPrint('Görsel paylaşılamadı: $e');
      return false;
    }
  }
}

// --------------------------------------------------------------- Fotoğraf

class PhotoService {
  late final _picker = ImagePicker();

  /// "Yaptım" fotoğrafı: uygulamanın kendi klasörüne kopyalanır, yolu döner.
  /// Tarayıcıda dosya saklanamadığı için null döner.
  Future<String?> takeDishPhoto({bool camera = true}) async {
    if (kIsWeb) return null;
    try {
      final file = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (file == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final photos = Directory('${dir.path}/yaptiklarim')
        ..createSync(recursive: true);
      final target =
          '${photos.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(file.path).copy(target);
      return target;
    } catch (e) {
      debugPrint('Fotoğraf alınamadı: $e');
      return null;
    }
  }

  /// Fiş taraması için görüntü (saklanmaz).
  Future<Uint8List?> pickImageBytes({bool camera = true}) async {
    try {
      final file = await _picker.pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 2400);
      return file == null ? null : await file.readAsBytes();
    } catch (e) {
      debugPrint('Görüntü alınamadı: $e');
      return null;
    }
  }

  /// Kullanıcının kendi kaydettiği tarif videosu (sesten tarif için).
  Future<String?> pickVideoPath() async {
    if (kIsWeb) return null;
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      return file?.path;
    } catch (e) {
      debugPrint('Video seçilemedi: $e');
      return null;
    }
  }
}

// --------------------------------------------------------------- Ses

/// Sesli pişirme modu: adımları okur, "sonraki", "geri" gibi komutları dinler.
class SpeechService {
  late final _stt = SpeechToText();
  late final _tts = FlutterTts();
  bool _ready = false;
  bool _ttsReady = false;

  Future<bool> _init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize();
    } catch (e) {
      debugPrint('Ses tanıma başlatılamadı: $e');
      _ready = false;
    }
    return _ready;
  }

  /// Dinlemeye başlar; tanınan her sözü [onWords]'e verir.
  /// İzin verilmezse ya da cihaz desteklemezse false döner.
  Future<bool> listen(void Function(String words, bool isFinal) onWords,
      {void Function()? onDone}) async {
    if (!await _init()) return false;
    try {
      _stt.statusListener = (status) {
        if (status == 'done' || status == 'notListening') onDone?.call();
      };
      await _stt.listen(
        onResult: (r) => onWords(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          localeId: 'tr_TR',
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Dinlenemedi: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    try {
      if (!_ttsReady) {
        await _tts.setLanguage('tr-TR');
        await _tts.setSpeechRate(0.48);
        _ttsReady = true;
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Okunamadı: $e');
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

// --------------------------------------------------------------- Bildirim

/// Planlanacak bir hatırlatma.
class Reminder {
  const Reminder(
      {required this.id,
      required this.title,
      required this.body,
      required this.at,
      this.daily = false});

  final int id;
  final String title;
  final String body;

  /// İlk gösterim zamanı (yerel saat).
  final DateTime at;

  /// Her gün aynı saatte tekrar etsin mi?
  final bool daily;
}

class ReminderService {
  late final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get supported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS);

  Future<bool> _init() async {
    if (_ready) return true;
    if (!supported) return false;
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Bildirimler başlatılamadı: $e');
    }
    return _ready;
  }

  /// iOS izin penceresini açar.
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
                alert: true, badge: true, sound: true) ??
            false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('Bildirim izni alınamadı: $e');
      return false;
    }
  }

  /// Önceki hatırlatmaları siler, yenilerini kurar.
  Future<void> replaceAll(List<Reminder> reminders) async {
    if (!await _init()) return;
    try {
      await _plugin.cancelAll();
      const details = NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails('hatirlatma', 'Hatırlatmalar',
            importance: Importance.defaultImportance),
      );
      for (final r in reminders) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: r.daily ? DateTimeComponents.time : null,
        );
      }
    } catch (e) {
      debugPrint('Hatırlatma kurulamadı: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!await _init()) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}

// --------------------------------------------------------------- iOS köprüsü

/// Kendi yazdığımız iOS kodu (ios/Runner/AppDelegate.swift → NativeBridgePlugin):
/// fişten yazı okuma (Apple Vision), videodaki konuşmayı yazıya çevirme
/// (Apple Speech, cihaz üstünde) ve ana ekran aracına veri yazma (WidgetKit).
class NativeBridge {
  static const _channel = MethodChannel('buzdolabi_sefi/native');

  Future<String?> recognizeText(Uint8List image) =>
      _call<String>('recognizeText', {'image': image});

  /// Önce Türkçe dinler; anlamlı bir metin çıkmazsa İngilizce dener
  /// (yabancı tarif videoları için).
  Future<String?> transcribeVideo(String path) async {
    String? best;
    for (final locale in const ['tr-TR', 'en-US']) {
      final text = await _call<String>(
          'transcribeVideo', {'path': path, 'locale': locale});
      if (text != null && text.trim().length > (best?.trim().length ?? 0)) {
        best = text;
      }
      if (best != null && best.trim().split(RegExp(r'\s+')).length >= 15) {
        break;
      }
    }
    return best;
  }

  Future<void> updateWidget(Map<String, Object?> data) async {
    await _call<bool>('updateWidget', data);
  }

  Future<T?> _call<T>(String method, Map<String, Object?> args) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('$method başarısız: ${e.message}');
      return null;
    }
  }
}
