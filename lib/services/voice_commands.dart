import 'turkish_text.dart';

/// Sesli pişirme modunda anlaşılan komutlar.
enum VoiceCommand {
  next('sonraki adım'),
  previous('önceki adım'),
  repeat('tekrar oku'),
  timer('zamanlayıcıyı başlat'),
  finish('bitti'),
  stop('sesli modu kapat');

  const VoiceCommand(this.example);

  /// Kullanıcıya gösterilen örnek söz.
  final String example;
}

/// "tamam sonrakine geç" → next. Cümlede birden çok komut varsa en sondaki
/// geçerlidir ("geri, yok yok sonraki" → next).
VoiceCommand? parseVoiceCommand(String words) {
  final text = TurkishText.fold(words);
  if (text.isEmpty) return null;
  const patterns = <VoiceCommand, List<String>>{
    VoiceCommand.next: [
      'sonraki',
      'sonrakine',
      'ileri',
      'devam',
      'gec',
      'siradaki'
    ],
    VoiceCommand.previous: ['onceki', 'geri', 'bir onceki'],
    VoiceCommand.repeat: [
      'tekrar',
      'yeniden oku',
      'oku',
      'ne diyordu',
      'anlamadim'
    ],
    VoiceCommand.timer: [
      'zamanlayici',
      'sayaci',
      'sure baslat',
      'baslat',
      'kur'
    ],
    VoiceCommand.finish: ['bitti', 'bitir', 'tamamladim', 'afiyet'],
    VoiceCommand.stop: ['sus', 'kapat', 'dinleme', 'sessiz'],
  };
  VoiceCommand? best;
  var bestPos = -1;
  patterns.forEach((cmd, keys) {
    for (final k in keys) {
      final pos = RegExp('(^| )$k').allMatches(text).lastOrNull?.start ?? -1;
      if (pos > bestPos) {
        bestPos = pos;
        best = cmd;
      }
    }
  });
  return best;
}
