import 'package:flutter/material.dart';

import 'ingredient.dart';
import 'recipe.dart';

/// Uygulama görünümü: varsayılan telefon ayarı.
enum UiTheme {
  system('Sistem'),
  light('Açık'),
  dark('Koyu');

  const UiTheme(this.label);

  final String label;

  ThemeMode get mode => switch (this) {
        UiTheme.system => ThemeMode.system,
        UiTheme.light => ThemeMode.light,
        UiTheme.dark => ThemeMode.dark,
      };
}

enum Diet {
  none('Yok'),
  vegetarian('Vejetaryen'),
  vegan('Vegan');

  const Diet(this.label);

  final String label;
}

/// "Seni buraya getiren ne?" (birden çok seçilebilir)
enum Goal {
  ideas('Ne pişireceğimi bulamıyorum', '🤔'),
  waste('Dolaptakiler çöpe gitmesin', '🌱'),
  healthy('Daha sağlıklı beslenmek', '💪'),
  budget('Mutfak masrafını azaltmak', '💰'),
  videos('Videolardaki tarifleri denemek', '🎬');

  const Goal(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// "Kimin için yemek yapıyorsun?" → tariflerin açıldığı porsiyon.
enum Household {
  solo('Sadece kendim', '🧑‍🍳', 1),
  couple('İki kişiyiz', '❤', 2),
  family('Ailem (3-4 kişi)', '🏠', 4),
  crowd('Kalabalık sofra', '🎉', 6);

  const Household(this.label, this.emoji, this.servings);

  final String label;
  final String emoji;
  final int servings;
}

/// "Nasıl besleniyorsun?" → diyet ve sonuçların varsayılan sırası.
enum EatingStyle {
  balanced('Dengeli, her şeyden', '🥗'),
  protein('Protein ağırlıklı', '💪'),
  light('Hafif, düşük kalori', '🪶'),
  vegetarian('Vejetaryen', '🥦'),
  vegan('Vegan', '🌱');

  const EatingStyle(this.label, this.emoji);

  final String label;
  final String emoji;

  Diet get diet => switch (this) {
        EatingStyle.vegetarian => Diet.vegetarian,
        EatingStyle.vegan => Diet.vegan,
        _ => Diet.none,
      };
}

/// "Tariflerini nasıl saklıyorsun?" (birden çok seçilebilir)
enum RecipeHabit {
  social('TikTok / Instagram\'da kaydediyorum', '📲'),
  screenshot('Ekran görüntüsü alıyorum', '📋'),
  notebook('Deftere yazıyorum', '📝'),
  memory('Saklamıyorum, aklımda', '🤔');

  const RecipeHabit(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// "Yemeği genelde ne zaman düşünürsün?" → ana sayfa karşılaması.
enum PlanTime {
  morning('Sabahtan planlarım', '☀', 'Bugün ne pişireceğini şimdiden seçelim.'),
  noon('Öğlen aklıma gelir', '🍽', 'Akşam için şimdiden bir fikir bulalım.'),
  evening('İşten dönerken', '⏱', 'Eve varmadan ne pişireceğin belli olsun.'),
  lastMinute(
      'Son dakika, acıkınca', '⚡', 'Hızlı olanlar önde, hemen başlayalım.');

  const PlanTime(this.label, this.emoji, this.homeLine);

  final String label;
  final String emoji;

  /// Ana sayfadaki karşılama cümlesi.
  final String homeLine;
}

class UserProfile {
  const UserProfile({
    this.allergies = const {},
    this.diet = Diet.none,
    this.appliances = const {Appliance.ocak, Appliance.firin},
    this.missingStaples = const {},
    this.allergyAsked = false,
    this.appliancesAsked = false,
    this.onboarded = false,
    this.goals = const {},
    this.cookDaysPerWeek,
    this.household,
    this.eating,
    this.habits = const {},
    this.planTime,
    this.remindersOn = false,
    this.dailyKcal = 2000,
    this.dailyProtein = 50,
    this.uiTheme = UiTheme.system,
    this.seenNavTour = false,
  });

  final Set<Allergen> allergies;
  final Diet diet;
  final Set<Appliance> appliances;

  /// Kullanıcının "evde yok" diye işaretlediği temel malzemeler.
  final Set<String> missingStaples;
  final bool allergyAsked;
  final bool appliancesAsked;

  /// Açılış anketi bitti ya da geçildi.
  final bool onboarded;
  final Set<Goal> goals;

  /// Haftalık seri hedefi; null ise varsayılan (3).
  final int? cookDaysPerWeek;
  final Household? household;
  final EatingStyle? eating;
  final Set<RecipeHabit> habits;
  final PlanTime? planTime;

  /// Plan saatinde ve bozulma öncesinde bildirim.
  final bool remindersOn;

  /// Günlük takip için hedefler (kullanıcı değiştirebilir; genel referans).
  final double dailyKcal;
  final double dailyProtein;

  /// Açık / koyu / sistem. Varsayılan: telefon ayarı.
  final UiTheme uiTheme;

  /// Alt menü turu bir kez gösterildi.
  final bool seenNavTour;

  /// Anket cevapları boşaltılmış hali (aletler de "sorulmadı"); alerjiler,
  /// evde olmayan temel malzemeler, hatırlatma, tema, tur ve günlük hedefler korunur.
  /// Yerel test sunucusu anketi her açılışta sıfırdan göstermek için kullanır.
  UserProfile withoutSurvey() => UserProfile(
        diet: diet,
        remindersOn: remindersOn,
        dailyKcal: dailyKcal,
        dailyProtein: dailyProtein,
        uiTheme: uiTheme,
        seenNavTour: seenNavTour,
      );

  /// Videodan tarif kaydetmeye yatkın mı? (TikTok kartı öne çıkar)
  bool get savesVideos =>
      goals.contains(Goal.videos) ||
      habits.contains(RecipeHabit.social) ||
      habits.contains(RecipeHabit.screenshot);

  UserProfile copyWith({
    Set<Allergen>? allergies,
    Diet? diet,
    Set<Appliance>? appliances,
    Set<String>? missingStaples,
    bool? allergyAsked,
    bool? appliancesAsked,
    bool? onboarded,
    Set<Goal>? goals,
    int? cookDaysPerWeek,
    Household? household,
    EatingStyle? eating,
    Set<RecipeHabit>? habits,
    PlanTime? planTime,
    bool? remindersOn,
    double? dailyKcal,
    double? dailyProtein,
    UiTheme? uiTheme,
    bool? seenNavTour,
  }) =>
      UserProfile(
        allergies: allergies ?? this.allergies,
        diet: diet ?? this.diet,
        appliances: appliances ?? this.appliances,
        missingStaples: missingStaples ?? this.missingStaples,
        allergyAsked: allergyAsked ?? this.allergyAsked,
        appliancesAsked: appliancesAsked ?? this.appliancesAsked,
        onboarded: onboarded ?? this.onboarded,
        goals: goals ?? this.goals,
        cookDaysPerWeek: cookDaysPerWeek ?? this.cookDaysPerWeek,
        household: household ?? this.household,
        eating: eating ?? this.eating,
        habits: habits ?? this.habits,
        planTime: planTime ?? this.planTime,
        remindersOn: remindersOn ?? this.remindersOn,
        dailyKcal: dailyKcal ?? this.dailyKcal,
        dailyProtein: dailyProtein ?? this.dailyProtein,
        uiTheme: uiTheme ?? this.uiTheme,
        seenNavTour: seenNavTour ?? this.seenNavTour,
      );

  Map<String, dynamic> toJson() => {
        'allergies': [for (final a in allergies) a.name],
        'diet': diet.name,
        'appliances': [for (final a in appliances) a.name],
        'missingStaples': missingStaples.toList(),
        'allergyAsked': allergyAsked,
        'appliancesAsked': appliancesAsked,
        'onboarded': onboarded,
        'goals': [for (final g in goals) g.name],
        if (cookDaysPerWeek != null) 'cookDaysPerWeek': cookDaysPerWeek,
        if (household != null) 'household': household!.name,
        if (eating != null) 'eating': eating!.name,
        'habits': [for (final h in habits) h.name],
        if (planTime != null) 'planTime': planTime!.name,
        'remindersOn': remindersOn,
        'dailyKcal': dailyKcal,
        'dailyProtein': dailyProtein,
        'uiTheme': uiTheme.name,
        'seenNavTour': seenNavTour,
      };

  static T? _enum<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static Set<T> _enums<T extends Enum>(List<T> values, Object? list) => {
        for (final n in (list as List? ?? const []))
          if (_enum(values, n) != null) _enum(values, n)!
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        allergies: {
          for (final a in (j['allergies'] as List? ?? const []))
            Allergen.values.byName(a as String)
        },
        diet: Diet.values.byName(j['diet'] as String? ?? Diet.none.name),
        appliances: {
          for (final a in (j['appliances'] as List? ?? const []))
            Appliance.values.byName(a as String)
        },
        missingStaples: {
          for (final s in (j['missingStaples'] as List? ?? const []))
            s as String
        },
        allergyAsked: j['allergyAsked'] as bool? ?? false,
        appliancesAsked: j['appliancesAsked'] as bool? ?? false,
        // Anket gelmeden önce uygulamayı kullananlara anket sorulmaz.
        onboarded: j['onboarded'] as bool? ?? true,
        goals: _enums(Goal.values, j['goals']),
        cookDaysPerWeek: j['cookDaysPerWeek'] as int?,
        household: _enum(Household.values, j['household']),
        eating: _enum(EatingStyle.values, j['eating']),
        habits: _enums(RecipeHabit.values, j['habits']),
        planTime: _enum(PlanTime.values, j['planTime']),
        remindersOn: j['remindersOn'] as bool? ?? false,
        dailyKcal: (j['dailyKcal'] as num?)?.toDouble() ?? 2000,
        dailyProtein: (j['dailyProtein'] as num?)?.toDouble() ?? 50,
        uiTheme: _enum(UiTheme.values, j['uiTheme']) ?? UiTheme.system,
        seenNavTour: j['seenNavTour'] as bool? ?? false,
      );
}
