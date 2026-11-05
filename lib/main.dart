import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'data/catalog.dart';
import 'data/remote_catalog.dart';
import 'services/device_services.dart';
import 'services/ingredient_repository.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';
import 'state/digest.dart';
import 'widgets/recipe_image.dart';

/// Çökme raporları için (boşsa kapalı):
///   --dart-define=SENTRY_DSN=https://...@....ingest.sentry.io/...
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Yerel test sunucusunda (tool/uygulamayi_ac.ps1) her açılışta açılış anketi
/// sıfırdan çıkar, dolap ve pişirme geçmişi (haftalık sayaç) silinir; her yenilemede
/// uygulama ilk kez açılmış gibi denenebilir. TestFlight/App Store sürümünde
/// bu ayar yoktur, kullanıcının verileri korunur.
const _surveyEveryLaunch = bool.fromEnvironment('ANKET_HER_ACILISTA');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Tarifler ve malzemeler assets/data/*.json dosyalarından okunur; sunucudan
  // daha yeni bir katalog indirildiyse (RemoteCatalog) o kullanılır.
  final bundledRecipes = await rootBundle.loadString(Catalog.recipesAsset);
  final catalog = await RemoteCatalog.cachedNewerThan(bundledRecipes) ??
      await Catalog.load(rootBundle);
  await RecipePhotos.init();
  for (final p in catalog.problems) {
    debugPrint('Katalog: $p');
  }
  final services = DeviceServices();
  final state = AppState(
    repo: IngredientRepository(catalog.ingredients),
    recipes: catalog.recipes,
    storage: StorageService(),
  );
  await state.load();
  if (_surveyEveryLaunch) {
    state.updateProfile(state.profile.withoutSurvey());
    state.resetForTesting();
  }

  // Arka planda: yeni katalog (bir sonraki açılışta devreye girer), ana ekran
  // aracı ve hatırlatmalar.
  RemoteCatalog().refresh(bundledRecipesJson: bundledRecipes);
  DigestSync(state, services);

  final app = MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      Provider.value(value: services),
    ],
    child: const BuzdolabiSefiApp(),
  );

  if (_sentryDsn.isEmpty) {
    runApp(app);
    return;
  }
  await SentryFlutter.init(
    (o) {
      o.dsn = _sentryDsn;
      // Kişisel bilgi (IP, kullanıcı) gönderilmez; yalnızca çökme yeri.
      o.sendDefaultPii = false;
      o.environment = kReleaseMode ? 'production' : 'debug';
    },
    appRunner: () => runApp(app),
  );
}
