import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global app state persisted locally: exploring on/off, chosen interests,
/// onboarding completion.
class AppState extends ChangeNotifier {
  final SharedPreferences _prefs;
  AppState(this._prefs);

  static const allInterests = ['history', 'funfact', 'headline', 'hotdeal'];

  bool get isExploring => _prefs.getBool('exploring') ?? false;

  Set<String> get interests =>
      (_prefs.getStringList('interests') ?? allInterests).toSet();

  bool get onboardingDone => _prefs.getBool('onboarding_done') ?? false;

  Future<void> setExploring(bool v) async {
    await _prefs.setBool('exploring', v);
    notifyListeners();
  }

  Future<void> toggleInterest(String interest) async {
    final s = interests;
    if (s.contains(interest)) {
      s.remove(interest);
    } else {
      s.add(interest);
    }
    await _prefs.setStringList('interests', s.toList());
    notifyListeners();
  }

  Future<void> setInterests(Set<String> newInterests) async {
    await _prefs.setStringList('interests', newInterests.toList());
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool('onboarding_done', true);
    notifyListeners();
  }
}
