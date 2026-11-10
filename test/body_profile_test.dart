import 'package:buzdolabi_sefi/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kadın, 30, 165 cm, 65 kg, biraz hareketli: kilo korumak', () {
    const b = BodyProfile(
        sex: Sex.female,
        age: 30,
        heightCm: 165,
        weightKg: 65,
        activity: ActivityLevel.light);
    // Mifflin-St Jeor: 10·65 + 6,25·165 − 5·30 − 161 = 1370
    expect(b.bmr.round(), 1370);
    // 1370 × 1,375 = 1884 → 1900; protein 65 × 1,0 = 65 g
    expect(b.targets.kcal, 1900);
    expect(b.targets.protein, 65);
    expect(b.targets.fiber, 27); // 1900 × 14 / 1000 = 26,6
  });

  test('kilo vermek: %20 açık, protein en az 1,2 g/kg', () {
    const b = BodyProfile(
        sex: Sex.female,
        age: 30,
        heightCm: 165,
        weightKg: 65,
        activity: ActivityLevel.light,
        goal: WeightGoal.lose);
    expect(b.targets.kcal, 1500); // 1884 × 0,8 = 1507
    expect(b.targets.protein, 80); // 65 × 1,2 = 78 → 80
    expect(b.targets.fiber, 21);
  });

  test('erkek, 25, 180 cm, 80 kg, hareketli: kas almak', () {
    const b = BodyProfile(
        sex: Sex.male,
        age: 25,
        heightCm: 180,
        weightKg: 80,
        activity: ActivityLevel.moderate,
        goal: WeightGoal.gain);
    expect(b.bmr.round(), 1805);
    expect(b.targets.kcal, 3100); // 1805 × 1,55 + 300 = 3098
    expect(b.targets.protein, 110); // 80 × 1,4 = 112 → 110
    expect(b.targets.fiber, 40, reason: '43 g üst sınırda kalır');
  });

  test('çok düşük kaloriye inilmez', () {
    const b = BodyProfile(
        sex: Sex.female,
        age: 70,
        heightCm: 150,
        weightKg: 45,
        activity: ActivityLevel.sedentary,
        goal: WeightGoal.lose);
    expect(b.targets.kcal, 1200);
  });

  test('18 yaş altı ve hatalı değerler hesaplanmaz', () {
    expect(BodyProfile.problem(age: 16, heightCm: 160, weightKg: 50),
        contains('18 yaş'));
    expect(
        BodyProfile.problem(age: 30, heightCm: 1.65, weightKg: 60), isNotNull,
        reason: 'boy metre yazılmış');
    expect(BodyProfile.problem(age: 30, heightCm: 165, weightKg: 60), isNull);
  });

  test('profil JSON\'una yazılıp okunur', () {
    const p = UserProfile(
        body: BodyProfile(
            sex: Sex.male,
            age: 40,
            heightCm: 175,
            weightKg: 82.5,
            activity: ActivityLevel.high,
            goal: WeightGoal.lose),
        dailyKcal: 2600,
        dailyProtein: 125);
    final back = UserProfile.fromJson(p.toJson());
    expect(back.body?.weightKg, 82.5);
    expect(back.body?.activity, ActivityLevel.high);
    expect(back.body?.goal, WeightGoal.lose);
    expect(back.dailyKcal, 2600);
    // Eski kayıtlarda vücut bilgisi yok.
    expect(UserProfile.fromJson(const UserProfile().toJson()).body, isNull);
  });
}
