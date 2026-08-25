import 'package:shared_preferences/shared_preferences.dart';

/// Local "steps explored" tally, derived from GPS movement inside the app
/// (~0.75 m per step). No pedometer permission needed; counts only what the
/// user walks while exploring or on a tour. Phase C adds real sensors.
class StepStore {
  static const metersPerStep = 0.75;
  static const _totalKey = 'steps_total_m';
  static const _dayKeyPrefix = 'steps_day_m_';

  static int stepsFromMeters(num meters) => (meters / metersPerStep).round();

  /// "~3 400" — rounded to the nearest hundred, thousands separated.
  static String fmt(num steps) {
    final rounded = ((steps / 100).round() * 100);
    final s = rounded.toString();
    final sep = s.length > 3
        ? '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)}'
        : s;
    return '~$sep';
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '$_dayKeyPrefix${n.year}-${n.month}-${n.day}';
  }

  /// Add walked meters (call with GPS deltas; caller filters jumps).
  static Future<void> addMeters(double meters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
        _totalKey, (prefs.getDouble(_totalKey) ?? 0) + meters);
    final key = _todayKey();
    await prefs.setDouble(key, (prefs.getDouble(key) ?? 0) + meters);
  }

  static Future<int> todaySteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // background isolate writes too
    return stepsFromMeters(prefs.getDouble(_todayKey()) ?? 0);
  }

  static Future<int> totalSteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return stepsFromMeters(prefs.getDouble(_totalKey) ?? 0);
  }
}
