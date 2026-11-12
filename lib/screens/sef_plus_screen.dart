import 'package:flutter/material.dart';

import '../services/premium.dart';
import '../theme/palette.dart';
import '../widgets/ui.dart';

/// Şef+ özelliklerinin yanında duran küçük rozet. İlk sürümde "ücretsiz" yazar.
class SefPlusBadge extends StatelessWidget {
  const SefPlusBadge({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const SefPlusScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Palette.butter,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: onDark ? Colors.white : Palette.butterText, width: 1.5),
        ),
        child: Text(
          firstReleaseFree ? 'Şef+ · şimdilik ücretsiz' : 'Şef+',
          style: TextStyle(
              fontFamily: Fonts.display,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              color: Color(0xFF1A1A17)), // hardal zemin her temada açık
        ),
      ),
    );
  }
}

/// Neyin ücretsiz kalacağını, neyin Şef+ olacağını ve nedenini dürüstçe anlatır.
class SefPlusScreen extends StatelessWidget {
  const SefPlusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Şef+')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
                color: Palette.basil, borderRadius: BorderRadius.circular(28)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Sym('🎉', size: 44),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('İlk sürümde hepsi ücretsiz',
                          style: TextStyle(
                              fontFamily: Fonts.display,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              height: 1.1,
                              color: Colors.white)),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Aşağıdakiler ileride Şef+ aboneliğine geçecek, çünkü bize sunucu '
                  've yapay zeka masrafı çıkarıyorlar. Şimdilik herkese açık.',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      height: 1.4,
                      color: Color(0xFFD6EEDF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Şef+ olacaklar', icon: '⭐'),
          for (final f in PremiumFeature.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SymBubble(f.emoji, size: 52, color: Palette.butterSoft),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.label, style: theme.textTheme.titleMedium),
                          Text(f.description, style: theme.textTheme.bodySmall),
                          if (f.freeMonthly > 0)
                            Text(
                                'Abonelik açılınca ücretsiz: ayda ${f.freeMonthly}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: Palette.accentDeep)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const SectionTitle('Her zaman ücretsiz', icon: '✅'),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in const [
                  'Dolabındakilerle tarif bulma ve karşılaştırma',
                  'TikTok, Instagram ve YouTube\'dan tarif kaydetme',
                  'Alışveriş listesi ve "Neler alabilirim?"',
                  'Fişten, barkoddan ve elle dolap doldurma',
                  'Haftalık plan',
                  'Dünden kalan, mevsim tarifleri, sesli pişirme',
                  'Günlük kalori-protein takibi, yemek günlüğü',
                  'Ana ekran aracı ve hatırlatmalar',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Palette.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(line,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
