/// Günlük kalori ve protein hedefini kişiye göre hesaplamak için vücut
/// bilgileri. Yalnızca cihazda saklanır.
///
/// Kalori: Mifflin-St Jeor formülüyle bazal metabolizma × hareket düzeyi
/// (yetişkinler için en yaygın kullanılan tahmin), hedefe göre ayarlanır.
/// Protein: kilogram başına öneri (hareketsiz yetişkinde 0,8 g/kg; spor ve
/// kilo verirken kası korumak için daha fazla). Tahmindir, tıbbi tavsiye
/// değildir; hamilelik, emzirme ve hastalıklarda ihtiyaç farklıdır.
library;

enum Sex {
  female('Kadın'),
  male('Erkek');

  const Sex(this.label);
  final String label;
}

enum ActivityLevel {
  sedentary('Çoğunlukla oturarak', 'Masa başı iş, az yürüyüş', 1.2, 0.8),
  light('Biraz hareketli', 'Haftada 1-3 gün yürüyüş ya da spor', 1.375, 1.0),
  moderate('Hareketli', 'Haftada 3-5 gün spor', 1.55, 1.2),
  high('Çok hareketli', 'Neredeyse her gün yoğun spor', 1.725, 1.5);

  const ActivityLevel(this.label, this.hint, this.factor, this.proteinPerKg);
  final String label;
  final String hint;

  /// Bazal metabolizmanın çarpanı.
  final double factor;

  /// Kilogram başına günlük protein (g).
  final double proteinPerKg;
}

enum WeightGoal {
  lose('Kilo vermek'),
  keep('Kilomu korumak'),
  gain('Kilo / kas almak');

  const WeightGoal(this.label);
  final String label;
}

typedef DailyTargets = ({double kcal, double protein});

class BodyProfile {
  const BodyProfile({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    this.activity = ActivityLevel.light,
    this.goal = WeightGoal.keep,
  });

  final Sex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activity;
  final WeightGoal goal;

  /// Formül yetişkinler için; uç değerlerde hesap yapılmaz.
  static String? problem({int? age, double? heightCm, double? weightKg}) {
    if (age == null || heightCm == null || weightKg == null) {
      return 'Yaş, boy ve kiloyu yaz.';
    }
    if (age < 18) {
      return '18 yaş altında ihtiyaç büyümeye göre değişir; bir doktora ya da '
          'diyetisyene danış.';
    }
    if (age > 100) return 'Yaşı kontrol et.';
    if (heightCm < 120 || heightCm > 230) return 'Boyu santimetre olarak yaz.';
    if (weightKg < 35 || weightKg > 250) return 'Kiloyu kilogram olarak yaz.';
    return null;
  }

  /// Bazal metabolizma hızı (kcal/gün), Mifflin-St Jeor.
  double get bmr =>
      10 * weightKg + 6.25 * heightCm - 5 * age + (sex == Sex.male ? 5 : -161);

  DailyTargets get targets {
    final maintain = bmr * activity.factor;
    var kcal = switch (goal) {
      // Haftada yaklaşık 0,5 kg; çok düşük kaloriye inilmez.
      WeightGoal.lose => maintain * 0.8,
      WeightGoal.keep => maintain,
      WeightGoal.gain => maintain + 300,
    };
    final floor = sex == Sex.male ? 1500.0 : 1200.0;
    if (kcal < floor) kcal = floor;

    var perKg = activity.proteinPerKg;
    // Kilo verirken kası korumak, kas alırken yapmak için daha fazla.
    if (goal == WeightGoal.lose && perKg < 1.2) perKg = 1.2;
    if (goal == WeightGoal.gain && perKg < 1.4) perKg = 1.4;
    return (
      kcal: (kcal / 50).round() * 50.0,
      protein: (weightKg * perKg / 5).round() * 5.0,
    );
  }

  BodyProfile copyWith({
    Sex? sex,
    int? age,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activity,
    WeightGoal? goal,
  }) =>
      BodyProfile(
        sex: sex ?? this.sex,
        age: age ?? this.age,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activity: activity ?? this.activity,
        goal: goal ?? this.goal,
      );

  Map<String, dynamic> toJson() => {
        'sex': sex.name,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activity': activity.name,
        'goal': goal.name,
      };

  static BodyProfile? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return BodyProfile(
        sex: Sex.values.byName(raw['sex'] as String),
        age: (raw['age'] as num).toInt(),
        heightCm: (raw['heightCm'] as num).toDouble(),
        weightKg: (raw['weightKg'] as num).toDouble(),
        activity: ActivityLevel.values
            .byName(raw['activity'] as String? ?? ActivityLevel.light.name),
        goal: WeightGoal.values
            .byName(raw['goal'] as String? ?? WeightGoal.keep.name),
      );
    } catch (_) {
      return null;
    }
  }
}
