import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../models/pantry_item.dart';
import '../services/device_services.dart';
import '../services/product_lookup.dart';
import '../services/receipt_parser.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import '../widgets/text_prompt.dart';

/// Malzemeleri tek tek yazmak yerine: fiş fotoğrafı, e-fiş metni ya da barkod.
class QuickFillScreen extends StatelessWidget {
  const QuickFillScreen({super.key});

  Future<void> _scanReceipt(BuildContext context) async {
    final services = DeviceServices.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final image = await services.photos.pickImageBytes();
    if (image == null) return;
    final text = await services.native.recognizeText(image);
    if (text == null || text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Fişteki yazıyı okuyamadım. Daha yakından ve düz çekmeyi dene '
              'ya da e-fiş metnini yapıştır.')));
      return;
    }
    nav.push(MaterialPageRoute<void>(
        builder: (_) => ReceiptReviewScreen(text: text)));
  }

  Future<void> _pasteReceipt(BuildContext context) async {
    final text = await askText(context,
        title: 'Fiş metnini yapıştır',
        confirm: 'Oku',
        minLines: 6,
        maxLines: 12,
        hint: 'Market uygulamasındaki e-fişi ya da e-arşiv faturayı '
            'kopyalayıp buraya yapıştır.');
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ReceiptReviewScreen(text: text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget option(String emoji, String title, String body, VoidCallback onTap,
            {Widget? badge}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SoftCard(
            onTap: onTap,
            child: Row(
              children: [
                IconBubble(emoji, size: 60, color: Palette.butterSoft),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(body, style: theme.textTheme.bodySmall),
                      if (badge != null) ...[const SizedBox(height: 6), badge],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Palette.inkSoft),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Dolabı hızlı doldur')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('Tek tek yazma', style: theme.textTheme.headlineSmall),
          Text('Marketten döndüğünde fişini ya da ürünlerin barkodunu okut.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Palette.inkSoft)),
          const SizedBox(height: 16),
          option(
              '🧾',
              'Fişin fotoğrafını çek',
              'Fişteki ürünleri okuyup dolabına ekler. Yazı telefonda okunur.',
              () => _scanReceipt(context)),
          option(
              '📋',
              'Fiş metnini yapıştır',
              'Market uygulamasındaki e-fişi kopyala, yapıştır.',
              () => _pasteReceipt(context)),
          option(
              '📦',
              'Barkod okut',
              'Ürünün barkodunu okut, tek tek ekle.',
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const BarcodeScreen()))),
        ],
      ),
    );
  }
}

/// Fişten bulunanları gösterir; kullanıcı onaylayınca dolaba ekler.
class ReceiptReviewScreen extends StatefulWidget {
  const ReceiptReviewScreen({super.key, required this.text});

  final String text;

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late final ReceiptResult _result =
      ReceiptParser(context.read<AppState>().repo).parse(widget.text);
  late final Set<String> _chosen = {
    for (final i in _result.items) i.ingredient.id
  };

  void _add() {
    final state = context.read<AppState>();
    state.upsertPantryAll([
      for (final i in _result.items)
        if (_chosen.contains(i.ingredient.id))
          (
            ingredientId: i.ingredient.id,
            quantity: i.quantity,
            level: i.quantity == null ? ApproxLevel.bol : null,
          )
    ]);
    final n = _chosen.length;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fişteki $n ürün dolabına eklendi')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _result.items;
    return Scaffold(
      appBar: AppBar(title: const Text('Fişte bulduklarım')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
              items.isEmpty
                  ? 'Fişte tanıdığım bir gıda bulamadım.'
                  : '${items.length} ürün buldum, eklemek istemediklerinin işaretini kaldır.',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (items.isNotEmpty)
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                children: [
                  for (final i in items)
                    CheckboxListTile(
                      value: _chosen.contains(i.ingredient.id),
                      onChanged: (v) => setState(() => v == true
                          ? _chosen.add(i.ingredient.id)
                          : _chosen.remove(i.ingredient.id)),
                      secondary: FoodIcon(i.ingredient.emoji, size: 34),
                      title: Text(i.ingredient.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                          [
                            if (i.quantity != null)
                              formatBase(i.ingredient, i.quantity!),
                            i.line,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          if (_result.unknown.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Gıda olmadığını düşündüklerim (${_result.unknown.length})',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final u in _result.unknown.take(12))
                  Pill(u.replaceAll(RegExp(r'\s+\*?\d+[.,]\d{2}.*$'), ''),
                      dense: true, color: Palette.ground),
              ],
            ),
          ],
          const SizedBox(height: 18),
          ChunkyButton(
            label: 'Dolabıma ekle (${_chosen.length})',
            icon: '🧺',
            tone: ChunkyTone.accent,
            onPressed: _chosen.isEmpty ? null : _add,
          ),
        ],
      ),
    );
  }
}

/// Barkod okuma: kamera ya da elle numara. Ürün Open Food Facts'te aranır.
class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key, this.useCamera = true});

  /// Testlerde ve kamerasız ortamda false.
  final bool useCamera;

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _lastCode;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup(String code) async {
    if (_busy || code == _lastCode) return;
    setState(() {
      _busy = true;
      _lastCode = code;
    });
    final state = context.read<AppState>();
    final lookup = ProductLookup(state.repo,
        client: DeviceServices.of(context).httpClient);
    final product = await lookup.byBarcode(code);
    if (!mounted) return;
    setState(() => _busy = false);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductSheet(product: product),
    );
    _lastCode = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Barkod okut')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: 300,
              child:
                  widget.useCamera && DeviceServices.of(context).cameraAvailable
                      ? MobileScanner(
                          onDetect: (capture) {
                            final v = capture.barcodes.firstOrNull?.rawValue;
                            if (v != null) _lookup(v);
                          },
                          errorBuilder: (_, __) => const _NoCamera(),
                        )
                      : const _NoCamera(),
            ),
          ),
          const SizedBox(height: 14),
          Text('Kamera açılmıyorsa barkod numarasını yaz',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '869…'),
                  onSubmitted: _lookup,
                ),
              ),
              const SizedBox(width: 10),
              ChunkyButton(
                label: _busy ? '…' : 'Bul',
                expand: false,
                height: 52,
                onPressed: _busy ? null : () => _lookup(_code.text.trim()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
              'Ürün bilgisi Open Food Facts\'ten (herkese açık ürün veritabanı) gelir. '
              'Her ürün orada olmayabilir; o zaman malzemeyi kendin seçersin.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _NoCamera extends StatelessWidget {
  const _NoCamera();

  @override
  Widget build(BuildContext context) => Container(
        color: Palette.basilSoft,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FoodIcon('📦', size: 72),
            SizedBox(height: 8),
            Text('Kamera burada açılamıyor',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _ProductSheet extends StatefulWidget {
  const _ProductSheet({required this.product});

  final ScannedProduct product;

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  late Ingredient? _ing = widget.product.ingredient;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final p = widget.product;
    final hits = state.repo.search(_search.text, limit: 5);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name ?? 'Ürün bulunamadı', style: theme.textTheme.titleLarge),
          Text('Barkod ${p.barcode}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          if (_ing != null)
            Row(
              children: [
                FoodIcon(_ing!.emoji, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      p.quantity != null && _ing == p.ingredient
                          ? '${_ing!.name} · ${formatBase(_ing!, p.quantity!)}'
                          : _ing!.name,
                      style: theme.textTheme.titleMedium),
                ),
                TextButton(
                    onPressed: () => setState(() => _ing = null),
                    child: const Text('Değiştir')),
              ],
            )
          else ...[
            const Text('Bu hangi malzeme?'),
            const SizedBox(height: 6),
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration:
                  const InputDecoration(hintText: 'Süt, yoğurt, makarna…'),
            ),
            for (final h in hits)
              ListTile(
                leading: FoodIcon(h.emoji, size: 30),
                title: Text(h.name),
                onTap: () => setState(() => _ing = h),
              ),
          ],
          const SizedBox(height: 14),
          ChunkyButton(
            label: 'Dolaba ekle',
            icon: '🧺',
            tone: ChunkyTone.accent,
            onPressed: _ing == null
                ? null
                : () {
                    final q = _ing == p.ingredient ? p.quantity : null;
                    state.upsertPantry(_ing!.id,
                        quantity: q, level: q == null ? ApproxLevel.bol : null);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${_ing!.name} dolabına eklendi')));
                  },
          ),
        ],
      ),
    );
  }
}
