import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../services/caption_recipe_extractor.dart';
import '../services/device_services.dart';
import '../services/premium.dart';
import '../services/video_import.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/ui.dart';
import '../widgets/video_source_card.dart';
import 'recipe_detail_screen.dart';

/// TikTok'tan paylaşılan videoyu ya da yapıştırılan linki/metni tarife çevirir,
/// kaydeder ve tarif ekranını açar. Açıklamada tarif yoksa kullanıcıdan
/// tarifi yapıştırmasını ister.
class ImportRecipeScreen extends StatefulWidget {
  const ImportRecipeScreen({super.key, this.payload, this.client});

  /// Paylaşım eklentisinden gelen içerik; null ise ekran boş form olarak açılır.
  final SharedPayload? payload;
  final VideoInfoClient? client;

  @override
  State<ImportRecipeScreen> createState() => _ImportRecipeScreenState();
}

enum _Phase { form, loading, noRecipe }

class _ImportRecipeScreenState extends State<ImportRecipeScreen> {
  final _link = TextEditingController();
  final _text = TextEditingController();
  late final VideoInfoClient _client = widget.client ?? VideoInfoClient();
  _Phase _phase = _Phase.form;
  VideoInfo? _info;

  /// Kullanıcının kaydettiği videonun sesinden (cihazda) çıkarılan konuşma.
  String? _transcript;

  /// Son denemede bir video linki var mıydı (hata mesajını seçmek için).
  bool _hadLink = false;

  @override
  void initState() {
    super.initState();
    final p = widget.payload;
    if (p != null) {
      _link.text = p.url ?? '';
      _text.text = p.text ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _link.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _canRun =>
      _link.text.trim().isNotEmpty || _text.text.trim().isNotEmpty;

  Future<void> _run() async {
    final state = context.read<AppState>();
    final payload = SharedPayload.fromRaw(
        url: _nonEmpty(_link.text), text: _nonEmpty(_text.text));
    final url = payload.url;

    // Aynı video ikinci kez paylaşıldıysa kopyalamak yerine kayıtlı tarifi aç.
    final existing = url == null ? null : state.importedFromUrl(url);
    if (existing != null && payload.text == null) {
      _openRecipe(existing, 'Bu videoyu daha önce kaydetmiştin');
      return;
    }

    setState(() {
      _phase = _Phase.loading;
      _hadLink = url != null;
    });
    if (url != null && payload.isTikTok && _info?.url != url) {
      _info = await _client.fetch(url);
    }
    if (!mounted) return;

    // Paylaşılan metin ("Bu tarife bak!") ile videonun açıklamasından hangisinde
    // daha çok malzeme bulunursa o kullanılır; eşitlikte kullanıcının metni.
    final extractor = CaptionRecipeExtractor(state.repo);
    final id = existing?.id ?? 'video_${DateTime.now().millisecondsSinceEpoch}';
    final source = RecipeSource(
      url: url ?? 'yapistirilan-metin',
      platform: payload.isTikTok ? 'TikTok' : 'Video',
      author: _info?.author,
      thumbnailUrl: _info?.thumbnailUrl,
    );
    ExtractedRecipe? extracted;
    for (final text in [payload.text, _info?.caption]) {
      if (text == null || text.trim().isEmpty) continue;
      final x = extractor.extract(text,
          id: id, fallbackTitle: _info?.caption, source: source);
      if (extracted == null ||
          x.recipe.items.length > extracted.recipe.items.length) {
        extracted = x;
      }
    }
    extracted ??= extractor.extract('', id: id, source: source);

    // Şef+: kural tabanlı çıkarma zayıf kaldıysa (tarif yok, tanınmayan
    // malzeme var, adımlar yok) yapay zekaya sor. Sunucu ayarlı değilse atlanır.
    final ai = DeviceServices.of(context).ai;
    final weak = !extracted.isUsable ||
        extracted.unmatched.isNotEmpty ||
        extracted.recipe.steps.length < 2;
    if (weak &&
        ai.configured &&
        const Premium().canUse(PremiumFeature.aiVideo)) {
      final better = await ai.extract(
        repo: state.repo,
        id: id,
        source: source,
        caption: payload.text ?? _info?.caption,
        transcript: _transcript,
      );
      if (!mounted) return;
      if (better != null &&
          better.recipe.items.length >= extracted.recipe.items.length) {
        state.saveImported(better.recipe);
        _openRecipe(
            better.recipe,
            better.cached
                ? 'Kaydedildi (bu videoyu başkası da çıkarmıştı)'
                : 'Buzdolabı Şefi\x27ne kaydedildi');
        return;
      }
    }

    if (!extracted.isUsable) {
      setState(() => _phase = _Phase.noRecipe);
      return;
    }
    state.saveImported(extracted.recipe);
    _openRecipe(extracted.recipe, 'Buzdolabı Şefi\'ne kaydedildi');
  }

  Future<void> _fromVideoAudio() async {
    final services = DeviceServices.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final path = await services.photos.pickVideoPath();
    if (path == null) return;
    setState(() => _phase = _Phase.loading);
    final text = await services.native.transcribeVideo(path);
    if (!mounted) return;
    if (text == null || text.trim().length < 20) {
      setState(() => _phase = _Phase.noRecipe);
      messenger.showSnackBar(const SnackBar(
          content: Text('Videodaki konuşmayı yazıya çeviremedim.')));
      return;
    }
    _transcript = text;
    _text.text = text;
    await _run();
  }

  void _openRecipe(Recipe recipe, String banner) {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) =>
          RecipeDetailScreen(recipeId: recipe.id, savedBanner: banner),
    ));
  }

  static String? _nonEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Videodan tarif')),
      body: _phase == _Phase.loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FoodIcon('🎬', size: 96),
                  const SizedBox(height: 12),
                  Text('Videodaki tarif okunuyor…',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 180,
                    child: ChunkyProgress(value: 0.6),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                if (_phase == _Phase.noRecipe)
                  _NoRecipeCard(info: _info, hadLink: _hadLink),
                if (_phase == _Phase.noRecipe && _hadLink) ...[
                  const SizedBox(height: 12),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FoodIcon('🎙', size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('Tarif sesli mi anlatılıyor?',
                                  style: theme.textTheme.titleMedium),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                            'Videoyu telefonuna kaydettiysen galeriden seç; konuşmayı '
                            'telefonunda yazıya çevirip tarifi ondan çıkarayım.',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 10),
                        ChunkyButton(
                          label: 'Videoyu seç',
                          icon: '🎬',
                          tone: ChunkyTone.soft,
                          height: 48,
                          onPressed: _fromVideoAudio,
                        ),
                      ],
                    ),
                  ),
                ],
                if (_phase == _Phase.form) const _HowToCard(),
                const SizedBox(height: 16),
                Text('Video linki', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'https://www.tiktok.com/@…/video/…',
                    prefixIcon: Padding(
                        padding: EdgeInsets.all(10),
                        child: FoodIcon('🔗', size: 24)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                    _phase == _Phase.noRecipe
                        ? 'Videodaki tarifi buraya yaz ya da yapıştır'
                        : 'Açıklama ya da tarif metni (isteğe bağlı)',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                TextField(
                  controller: _text,
                  minLines: 5,
                  maxLines: 10,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Malzemeler: 2 yumurta, 1 su bardağı süt…\n'
                        'Yapılışı: Hepsini çırpın…',
                  ),
                ),
                const SizedBox(height: 18),
                ChunkyButton(
                  label: 'Tarifi kaydet',
                  icon: '📥',
                  tone: ChunkyTone.accent,
                  onPressed: _canRun ? _run : null,
                ),
              ],
            ),
    );
  }
}

/// Paylaş menüsünün nasıl kullanılacağını anlatan kart.
class _HowToCard extends StatelessWidget {
  const _HowToCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(String n, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Palette.butter, shape: BoxShape.circle),
                child: Text(n,
                    style: const TextStyle(
                        fontFamily: Fonts.display,
                        fontWeight: FontWeight.w800,
                        color: Palette.ink)),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(text,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 14.5))),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
          color: Palette.basil, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FoodIcon('📲', size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Text('TikTok\'tan tek dokunuşla',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: Colors.white)),
              ),
            ],
          ),
          step('1', 'Tarif videosunda Paylaş\'a dokun'),
          step('2', 'Listeden Buzdolabı Şefi\'ni seç'),
          step('3', 'Tarif, dolabınla karşılaştırılmış halde burada'),
          const SizedBox(height: 10),
          const Text('Ya da linki aşağıya yapıştır.',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFFD6EEDF))),
        ],
      ),
    );
  }
}

class _NoRecipeCard extends StatelessWidget {
  const _NoRecipeCard({required this.info, required this.hadLink});

  final VideoInfo? info;
  final bool hadLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      color: Palette.butterSoft,
      borderColor: Palette.butter,
      child: Row(
        children: [
          VideoThumb(url: info?.thumbnailUrl, width: 60, height: 80),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    !hadLink
                        ? 'Bu metinde tarif bulamadım'
                        : info == null
                            ? 'Videoya ulaşamadım'
                            : 'Açıklamada tarif yok',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  !hadLink
                      ? 'Malzemeleri "2 yumurta, 1 su bardağı süt" gibi miktarlarıyla yaz.'
                      : info == null
                          ? 'İnternet bağlantını kontrol et ya da tarifi aşağıya yapıştır.'
                          : 'Bu videoda tarif sesli anlatılıyor gibi. Malzemeleri '
                              'aşağıya yazarsan dolabınla karşılaştırırım.',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Palette.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
