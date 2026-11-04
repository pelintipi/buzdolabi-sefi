# Buzdolabı Şefi

Dolabındaki malzemelerle (ve elindeki **miktarlarla**) ne pişirebileceğini bulan
Flutter tarif uygulaması. Ürün planının 1. aşamasıdır (MVP).

## Kurulum

1. Flutter'ı kur: https://docs.flutter.dev/get-started/install/windows
   (Android için Android Studio da kurulmalı). Ardından `flutter doctor` çalıştır.
2. Platform klasörlerini (android/ios) oluştur. Mevcut dosyaların üzerine yazılmaz:
   ```
   cd buzdolabi_sefi
   flutter create . --org com.buzdolabisefi --platforms android,ios
   ```
3. Paketleri indir, testleri çalıştır, uygulamayı başlat:
   ```
   flutter pub get
   flutter test
   flutter run
   ```

## App Store'a yükleme (Mac olmadan, GitHub Actions ile)

`.github/workflows/ios-testflight.yml` önce testleri çalıştırır, sonra GitHub'ın macOS
sunucusunda uygulamayı imzalayıp App Store Connect'e (TestFlight) yükler.

**Bir kerelik hazırlık (hepsi tarayıcıdan):**

1. **Apple Developer Program** üyeliği (yıllık 99 $): https://developer.apple.com/programs/
2. **Bundle ID kaydı:** developer.apple.com → Certificates, IDs & Profiles → Identifiers → `+`
   → App IDs → Bundle ID: `com.buzdolabisefi.buzdolabiSefi`
3. **Uygulamayı oluştur:** appstoreconnect.apple.com → Uygulamalar → `+` → Yeni Uygulama,
   aynı Bundle ID'yi seç.
4. **API anahtarı:** App Store Connect → Kullanıcılar ve Erişim → Entegrasyonlar →
   App Store Connect API → anahtar oluştur. Rol: **Admin** (sertifika oluşturabilmesi için).
   `.p8` dosyası yalnızca bir kez indirilebilir.
5. **GitHub secret'ları:** depo → Settings → Secrets and variables → Actions:

   | Secret | Değer |
   |---|---|
   | `APP_STORE_CONNECT_KEY_ID` | Anahtar kimliği (ör. `ABC123DEFG`) |
   | `APP_STORE_CONNECT_ISSUER_ID` | Aynı sayfadaki Issuer ID |
   | `APP_STORE_CONNECT_API_KEY_P8` | `.p8` dosyasının tüm içeriği (BEGIN/END satırları dahil) |
   | `APPLE_TEAM_ID` | developer.apple.com → Membership → Team ID |

**Derleme:** GitHub → Actions → "iOS → TestFlight" → Run workflow
(ya da `git tag v0.1.0` ve `git push origin v0.1.0`).
Yüklenen sürüm 10-30 dakika içinde App Store Connect → TestFlight'ta görünür.

**Yayından önce App Store Connect'te:** ekran görüntüleri (6.9" iPhone), açıklama,
gizlilik politikası URL'si, "Uygulama Gizliliği" formu (veri toplanmıyor), yaş sınırı.
Sürümü seçip "İncelemeye Gönder".

## Neler var

| Özellik | Dosya |
|---|---|
| Serbest metinle giriş ("3 yumurta, yarım biber, biraz peynir"), Türkçe ek çözümleme | `lib/services/quantity_parser.dart`, `turkish_text.dart` |
| Malzeme hiyerarşisi (peynir → kaşar), eş anlamlılar, alerjen kalıtımı | `lib/services/ingredient_repository.dart` |
| Bardak/kaşık/adet → gram dönüşümü | `lib/services/unit_converter.dart` |
| Miktar bazlı eşleştirme: Hemen yapabilirsin / Alternatifle / Az kaldı | `lib/services/recipe_matcher.dart` |
| "Sadece X alırsan N tarif açılır" önerisi | `RecipeMatcher.unlockSuggestions` |
| Alerji, diyet ve mutfak aleti filtreleri (profil), hızlı filtreler | `RecipeMatcher.passesProfile`, `QuickFilters` |
| Porsiyon ayarı, akıllı yuvarlama, besin değerleri, maliyet | `lib/screens/recipe_detail_screen.dart` |
| Pişirme modu: ekran kapanmaz, çoklu zamanlayıcı, kaldığın adımdan devam | `lib/screens/cooking_mode_screen.dart` |
| "Pişirdim!": dolaptan düşme (tamamı/yarısı/düzenle), 10 sn geri alma, ödül | `lib/screens/cooked_screen.dart` |
| Dolap: yaklaşık miktar, son kullanma tarihi, yakında bozulacaklar | `lib/screens/pantry_screen.dart` |
| Haftalık seri, beceri ağacı, israf istatistiği | `lib/screens/progress_screen.dart` |
| 30 saniye kuralı: alerji ilk tarifte, aletler ilk pişirmeden sonra sorulur | `recipe_detail_screen.dart`, `cooked_screen.dart` |

Bütün veriler cihazda (`shared_preferences`) tutulur; sunucu yoktur.

## Henüz yok (sonraki aşamalar)

- Sesle ve fotoğrafla malzeme girişi, fiş okuma
- Uygulama kapalıyken zamanlayıcı bildirimi (`flutter_local_notifications` gerekir).
  Şu an uygulama arka plandan dönünce biten zamanlayıcı hemen haber verir.
- Alışveriş listesi, hane ve ortak dolap, Supabase senkronizasyonu
- Yapay zeka şef (Claude API), haftalık görevler, rozetler
- Tarif sayısı: 24 başlangıç tarifi var, hedef 300.

## Tarifler ve malzemeler (JSON)

Katalog koddan ayrıdır; uygulama açılışta bu iki dosyayı okur (`lib/data/catalog.dart`):

| Dosya | İçerik |
|---|---|
| `assets/data/ingredients.json` | Malzemeler: ad, emoji, birim, yoğunluk, adet ağırlığı, paket miktarı, raf ömrü, alerjenler, 100 g besin değeri, ₺/kg, `staple` (evde hep var) |
| `assets/data/recipes.json` | Tarifler: süre, zorluk, porsiyon, aletler, teknikler, etiketler, malzemeler, adımlar, ipucu |

**Yeni tarif eklemek:** `recipes.json` içindeki `recipes` listesine bir nesne ekle.
Kod değiştirmen gerekmez. Örnek:

```json
{
  "id": "rafadan",
  "title": "Rafadan Yumurta",
  "emoji": "🥚",
  "minutes": 8,
  "difficulty": "kolay",
  "servings": 1,
  "appliances": ["ocak"],
  "techniques": ["haslama"],
  "tags": ["kahvalti"],
  "items": [
    { "ingredient": "yumurta", "amount": 2, "measure": "adet", "role": "main" },
    { "ingredient": "tuz", "amount": 1, "measure": "tutam", "role": "side" }
  ],
  "steps": [
    { "text": "Kaynayan suya bırak.", "timerMinutes": 6, "timerLabel": "Haşlama" }
  ]
}
```

- `role`: `main` (ana malzeme, puanda 3 kat), `side` (yan), `optional` (isteğe bağlı).
- `measure`: `gram, kilogram, ml, litre, adet, suBardagi, cayBardagi, yemekKasigi,
  tatliKasigi, cayKasigi, kase, tutam, paket, dis, demet, dilim`.
- `difficulty`: `kolay, orta, zor`. `appliances`: `ocak, firin, airfryer, blender`.
  `techniques`: `cig, haslama, sote, kizartma, firin, karistirma`.
- Bir malzemenin yerine başkası kullanılabiliyorsa:
  `"substitutes": [{ "ingredient": "sivi_yag", "note": "Tereyağı yerine sıvı yağ." }]`.
- `ingredient` değerleri `ingredients.json` içindeki `id`'lerle aynı olmalı.

Hatalı bir tarif uygulamayı çökertmez: açılışta atlanır ve konsola `Katalog: ...`
diye yazılır. `flutter test` çalıştırınca `test/matcher_test.dart` kataloğun hatasız
olduğunu kontrol eder; hatalı tarif varsa hangisi ve neden olduğu yazılır.

## Veri notları

Besin değerleri TürKomp/USDA civarındaki yaklaşık değerlerdir; resmi tablolardan
tek tek doğrulanmadı. Fiyatlar kaba tahmindir ve uygulamada "tahmini" gösterilir.
Tarifler henüz bir aşçı ya da editör tarafından kontrol edilmedi.

## TikTok'tan tarif kaydetme

TikTok'ta bir videoda **Paylaş → Buzdolabı Şefi** denince tarif uygulamaya kaydedilir.

| Parça | Dosya |
|---|---|
| iOS paylaşım eklentisi ("Kaydedildi" kartı) | `ios/ShareExtension/ShareViewController.swift` |
| Eklentiyi Xcode projesine ekleyen betik (CI'da çalışır) | `ios/scripts/add_share_extension.rb` |
| Paylaşımları Flutter'a veren köprü | `ios/Runner/AppDelegate.swift` → `ShareInboxPlugin` |
| Video bilgisi (TikTok oEmbed) ve paylaşım kutusu | `lib/services/video_import.dart` |
| Açıklamadan tarif çıkarma (kural tabanlı, sunucusuz) | `lib/services/caption_recipe_extractor.dart` |
| Ekran | `lib/screens/import_recipe_screen.dart` |

Akış: eklenti linki uygulama grubunun ortak kutusuna (`group.<paket kimliği>`) bırakır →
uygulama açılınca/öne gelince kutuyu boşaltır → TikTok'un herkese açık oEmbed
servisinden açıklama, hesap adı ve kapak alınır → tarif çıkarılır, kaydedilir ve
dolapla karşılaştırılmış halde açılır. Video dosyası indirilmez.

Bilinen sınırlar:
- Tarif açıklamada yazmıyorsa (sesli anlatılıyorsa) çıkarılamaz; kullanıcıdan
  tarifi yapıştırması istenir.
- Katalogda olmayan malzemeler tarife eklenmez, "Tanıyamadığım malzemeler"
  altında gösterilir.
- Apple tarafında: Developer hesabında App Group yetkisi gerekir. Otomatik
  imzalama bunu kendisi kaydetmeye çalışır; ilk derlemede hata verirse
  developer.apple.com → Identifiers → App Groups'tan `group.<paket kimliği>`
  elle oluşturulup iki uygulama kimliğine (uygulama ve `.ShareExtension`) eklenir.

## Sürüm 2 özellikleri

| Özellik | Nerede | Not |
|---|---|---|
| Haftalık plan | `lib/services/meal_planner.dart`, `lib/screens/plan_screen.dart` | Akşam sayısı anketteki "haftada kaç gün". Bir malzeme bir akşam kullanılınca sonraki akşam yeniden "var" sayılmaz. |
| Dünden kalan | `lib/screens/leftover_screen.dart` | 5 pişmiş artık malzeme (`"leftover": true`), 7 tarif (`"artik"` etiketi). Bayat ekmek, ekmeğin alt türü. |
| Mevsim takvimi | `assets/data/ingredients.json` → `"season"` | Türkiye için yaklaşık aylar. |
| Fiş ve barkod | `lib/services/receipt_parser.dart`, `product_lookup.dart`, `lib/screens/quick_fill_screen.dart` | Fiş yazısı telefonda okunur (Apple Vision). Barkod: Open Food Facts. |
| Sesli pişirme | `lib/services/voice_commands.dart`, pişirme ekranındaki mikrofon | "sonraki", "geri", "tekrar oku", "zamanlayıcı", "bitti". |
| Ana ekran aracı | `ios/HomeWidget/` | Veri: `lib/state/digest.dart`. |
| Hatırlatmalar | Profil → Hatırlatmalar | Telefonun kendi bildirimleri; sunucu yok. |
| "Yaptım" fotoğrafı, günlük kalori-protein | Pişirdim ekranı, İlerleme | Fotoğraflar uygulama klasöründe. |
| TikTok'a paylaşım kartı | `lib/widgets/share_card.dart` | 1080×1920 görsel. |
| Video sahibi koleksiyonu | `lib/screens/creator_screen.dart` | "@hesabın tarifleri". |
| Liste paylaşma ve içe alma, Migros'ta ara | Alışveriş listesi | Getir/A101 adresleri doğrulanamadığı için yok. |
| Şef+ yapısı | `lib/services/premium.dart` | `firstReleaseFree = true`: ilk sürümde hepsi açık. |
| KVKK ve gizlilik | `lib/screens/privacy_screen.dart`, `ios/*/PrivacyInfo.xcprivacy` | Aşağıya bak. |

## Şef+ (ilk sürümde ücretsiz)

Kural: telefonda çalışan her şey hep ücretsiz; Şef+'ta yalnızca bize masraf
çıkaranlar var: yapay zekalı video tarifi ve ortak dolap. Abonelik açılacağı zaman
`firstReleaseFree` false yapılır, `Premium.subscribed` App Store satın alımına
(StoreKit, App Store Connect'te abonelik ürünü tanımlanınca) bağlanır.

## Sunucu (isteğe bağlı)

Hiçbiri olmadan uygulama çalışır; ayarlanınca ilgili özellik açılır.

**1. Tarifleri güncelleme olmadan yenilemek (ücretsiz).** `assets/data`
klasörünün GitHub "raw" adresini `CATALOG_URL` değişkeni yap (GitHub → Settings
→ Variables). Yeni tarif ekleyince `recipes.json` içindeki `"version"` değerini
artır; uygulama indirir, doğrular, bir sonraki açılışta kullanır.

**2. Yapay zekalı video tarifi (Şef+).** `server/` klasörü bir Supabase projesidir:
```
supabase link --project-ref <proje>
supabase db push                                   # video_recipes tablosu
supabase secrets set ANTHROPIC_API_KEY=<anahtar>
supabase functions deploy extract-recipe
```
Sonra GitHub'da `EXTRACT_URL` değişkeni (`https://<proje>.supabase.co/functions/v1/extract-recipe`)
ve `SUPABASE_ANON_KEY` secret'ı. Fonksiyon Claude Opus 5.5 kullanır (düşük
"effort"); malzeme alanı yalnızca katalogdaki kimliklerden biri olabilir. Bir
video bir kez çıkarılır, sonra herkes önbellekten alır. Kaba maliyet: yeni video
başına birkaç sent (girdi ~3 bin, çıktı ~1 bin token; 1M token $4 / $20). Daha
ucuz isterseniz `index.ts` içindeki modeli Claude Haiku 5.5 yapabilirsiniz.

**3. Çökme raporları.** sentry.io'da Flutter projesi aç, DSN'i `SENTRY_DSN`
secret'ı yap. Kişisel bilgi gönderilmez (`sendDefaultPii = false`).

**Ortak dolap** için (Şef+, henüz yok): Supabase Auth ile hane hesabı +
`households`, `pantry_items`, `shopping_items` tabloları ve Realtime abonelik.
O gelene kadar liste mesajla paylaşılıp içe alınıyor.

## Yasal (App Store'dan önce)

- `lib/screens/privacy_screen.dart` başındaki `dataController` ve
  `dataControllerContact` gerçek bilgilerle doldurulmalı. Metin uygulamanın
  gerçekte yaptığına göre yazıldı ama bir hukukçuya okutulmalı.
- App Store Connect'te gizlilik politikası adresi zorunlu: aynı metni bir web
  sayfasına koyun.
- App Store gizlilik etiketi: Sentry açıksa yalnızca "Crash Data, kimliğe
  bağlanmaz, izleme yok"; kapalıysa "Data Not Collected".
- `PrivacyInfo.xcprivacy` (Runner, ShareExtension, HomeWidget): UserDefaults
  kullanım gerekçeleri ve çökme verisi bildirildi.
- Apple Developer'da: üç uygulama kimliğine (uygulama, `.ShareExtension`,
  `.HomeWidget`) App Groups yetkisi ve `group.<paket kimliği>` grubu. Otomatik
  imzalama oluşturmazsa elle.
