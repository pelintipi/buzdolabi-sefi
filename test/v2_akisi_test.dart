// Yeni özellikleri kullanıcı gibi dener ve her adımın ekran görüntüsünü alır:
// haftalık plan, dünden kalan, mevsim, fiş ve barkod, paylaşım kartı, sesli
// pişirme, yenen porsiyon, günlük takip, hatırlatmalar, Şef+ ve gizlilik.
//   flutter test test/v2_akisi_test.dart
// Rapor: degisiklik_raporlari/2026-11-04_v2-ozellikler/rapor.html

import 'dart:convert';
import 'dart:typed_data';

import 'package:buzdolabi_sefi/app.dart';
import 'package:buzdolabi_sefi/screens/cooking_mode_screen.dart';
import 'package:buzdolabi_sefi/screens/recipe_detail_screen.dart';
import 'package:buzdolabi_sefi/services/device_services.dart';
import 'package:buzdolabi_sefi/services/ingredient_repository.dart';
import 'package:buzdolabi_sefi/services/storage_service.dart';
import 'package:buzdolabi_sefi/state/app_state.dart';
import 'package:buzdolabi_sefi/state/digest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screenshot_report.dart';
import 'support/test_catalog.dart';

const _screen = Size(393, 852);

const _receipt = '''
MIGROS TICARET A.S.
TARIH: 04.11.2026  SAAT: 18:42
SUT TAM YAGLI 1 LT            *32,50
YUMURTA 10LU                  *89,90
PIRASA KG
1,150 X 24,90                 *28,64
PEYNIR BEYAZ 500 GR           *149,00
KIYMA DANA 500 GR            *289,00
BULASIK DETERJANI             *79,90
TOPLAM                       *668,94
''';

class _FakeSpeech extends SpeechService {
  void Function(String, bool)? onWords;
  final spoken = <String>[];

  @override
  Future<bool> listen(void Function(String, bool) onWords,
      {void Function()? onDone}) async {
    this.onWords = onWords;
    return true;
  }

  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> stopSpeaking() async {}
}

class _FakeShare extends ShareService {
  String? text;
  @override
  Future<bool> shareText(String text) async {
    this.text = text;
    return true;
  }

  @override
  Future<bool> shareImage(Uint8List png, {required String text}) async => true;
}

class _FakeReminders extends ReminderService {
  List<Reminder> scheduled = [];
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> replaceAll(List<Reminder> reminders) async =>
      scheduled = reminders;
  @override
  Future<void> cancelAll() async => scheduled = [];
}

class _FakeNative extends NativeBridge {
  Map<String, Object?>? widget;
  @override
  Future<String?> recognizeText(Uint8List image) async => _receipt;
  @override
  Future<void> updateWidget(Map<String, Object?> data) async => widget = data;
}

final _mainScroll = find
    .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
    .first;

Future<void> _clearSnackBars(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('yeni özellikler: plan, artık, mevsim, fiş, barkod, ses, takip',
      (tester) async {
    tester.view.physicalSize = _screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      repo: IngredientRepository(ingredientCatalog),
      recipes: recipeCatalog,
      storage: StorageService(),
    );
    await state.load();
    state.updateProfile(state.profile.copyWith(
        onboarded: true,
        allergyAsked: true,
        appliancesAsked: true,
        cookDaysPerWeek: 5));
    state.upsertPantryAll([
      (ingredientId: 'tavuk_gogsu', quantity: 800, level: null),
      (ingredientId: 'pirinc', quantity: 1000, level: null),
      (ingredientId: 'mercimek', quantity: 500, level: null),
      (ingredientId: 'makarna', quantity: 500, level: null),
      (ingredientId: 'domates', quantity: 4, level: null),
      (ingredientId: 'sogan', quantity: 4, level: null),
      (ingredientId: 'patates', quantity: 5, level: null),
      (ingredientId: 'havuc', quantity: 3, level: null),
      (ingredientId: 'yogurt', quantity: 500, level: null),
    ]);

    final speech = _FakeSpeech();
    final share = _FakeShare();
    final reminders = _FakeReminders();
    final native = _FakeNative();
    final services = DeviceServices(
      speech: speech,
      share: share,
      reminders: reminders,
      native: native,
      photos: PhotoService(),
      cameraAvailable: false,
      httpClient: MockClient((req) async {
        if (req.url.host == 'world.openfoodfacts.org') {
          return http.Response.bytes(
              utf8.encode(jsonEncode({
                'product': {
                  'product_name_tr': 'Sütaş Süzme Yoğurt',
                  'quantity': '1 kg'
                }
              })),
              200);
        }
        return http.Response('', 404);
      }),
    );
    // main.dart'taki gibi: ana ekran aracı ve hatırlatmalar durumla eşitlenir.
    final sync = DigestSync(state, services);
    addTearDown(sync.dispose);
    final r = ScreenshotReport('degisiklik_raporlari/2026-11-04_v2-ozellikler',
        'Yeni özellikler · Ekran testi');

    debugDisableShadows = false;
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state),
            Provider.value(value: services),
          ],
          child: const BuzdolabiSefiApp(),
        ),
      ));

      // ------------------------------------------------ Ana sayfa
      await tester.scrollUntilVisible(find.text('Dolabı doldur'), 200,
          scrollable: _mainScroll);
      await r.capture(tester,
          title: 'Ana sayfa: hızlı girişler',
          action: 'Uygulamayı açıp biraz kaydırdım.',
          result:
              'Yeşil kartın altında dört yeni kutu: Haftalık plan, Dünden kalan, '
              'Mevsiminde, Dolabı doldur.');

      // ------------------------------------------------ Haftalık plan
      await r.tap(tester, find.text('Haftalık plan'), 'Haftalık plan');
      await r.capture(tester,
          title: 'Haftalık plan',
          action: '"Haftalık plan"a dokundum.',
          result: 'Ankette "5-6 gün" dediğim için 5 akşamlık plan öneriyor.');
      await r.tap(tester, find.text('Planı çıkar'), 'Planı çıkar');
      await tester.pumpAndSettle();
      final nights = state.planNights;
      await r.capture(tester,
          title: 'Plan hazır',
          action: '"Planı çıkar"a bastım.',
          result: '${nights.length} akşam, her biri farklı ana malzemeyle; '
              '${nights.where((n) => n.ready).length} akşam dolabındakilerle hazır. '
              'Bir malzeme bir akşam kullanılınca sonraki akşam yeniden sayılmıyor.',
          ok: nights.length == 5 &&
              nights.map((n) => n.recipe.id).toSet().length == 5);
      expect(nights, hasLength(5));

      final before = state.planIds[1];
      await r.tap(tester, find.byTooltip('Başka tarif').at(1), 'Başka tarif');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Bir akşamı değiştir',
          action: 'İkinci akşamın ⇄ butonuna bastım.',
          result: 'Sadece o akşam değişti, diğerleri yerinde kaldı.',
          ok: state.planIds[1] != before);

      await tester.scrollUntilVisible(find.text('Yeniden planla'), 200,
          scrollable: _mainScroll);
      await r.capture(tester,
          title: 'Eksikler tek listede',
          action: 'Aşağı kaydırdım.',
          result:
              'Bütün haftanın eksikleri tek butonla alışveriş listesine eklenebiliyor.');
      Navigator.of(tester.element(find.text('Yeniden planla'))).pop();
      await tester.pumpAndSettle();

      // ------------------------------------------------ Dünden kalan
      await r.tap(tester, find.text('Dünden kalan'), 'Dünden kalan');
      await tester.pumpAndSettle();
      await r.tap(tester, find.text('Pişmiş pilav'), 'Pişmiş pilav');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Dünden kalan pilav',
          action: '"Dünden kalan"a girip "Pişmiş pilav"ı seçtim.',
          result:
              'Pilav 2 günlük olarak dolaba eklendi; onu değerlendiren tarifler '
              '(Yumurtalı Pilav Kavurması gibi) listeleniyor.',
          ok: state.leftovers.any((p) => p.ingredientId == 'pismis_pilav'));
      expect(find.textContaining('Pilav Kavurması'), findsWidgets);
      Navigator.of(tester.element(find.text('Neyin kaldı?'))).pop();
      await tester.pumpAndSettle();

      // ------------------------------------------------ Mevsim
      await r.tap(tester, find.text('Mevsiminde'), 'Mevsiminde');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Kasım mevsimi',
          action: '"Mevsiminde" kutusuna dokundum.',
          result:
              'Pırasa, ıspanak, karnabahar, brokoli, havuç… Dolabında olanlar '
              'yeşil. Altında bunlarla yapılan tarifler.');
      expect(find.text('Pırasa'), findsOneWidget);
      Navigator.of(tester.element(find.text('Bu ay mevsiminde'))).pop();
      await tester.pumpAndSettle();

      // ------------------------------------------------ Fiş
      await r.tap(tester, find.text('Dolabı doldur'), 'Dolabı doldur');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Dolabı hızlı doldur',
          action: '"Dolabı doldur"a dokundum.',
          result: 'Fiş fotoğrafı, e-fiş metni ya da barkod.');
      await r.tap(
          tester, find.text('Fiş metnini yapıştır'), 'Fiş metnini yapıştır');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), _receipt);
      await tester.tap(find.text('Oku'));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Fişte bulduklarım',
          action: 'Market fişinin metnini yapıştırıp "Oku"ya bastım.',
          result:
              'Süt (1 L), yumurta (10), pırasa (alt satırdaki 1,15 kg), beyaz peynir, kıyma bulundu; '
              '"TAM YAĞLI" yağ sanılmadı, deterjan gıda sayılmadı.');
      expect(find.text('Beyaz peynir'), findsOneWidget);
      expect(find.text('Sıvı yağ'), findsNothing);
      await r.tap(
          tester, find.textContaining('Dolabıma ekle'), 'Dolabıma ekle');
      await tester.pumpAndSettle();
      expect(state.snapshot.gramsById.containsKey('kiyma'), isTrue);

      // ------------------------------------------------ Barkod
      await r.tap(tester, find.text('Barkod okut'), 'Barkod okut');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '8690000000001');
      await tester.tap(find.text('Bul'));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Barkod',
          action:
              'Barkod numarasını yazıp "Bul"a bastım (kamera testte açılmıyor).',
          result:
              'Open Food Facts\'ten "Sütaş Süzme Yoğurt 1 kg" geldi, Yoğurt olarak eşleşti.');
      expect(find.textContaining('Yoğurt'), findsWidgets);
      await tester.tap(find.text('Dolaba ekle'));
      await tester.pumpAndSettle();
      await _clearSnackBars(tester);
      Navigator.of(tester.element(find.text('Barkod okut').first)).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Tek tek yazma'))).pop();
      await tester.pumpAndSettle();

      // ------------------------------------------------ Paylaşım kartı
      tester.state<NavigatorState>(find.byType(Navigator).first).push(
          MaterialPageRoute<void>(
              builder: (_) => const RecipeDetailScreen(recipeId: 'menemen')));
      await tester.pumpAndSettle();
      await r.tap(tester, find.byTooltip('Paylaş'), 'Paylaş');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'TikTok paylaşım kartı',
          action: 'Menemen tarifinde paylaş butonuna bastım.',
          result:
              'Hikâye boyutunda "Dolabımdan bu çıktı" kartı: malzeme sayısı, '
              'süre, kalori, protein ve Buzdolabı Şefi adı.');
      expect(find.text('Dolabımdan bu çıktı'), findsOneWidget);
      Navigator.of(tester.element(find.text('Dolabımdan bu çıktı'))).pop();
      await tester.pumpAndSettle();

      // ------------------------------------------------ Sesli pişirme
      Navigator.of(tester.element(find.text('Menemen').first)).push(
          MaterialPageRoute<void>(
              builder: (_) => const CookingModeScreen(
                  recipeId: 'menemen', servings: 2, initialStep: 0)));
      await tester.pumpAndSettle();
      await r.tap(tester, find.byTooltip('Sesli mod'), 'Sesli mod');
      await tester.pumpAndSettle();
      speech.onWords!('tamam sonraki adım', true);
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Sesli pişirme',
          action: 'Mikrofon simgesine basıp "tamam sonraki adım" dedim.',
          result:
              'Adımı sesli okudu, komutu anlayıp 2. adıma geçti; üstte duyduğunu yazıyor.',
          ok: speech.spoken.length >= 2 &&
              speech.spoken.last.startsWith('Adım 2'));
      expect(speech.spoken.last, startsWith('Adım 2'));
      speech.onWords!('bitti afiyet olsun', true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Senin tabağın'), 200,
          scrollable: _mainScroll);
      await tester.tap(find.byTooltip('Daha çok'));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Senin tabağın',
          action: '"Bitti" deyip kaydettim, yediğim porsiyonu 1,5 yaptım.',
          result:
              'Günlük kaloriye ve proteine eklenen miktar yazıyor; fotoğraf ekleyip '
              'paylaşabiliyorum.',
          ok: state.logs.last.portionsEaten == 1.5);
      expect(state.logs.last.portionsEaten, 1.5);
      await _clearSnackBars(tester);
      Navigator.of(tester.element(find.text('Senin tabağın')))
          .popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();

      // ------------------------------------------------ İlerleme
      await r.tap(tester, find.text('İlerleme'), 'İlerleme');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Bugün yediklerin',
          action: 'Alt menüden "İlerleme"ye geçtim.',
          result:
              'Bugünkü kalori ve protein hedefe göre çubukla; son 7 günün grafiği.');
      expect(find.text('Bugün yediklerin'), findsOneWidget);

      // ------------------------------------------------ Profil
      await r.tap(tester, find.text('Profil'), 'Profil');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Bildirim gönder'), 200,
          scrollable: _mainScroll);
      await tester.pumpAndSettle();
      // Hatırlatma kartını ekranın üstüne getir.
      await Scrollable.ensureVisible(tester.element(find.text('Hatırlatmalar')),
          alignment: 0.02);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bildirim gönder'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Hatırlatmalar ve hedefler',
          action: 'Profil\'de "Bildirim gönder"i açtım.',
          result:
              'İzin istendi; her gün plan saatinde bir öneri kuruldu. Günlük '
              'kalori-protein hedefleri buradan değişiyor.',
          ok: state.profile.remindersOn && reminders.scheduled.isNotEmpty);
      expect(reminders.scheduled, isNotEmpty);
      // Ana ekran aracına da veri gitti.
      expect(native.widget?['recipes'], isA<List>());
      expect(
          Digest(state, DateTime.now()).widgetData()['readyCount'], isA<int>());

      await tester.scrollUntilVisible(find.text('Şef+'), 200,
          scrollable: _mainScroll);
      await r.tap(tester, find.text('Şef+'), 'Şef+');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Şef+',
          action: '"Şef+"a dokundum.',
          result:
              'İlk sürümde hepsi ücretsiz. İleride Şef+ olacaklar (yapay zekalı '
              'video, ortak dolap) ve her zaman ücretsiz kalacaklar ayrı ayrı yazıyor.');
      expect(find.text('İlk sürümde hepsi ücretsiz'), findsOneWidget);
      Navigator.of(tester.element(find.text('İlk sürümde hepsi ücretsiz')))
          .pop();
      await tester.pumpAndSettle();

      await r.tap(tester, find.text('Gizlilik'), 'Gizlilik');
      await tester.pumpAndSettle();
      await r.capture(tester,
          title: 'Gizlilik ve KVKK',
          action: '"Gizlilik"e dokundum.',
          result:
              'Hangi bilginin telefonda kaldığı, hangisinin nereye gittiği ve '
              'KVKK hakları tek tek yazıyor.');
      expect(find.textContaining('telefonunda kalır'), findsOneWidget);
      Navigator.of(tester.element(find.textContaining('telefonunda kalır')))
          .pop();
      await tester.pumpAndSettle();

      // ------------------------------------------------ Liste paylaşımı
      state.addToShopping(['mantar', 'krema']);
      await r.tap(tester, find.text('Liste'), 'Liste');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Listeyi paylaş'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Ortak dolap'), 200,
          scrollable: _mainScroll);
      await r.capture(tester,
          title: 'Listeyi paylaş',
          action:
              '"Liste" sekmesinde paylaş butonuna bastım, sonra aşağı kaydırdım.',
          result:
              'Liste "☐ Mantar, ☐ Krema" diye mesajla gönderiliyor; karşı taraf indir butonuyla '
              'kendi listesine ekliyor. Gerçek zamanlı ortak dolap Şef+ ile sunucu gelince.',
          ok: share.text?.contains('☐ Mantar') ?? false);
      expect(share.text, contains('☐ Krema'));
      await _clearSnackBars(tester);
    } finally {
      debugDisableShadows = true;
      r.writeHtml();
      r.writePrototypeJson(_screen);
    }
  });
}
