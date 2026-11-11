# Proje notları (devam edecek kişi ya da yapay zekâ için)

Kurulum ve App Store adımları için `README.md`. Bu dosya, son çalışmalarda
alınan kararları ve dikkat edilecekleri özetler. Ayrıntılar git kayıt
mesajlarında (`git log`).

## Uygulama kısaca

Türkçe iOS tarif uygulaması (Flutter). Dolaptaki malzemelere ve miktarlara göre
tarif bulur; TikTok/Instagram/YouTube'dan tarif kaydeder; besin değeri
(kalori, protein, karbonhidrat, yağ, lif) ve diyetisyen yorumu verir.
İlk sürüm tamamen ücretsiz. Şef+ yalnızca sunucu/yapay zekâ masrafı çıkaran
özellikler için düşünülüyor (`lib/services/premium.dart`).

## Veriler

- `assets/data/recipes.json`: 300 tarif. Kategori dağılımı: ana yemek 118,
  kahvaltı 47, salata/meze 40, tatlı 34, çorba 31, atıştırmalık 30.
- `assets/data/ingredients.json`: 125 malzeme. Her birinde 100 g başına besin
  değeri (lif dahil, USDA'ya dayalı yaklaşık), alerjen, raf ömrü, yaklaşık fiyat,
  Türkçe ve İngilizce eş anlamlılar.
- Her tarif ve malzemenin `assets/icons/` içinde 3D ikonu olmalı
  (Microsoft Fluent Emoji, MIT). Emoji → dosya eşlemesi `lib/widgets/ui.dart`.
- Kızartmalarda yalnızca emilen yağ (≈3 yemek kaşığı) yazılır, tavadaki
  yağın tamamı değil.
- Kalite kuralları `test/matcher_test.dart` içinde (ana malzeme, en az 2 adım,
  benzersiz ad, ikon, porsiyon başı 20–1500 kcal). Tarif eklerken bu test
  geçmeli; tarif/malzeme sayısını tutan satır da güncellenmeli.

## Önemli kararlar

- **Tarif çıkarma** (`lib/services/caption_recipe_extractor.dart`) kural
  tabanlıdır, sunucu gerektirmez. Türkçe ("ekliyorum", "pişirip") ve İngilizce
  (Ingredients/Instructions, cup/tbsp/tsp/oz) açıklamaları anlar. Bulamadığını
  uydurmaz; tanınmayan malzemeleri kullanıcıya gösterir.
- **Başlık:** "Yoğurt ve süt" gibi yalnızca malzemeden oluşan adlar reddedilir;
  bilinen kombo (chia+süt → Chia puding), tek belirgin ana malzeme + "tarifi"
  veya "Videodan tarif" kullanılır. Eski zayıf başlıklı kayıt yeniden
  çıkarılır.
- **Aynı video** kısa/uzun link ya da aynı açıklama ile tekrar kaydedilirse kopya
  oluşmaz (`AppState.videoKey`, `sameVideo`).
- **Alerjiler:** listedekiler + "Diğer" ile serbest metin (`customAllergies`).
  Malzeme listesinde karşılığı varsa o malzemeyi içeren tarifler gizlenir.
- **Kişisel hedef** (`lib/models/body_profile.dart`): Mifflin-St Jeor ile kalori,
  kg başına protein, 1000 kcal başına 14 g lif. 18 yaş altı hesaplanmaz.
  Bilgiler yalnızca cihazda saklanır.
- **Hız:** `AppState.matches()` sonucu önbellekte tutulur; veri değişince ya da
  bir dakika geçince yenilenir. Ekranlar her çizimde eşleştirme yapıyordu ve
  300 tarifte yavaşlıyordu.

## Ana ekran aracı (iOS widget)

- Kod: `ios/HomeWidget/HomeWidget.swift`. Xcode projesine elle eklenmez;
  GitHub Actions derlemesinde `ios/scripts/add_share_extension.rb` ekler.
- Veriyi uygulama yazar: `lib/state/digest.dart` → `Digest.widgetData()`
  (hazır tarifler, bozulacak sayısı, "Kıymayı değerlendir" önerisi) →
  `AppDelegate.swift` → ortak kutu (App Group) → araç okur.
- Boyutlar: küçük, orta, kilit ekranı (dikdörtgen ve tek satır, iOS 16+).
- Dokununca: `buzdolabisefi://app/ne-pisirsem` ve `buzdolabisefi://app/dolap`
  (Info.plist → CFBundleURLSchemes, FlutterDeepLinkingEnabled). Flutter bunları
  ekran adı olarak alır; `lib/deep_links.dart` ekrana çevirir.
- Swift kodu Windows'ta derlenemez; ilk doğrulama GitHub Actions iOS
  derlemesinde olur.

## Bozulmak üzere bildirimleri

- `Digest.reminders()`: bozulmadan bir gün önce 10:00'da
  "Kıyma yarın bozuluyor" + "Şunu yapabilirsin: Kıymalı Pilav"
  (`tipForIngredient`). Hatırlatmalar açıksa uygulama her açılışta yeniler.
- Ana sayfa kartı ve günlük "Bugün ne pişirsem?" bildirimi de aynı öneriyi
  kullanır.

## Haftalık plan → alışveriş listesi

- `PlanScreen`: akşamlar sırayla değerlendirilir; bir akşamda kullanılan
  dolaptan düşülür (`MealPlanner.evaluate` / `missing`).
- "Bu haftaki planın için şunları al" listesi eksikleri gösterir;
  "Alışveriş listesine ekle" → `AppState.addToShopping`.

## Paylaşım kartı (ücretsiz reklam)

- `lib/widgets/share_card.dart`: 9:16 hikâye görseli ("Dolabımdan bu çıktı").
  Altında "Buzdolabı Şefi · App Store'da ücretsiz".
- Pişirme sonrası (`CookedScreen`) ve tarif detayında paylaş.
- Görsel geçici dosyaya yazılıp sistem paylaşımına verilir (Instagram hikâyesi
  için metin eklenmez; Meta görsel+metinde sorun çıkarır).

## Pişirme notu

- Pişirme bitince (`CookedScreen`) yıldız + isteğe bağlı not
  ("Tuzu azalttım"). `CookLog.note` cihazda saklanır.
- Aynı tarif tekrar açılınca / pişirme modunda `AppState.lastCookMemory`
  ile "Geçen sefer" hatırlatması gösterilir.

## Siri ve Kısayollar (iOS 16+)

- Kod: `ios/Runner/AppDelegate.swift` → `AddToPantryIntent` +
  `BuzdolabiSefiShortcuts`. Uygulamayı
  `buzdolabisefi://app/ekle?metin=6%20yumurta` ile açar; Flutter
  `QuantityParser` ile malzeme tanır ve `AppState.addToPantry` ile **üstüne
  ekler** (yerine yazmaz).
- Siri cümlelerinde uygulama adı gerekir: örn. "Hey Siri, dolabıma 6 yumurta
  ekle Buzdolabı Şefi". Kısayollar uygulamasından kısa bir özel cümle de
  tanımlanabilir.
- Yalnızca listedeki 125 malzeme; tanınmazsa Dolabım açılır ve uyarı gösterilir.

## Test modu (dikkat)

`--dart-define=ANKET_HER_ACILISTA=true` ile çalışan sürümde her açılışta anket
yeniden gelir; dolap ve pişirme geçmişi silinir. **App Store sürümünde bu bayrak
verilmemeli.**

## Telefonda tarayıcıdan test (aynı Wi-Fi)

Üç ayrı terminalde:

```
flutter build web --release --dart-define=ANKET_HER_ACILISTA=true
dart run tool/serve_web.dart 8091
dart run tool/oembed_proxy.dart
```

Telefonda: `http://<bilgisayarın IP adresi>:8091` (IP adresi değişebilir;
`ipconfig` ile bak).

- `serve_web.dart` dosyaları sıkıştırır ve önbelleğe alır. Flutter'ın kendi
  geliştirme sunucusu bunu yapmıyor, telefonda yavaştı.
- `oembed_proxy.dart` TikTok açıklamasını getirir (tarayıcı doğrudan alamaz).
  Node.js sürümü (`.mjs`) bu bilgisayarın güvenlik duvarında engelli, Dart
  sürümünü kullan.
- TikTok oEmbed çoğu videoda boş `title` + kapak verir. Proxy ve
  `VideoInfoClient` boş başlığı kabul etmez; `tikwm` ile açıklamayı doldurur
  (`/tikwm`). Proxy'yi değiştirdikten sonra `dart run tool/oembed_proxy.dart`
  yeniden başlatılmalı.
- Tarayıcıda "videodan sesi yazıya çevirme" yoktur; yalnızca iPhone
  uygulamasında çalışır (Apple Speech).

## Bilinen eksikler / sıradaki adımlar

1. Gizlilik politikası + KVKK metni, bir web adresinde yayında olmalı
   (App Store şartı).
2. Gerçek yemek fotoğrafları (şu an 3D ikon).
3. Apple ile giriş + bulut yedeği; şu an tüm veriler yalnızca telefonda.
4. Şef+ yapay zekâ: sesli videodan tarif, İngilizce adımları Türkçeye çevirme.
5. Yeni malzemelerin (deniz ürünleri, meyveler) geçtiği tarif sayısı az.
6. Malzeme fiyatları elle girildi; enflasyonla eskir.

## Git

Kayıtlar yerel; GitHub'a gönderme (push) yalnızca sahibinin onayıyla.
Gizli anahtarlar (`*.p8`, `*.p12`, `*.mobileprovision`, API anahtarları)
asla kayda eklenmez; yalnızca GitHub Secrets'ta durur.
