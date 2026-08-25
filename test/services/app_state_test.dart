import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults: not exploring, all interests, onboarding not done', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    expect(state.isExploring, false);
    expect(state.interests,
        {'history', 'otium', 'headline', 'hotdeal'});
    expect(state.onboardingDone, false);
  });

  test('setExploring persists', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    await state.setExploring(true);
    expect(state.isExploring, true);
  });

  test('toggleInterest removes and adds', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    await state.toggleInterest('hotdeal');
    expect(state.interests.contains('hotdeal'), false);
    await state.toggleInterest('hotdeal');
    expect(state.interests.contains('hotdeal'), true);
  });

  test('completeOnboarding persists', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    await state.completeOnboarding();
    expect(state.onboardingDone, true);
  });
}
