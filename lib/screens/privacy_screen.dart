import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../widgets/ui.dart';

/// Veri sorumlusunun adı ve başvuru adresi. App Store'a göndermeden önce
/// gerçek bilgilerle değiştirilmeli (README → "Yasal").
const dataController = '[Geliştirici adı soyadı]';
const dataControllerContact = '[iletişim e-postası]';

/// KVKK aydınlatma metni ve gizlilik politikası (uygulamanın gerçekte yaptığına
/// göre yazıldı; yayından önce bir hukukçuya okutulmalı).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section(String icon, String title, List<String> lines) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FoodIcon(icon, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(title, style: theme.textTheme.titleMedium)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $l', style: theme.textTheme.bodyMedium),
                  ),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik ve KVKK')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('Kısaca: verilerin telefonunda kalır.',
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Hesap açmıyorsun, adını, e-postanı ya da konumunu istemiyoruz. '
            'Aşağıda hangi bilginin nerede durduğunu ve ne zaman telefondan '
            'çıktığını tek tek yazdık.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Palette.inkSoft),
          ),
          const SizedBox(height: 16),
          section('📱', 'Yalnızca telefonunda saklananlar', const [
            'Dolabındaki malzemeler, alışveriş listen, favorilerin, haftalık planın.',
            'Açılış anketi cevapların (amaç, kaç kişi, beslenme tarzı, aletler, plan saati) ve alerjilerin.',
            'Pişirme geçmişin, yediğin porsiyonlar, "Yaptım" fotoğrafların.',
            'Videodan kaydettiğin tarifler.',
            'Bunları biz göremeyiz. Uygulamayı silince ya da Profil\'deki "Tüm verilerimi sil" ile silinir.',
          ]),
          section('🌐', 'Telefondan çıkan bilgiler', const [
            'TikTok videosu paylaştığında: videonun adresi, açıklamasını almak için TikTok\'a gönderilir.',
            'Barkod okuttuğunda: barkod numarası, ürün adını bulmak için Open Food Facts\'e gönderilir.',
            'Şef+ yapay zekalı tarif açıksa: video adresi, açıklaması ya da konuşmanın yazıya dökülmüş hali ve malzeme listemiz sunucumuza ve yapay zeka hizmetine (Anthropic) gönderilir. Kim olduğun gönderilmez; sonuç aynı videoyu paylaşan herkes için saklanır.',
            'Sesli pişirme modunda: söylediklerin Apple\'ın ses tanımasıyla yazıya çevrilir; Apple bunu cihazda ya da kendi sunucularında yapabilir.',
            'Uygulama çökerse: çökme raporu (cihaz modeli, iOS sürümü, hatanın yeri) hata takibi için gönderilir. Kişisel bilgi eklenmez.',
          ]),
          section('🔒', 'Telefonda kalan işlemler', const [
            'Fiş fotoğrafındaki yazı Apple\'ın cihaz üstü yazı tanımasıyla okunur; fotoğraf gönderilmez ve saklanmaz.',
            'Videodaki konuşmanın yazıya çevrilmesi, mümkünse cihazda yapılır.',
            'Hatırlatmalar telefonun kendi bildirimleriyle kurulur.',
          ]),
          section('⚖', 'KVKK kapsamındaki hakların', [
            'Veri sorumlusu: $dataController.',
            'Kişisel verilerin, 6698 sayılı Kanun\'un 5. maddesindeki açık rıza ve sözleşmenin ifası şartlarına dayanarak, yalnızca uygulamanın çalışması için işlenir.',
            '11. madde uyarınca verilerinin işlenip işlenmediğini öğrenme, düzeltilmesini ya da silinmesini isteme, itiraz etme haklarına sahipsin.',
            'Başvuru: $dataControllerContact. Telefondaki verilerin için Profil\'deki "Tüm verilerimi sil" yeterlidir.',
          ]),
          Text('Son güncelleme: 4 Kasım 2026',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
