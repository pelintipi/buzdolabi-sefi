import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/device_services.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import 'ui.dart';

/// Profil'de "Yedek": hesap ve sunucu olmadığı için verilerin yalnızca bu
/// telefonda olduğunu açıkça söyler, yedek dosyası aldırır ve geri yükler.
class BackupCard extends StatelessWidget {
  const BackupCard({super.key});

  static String lastBackupText(DateTime? at, DateTime now) {
    if (at == null) return 'Hiç yedek almadın.';
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(at.year, at.month, at.day))
        .inDays;
    if (days <= 0) return 'Son yedek: bugün.';
    if (days == 1) return 'Son yedek: dün.';
    return 'Son yedek: $days gün önce.';
  }

  /// Hiç yedek yoksa ya da bir aydan eskiyse uyarı rengiyle gösterilir.
  static bool isStale(DateTime? at, DateTime now) =>
      at == null || now.difference(at).inDays >= 30;

  static String fileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'buzdolabi-sefi-yedek-${now.year}-${two(now.month)}-${two(now.day)}.json';
  }

  Future<void> _export(BuildContext context) async {
    final state = context.read<AppState>();
    final share = DeviceServices.of(context).share;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await share.shareTextFile(
        fileName(DateTime.now()), state.exportBackup());
    if (!ok) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Yedek dosyası hazırlanamadı.')));
    }
  }

  Future<void> _import(BuildContext context) async {
    final state = context.read<AppState>();
    final services = DeviceServices.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yedekten geri yükle'),
        content: const Text(
            'Seçeceğin yedek, bu telefondaki dolabın, favorilerin, kaydettiğin '
            'tarifler ve geçmişinin yerine geçer. Devam edilsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Dosya seç')),
        ],
      ),
    );
    if (sure != true) return;
    final content = await services.share.pickTextFile();
    if (content == null) return;
    try {
      state.importBackup(content);
      messenger.showSnackBar(const SnackBar(
          content: Text('Yedek geri yüklendi. Kaldığın yerden devam et.')));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = context.select<AppState, DateTime?>((s) => s.lastBackupAt);
    final now = DateTime.now();
    final stale = isStale(at, now);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Sym('📥', size: 28),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Yedek', style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hesap açmıyorsun; verilerin yalnızca bu telefonda. Uygulamayı '
            'silersen ya da telefon değiştirirsen dolabın, favorilerin, '
            'kaydettiğin tarifler ve geçmişin kaybolur. Ara sıra yedek al; '
            'dosyayı iCloud Drive\'a ya da Dosyalar\'a kaydet.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            lastBackupText(at, now),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: stale ? Palette.tomatoText : Palette.accent),
          ),
          const SizedBox(height: 10),
          ChunkyButton(
            label: 'Yedeği kaydet',
            icon: '📥',
            tone: stale ? ChunkyTone.primary : ChunkyTone.soft,
            height: 48,
            onPressed: () => _export(context),
          ),
          const SizedBox(height: 8),
          ChunkyButton(
            label: 'Yedekten geri yükle',
            icon: '🔄',
            tone: ChunkyTone.soft,
            height: 48,
            onPressed: () => _import(context),
          ),
          const SizedBox(height: 6),
          Text('Fotoğraflar yedeğe girmez; telefonunda kalır.',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Palette.inkSoft)),
        ],
      ),
    );
  }
}
