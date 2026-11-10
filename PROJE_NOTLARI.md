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
