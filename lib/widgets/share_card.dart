import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../services/device_services.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import 'ui.dart';

/// "Dolabımdan bu çıktı" kartı: TikTok/Instagram hikâyesine uygun 9:16 görsel.
/// Önce önizleme gösterilir, kullanıcı "Paylaş" deyince görsel üretilir.
/// Kartta uygulama adı durur → ücretsiz reklam.
Future<void> showShareCard(BuildContext context, Recipe recipe,
    {String? photoPath}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Palette.ground,
    builder: (_) => _ShareSheet(recipe: recipe, photoPath: photoPath),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.recipe, this.photoPath});

  final Recipe recipe;
  final String? photoPath;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    final services = DeviceServices.of(context);
    final boundary =
        _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // 300 nokta genişlik × 3,6 = 1080 piksel (hikâye boyutu).
    final image = await boundary.toImage(pixelRatio: 3.6);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final ok = await services.share.shareImage(data.buffer.asUint8List());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hikâye kartı', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Instagram veya TikTok hikâyesinde paylaş. Kartta uygulama adı görünür.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            RepaintBoundary(
              key: _key,
              child:
                  ShareCard(recipe: widget.recipe, photoPath: widget.photoPath),
            ),
            const SizedBox(height: 14),
            ChunkyButton(
              label: _busy ? 'Hazırlanıyor…' : 'Hikâyede paylaş',
              icon: '📲',
              tone: ChunkyTone.accent,
              onPressed: _busy ? null : _share,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paylaşılan görsel telefonun açık/koyu temasından bağımsız hep aynı
/// görünür; temaya göre değişen Palette.ink burada kullanılmaz.
const _cardInk = Color(0xFF1A1A17);

class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.recipe, this.photoPath});

  final Recipe recipe;
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final n = state.matcher.factsOf(recipe).perServing;
    final count = recipe.items.where((i) => !i.optional).length;
    final photo = photoPath != null && !kIsWeb && File(photoPath!).existsSync()
        ? photoPath
        : null;
    Widget stat(String icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Sym(icon, size: 20, color: Palette.basil),
              const SizedBox(width: 4),
              Text(text,
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: _cardInk)),
            ],
          ),
        );

    return Container(
      width: 300,
      height: 533,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Palette.basil, borderRadius: BorderRadius.circular(28)),
      child: Stack(
        children: [
          const Positioned(right: -10, top: 30, child: Sym('🍅', size: 70)),
          const Positioned(right: 58, top: 22, child: Sym('🌿', size: 40)),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Palette.butter,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('Dolabımdan bu çıktı',
                      style: TextStyle(
                          fontFamily: Fonts.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _cardInk)),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Center(
                    child: photo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.file(File(photo),
                                width: 240, height: 240, fit: BoxFit.cover),
                          )
                        : FoodIcon(recipe.emoji, size: 170),
                  ),
                ),
                Text(recipe.title,
                    maxLines: 2,
                    style: const TextStyle(
                        fontFamily: Fonts.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 30,
                        height: 1.05,
                        color: Colors.white)),
                const SizedBox(height: 6),
                Text('$count malzemeyle, ${recipe.minutes} dakikada',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFFD6EEDF))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    stat('🔥', '${formatNumber(n.kcal, decimals: 0)} kcal'),
                    stat('💪',
                        '${formatNumber(n.protein, decimals: 0)} g protein'),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Sym('🧑‍🍳', size: 26, color: Color(0xFFD6EEDF)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Buzdolabı Şefi',
                              style: TextStyle(
                                  fontFamily: Fonts.display,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.white)),
                          Text('App Store\'da ücretsiz',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Color(0xFFD6EEDF))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
