import 'package:buzdolabi_sefi/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uiTheme varsayılan sistem; json round-trip', () {
    expect(const UserProfile().uiTheme, UiTheme.system);
    expect(UiTheme.system.mode, ThemeMode.system);

    final dark = const UserProfile().copyWith(uiTheme: UiTheme.dark);
    final again = UserProfile.fromJson(dark.toJson());
    expect(again.uiTheme, UiTheme.dark);
    expect(again.uiTheme.mode, ThemeMode.dark);

    final legacy = UserProfile.fromJson({'diet': 'none', 'appliances': []});
    expect(legacy.uiTheme, UiTheme.system);
    expect(legacy.seenNavTour, isFalse);

    final toured = legacy.copyWith(seenNavTour: true);
    expect(UserProfile.fromJson(toured.toJson()).seenNavTour, isTrue);
  });
}
