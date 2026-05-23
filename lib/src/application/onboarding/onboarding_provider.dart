import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingDoneKey = 'onboarding_done';

/// Whether the user has completed the first-launch onboarding.
/// Overridden at startup via [ProviderScope] after reading SharedPreferences.
final onboardingDoneProvider = StateProvider<bool>((_) => false);

/// Marks onboarding as complete — persists to SharedPreferences and updates
/// the provider so the router redirects away from /onboarding.
Future<void> completeOnboarding(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDoneKey, true);
  ref.read(onboardingDoneProvider.notifier).state = true;
}

/// Reads the onboarding flag from SharedPreferences at startup.
Future<bool> readOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDoneKey) ?? false;
}
