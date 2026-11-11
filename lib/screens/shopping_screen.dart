import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/device_services.dart';
import '../services/premium.dart';
import 'sef_plus_screen.dart';

import '../services/recipe_matcher.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/ui.dart';
import '../widgets/text_prompt.dart';

/// Alışveriş listesi: tariflerdeki eksikler buraya gelir, "Aldım" deyince
/// dolaba geçer. Altında "Neler alabilirim?": tek bir malzemeyle en çok tarif
/// açan öneriler.
class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final items = state.shoppingList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alışveriş listesi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Paylaşılan listeyi ekle',
            onPressed: () => importSharedList(context),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Listeyi paylaş',
            onPressed: items.isEmpty ? null : () => shareList(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (items.isEmpty)
            SoftCard(
              child: Row(
                children: [
                  const Sym('📝', size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Listen boş', style: theme.textTheme.titleMedium),
                        Text(
                          'Haftalık planda "Alışveriş listesine ekle" de, bir tarifte '
                          'eksikleri ekle ya da aşağıdaki önerilerden seç.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
                '${items.length} malzeme · aldıkça "Aldım"a bas, dolabına eklensin',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            for (final id in items)
              Builder(builder: (_) {
                final ing = state.repo.byId(id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                    child: Row(
                      children: [
                        IconBubble(ing.emoji, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(ing.name,
                              style: theme.textTheme.titleMedium),
                        ),
                        ChunkyButton(
                          label: 'Aldım',
                          icon: '✅',
                          expand: false,
                          height: 40,
                          onPressed: () {
                            state.buyFromShopping(id);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('${ing.name} dolabına eklendi')));
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.search_rounded,
                              color: Palette.inkSoft),
                          tooltip: 'Migros\x27ta ara',
                          onPressed: () => launchUrl(
                              Uri.https('www.migros.com.tr', '/arama',
                                  {'q': ing.name}),
                              mode: LaunchMode.externalApplication),
                        ),
                        IconButton(
                          icon:
                              Icon(Icons.close_rounded, color: Palette.inkSoft),
                          tooltip: 'Listeden çıkar',
                          onPressed: () => state.removeFromShopping(id),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
          const SizedBox(height: 18),
          const _WhatToBuy(),
          const SizedBox(height: 18),
          const _SharedPantryCard(),
        ],
      ),
    );
  }
}

/// "Neler alabilirim?": dolaptakilere tek bir malzeme eklenince yapılabilir
/// hale gelen tarifleri sayar, en çok tarif açanları önerir.
class _WhatToBuy extends StatelessWidget {
  const _WhatToBuy();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final matches = state.matches(const QuickFilters());
    final suggestions =
        state.matcher.unlockSuggestions(matches).take(5).toList();

    List<String> examples(String ingredientId) => [
          for (final m in matches)
            if (m.group == MatchGroup.almost &&
                m.blocking?.item.ingredientId == ingredientId)
              m.recipe.title
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Neler alabilirim?', icon: '🛒'),
        if (state.pantry.isEmpty)
          SoftCard(
            color: Palette.butterSoft,
            borderColor: Palette.butter,
            child: Text(
              'Dolabına ne olduğunu ekleyince, hangi malzemeyi alırsan kaç tarifin '
              'açılacağını burada gösteririm.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else if (suggestions.isEmpty)
          SoftCard(
            child: Text(
              'Şu an tek bir malzemeyle açılan tarif yok. Dolabına birkaç malzeme '
              'daha eklersen öneriler çıkar.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else ...[
          Text(
              'Dolabındakilere bunlardan birini eklersen yeni tarifler açılır.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          for (final s in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    IconBubble(s.ingredient.emoji,
                        size: 52, color: Palette.butterSoft),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.ingredient.name,
                              style: theme.textTheme.titleMedium),
                          Text('+${s.recipeCount} tarif açılır',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: Palette.basilDeep)),
                          Text(examples(s.ingredient.id).take(2).join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChunkyButton(
                      label: state.isOnShoppingList(s.ingredient.id)
                          ? 'Listede'
                          : 'Ekle',
                      tone: ChunkyTone.butter,
                      expand: false,
                      height: 40,
                      onPressed: state.isOnShoppingList(s.ingredient.id)
                          ? null
                          : () => state.addToShopping([s.ingredient.id]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Listeyi metin olarak paylaşır (WhatsApp, Mesajlar...). Karşı taraf bu
/// metni kendi uygulamasında "Paylaşılan listeyi ekle" ile içe alır.
Future<void> shareList(BuildContext context) async {
  final state = context.read<AppState>();
  final lines = [
    for (final id in state.shoppingList) '☐ ${state.repo.byId(id).name}'
  ];
  await DeviceServices.of(context)
      .share
      .shareText('Alışveriş listesi (Buzdolabı Şefi)\n${lines.join('\n')}');
}

/// Mesajla gelen listeyi yapıştırınca tanınan malzemeleri listeye ekler.
Future<void> importSharedList(BuildContext context) async {
  final state = context.read<AppState>();
  final text = await askText(context,
      title: 'Paylaşılan listeyi ekle',
      confirm: 'Ekle',
      minLines: 4,
      maxLines: 10,
      hint: 'Evden gelen listeyi buraya yapıştır');
  if (text == null || !context.mounted) return;
  final ids = <String>{};
  for (final raw in text.split(RegExp(r'[\n,;]+'))) {
    final line = raw.replaceAll(RegExp(r'^[\s☐☑✓✔•*\-\d.)]+'), '').trim();
    if (line.isEmpty || line.startsWith('Alışveriş listesi')) continue;
    final ing = state.repo.findByName(line);
    if (ing != null) ids.add(ing.id);
  }
  final added = state.addToShopping(ids);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added == 0
          ? 'Listede yeni malzeme bulamadım'
          : '$added malzeme listene eklendi')));
}

/// Şef+ ortak dolap: gerçek zamanlı eşitleme sunucu açılınca gelecek;
/// şimdilik listeyi mesajla paylaşma yolunu gösterir.
class _SharedPantryCard extends StatelessWidget {
  const _SharedPantryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      color: Palette.butterSoft,
      borderColor: Palette.butter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Sym('🏠', size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(PremiumFeature.sharedPantry.label,
                    style: theme.textTheme.titleMedium),
              ),
              const SefPlusBadge(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Evdekilerle aynı listeyi anında görmek için sunucu gerekiyor; o gelene '
            'kadar listeyi sağ üstteki paylaş butonuyla mesajla gönder, karşı taraf indir '
            'butonuyla kendi listesine eklesin.',
            style: theme.textTheme.bodySmall?.copyWith(color: Palette.ink),
          ),
        ],
      ),
    );
  }
}
