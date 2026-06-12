import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locally persisted bookmarks. Syncs to Supabase once auth is added.
class SavedStore extends ChangeNotifier {
  static const _key = 'saved_hotspots';
  final SharedPreferences _prefs;

  SavedStore(this._prefs);

  Set<String> get savedIds => (_prefs.getStringList(_key) ?? []).toSet();

  bool isSaved(String hotspotId) => savedIds.contains(hotspotId);

  Future<void> toggle(String hotspotId) async {
    final s = savedIds;
    if (s.contains(hotspotId)) {
      s.remove(hotspotId);
    } else {
      s.add(hotspotId);
    }
    await _prefs.setStringList(_key, s.toList());
    notifyListeners();
  }
}
