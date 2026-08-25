import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'dyk_repository.dart';

/// What the current user has unlocked. A city's full content is available when
/// the user is premium or has purchased that city (free hotspots are always
/// available regardless).
class Entitlements extends ChangeNotifier {
  bool isPremium = false;
  Set<String> _cities = {};

  bool isCityUnlocked(String? cityId) =>
      isPremium || (cityId != null && _cities.contains(cityId));

  Future<void> load(DykRepositoryBase repo) async {
    final e = await repo.getEntitlements();
    isPremium = e.$1;
    _cities = e.$2;
    notifyListeners();
  }

  /// Returns null on success, 'signin' if not signed in, or an error message.
  Future<String?> unlockCity(
      DykRepositoryBase repo, AuthService auth, String cityId) async {
    if (!auth.isSignedIn) return 'signin';
    final err = await repo.unlockCity(cityId);
    if (err == null) {
      _cities = {..._cities, cityId};
      notifyListeners();
    }
    return err;
  }

  Future<String?> goPremium(DykRepositoryBase repo, AuthService auth) async {
    if (!auth.isSignedIn) return 'signin';
    final err = await repo.setPremium();
    if (err == null) {
      isPremium = true;
      notifyListeners();
    }
    return err;
  }
}
