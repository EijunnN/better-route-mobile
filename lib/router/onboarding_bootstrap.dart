import 'package:shared_preferences/shared_preferences.dart';

/// First-launch onboarding flag bridge.
///
/// The router needs a *synchronous* answer to "should we redirect to
/// onboarding?" so the GoRouter redirect callback can decide without
/// awaiting. We solve that by loading the persisted flag once before
/// `runApp` from `main()` and caching it in memory; subsequent reads
/// are O(1).
///
/// Lives outside `router.dart` so `main.dart` can import it without
/// dragging in screens or the GoRouter provider chain.
class OnboardingBootstrap {
  static const String _key = 'onboarding_seen_v1';
  static bool _seen = false;

  /// True if the driver has already finished the onboarding slides.
  /// Defaults to false until [load] resolves.
  static bool get seen => _seen;

  /// Read the persisted flag into memory. Call once from `main()`
  /// before `runApp`.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _seen = prefs.getBool(_key) ?? false;
  }

  /// Persist that the slides were completed. Updates both disk and
  /// the in-memory cache so subsequent redirects skip onboarding.
  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    _seen = true;
  }

  /// Reset — useful for QA flows ("Ver onboarding de nuevo").
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _seen = false;
  }
}
