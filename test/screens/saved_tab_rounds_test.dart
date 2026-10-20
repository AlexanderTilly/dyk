import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/tour.dart';
import 'package:palma_app/screens/tabs/saved_tab.dart';
import 'package:palma_app/services/audio_service.dart';
import 'package:palma_app/services/auth_service.dart';
import 'package:palma_app/services/dyk_repository.dart';
import 'package:palma_app/services/saved_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements DykRepositoryBase {
  int calls = 0;
  @override
  Future<List<Tour>> loadSavedTours() async {
    calls++;
    return [
      const Tour(
          id: 't1',
          citypackId: 'c',
          type: 'custom',
          title: 'Ghosts walk, 2 km',
          distanceMeters: 1760,
          estMinutes: 56,
          isGenerated: true)
    ];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth implements AuthService {
  final bool signedIn;
  _Auth(this.signedIn);
  @override
  bool get isSignedIn => signedIn;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Audio implements AudioService {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<_Repo> _mount(WidgetTester t, {required bool signedIn}) async {
  SharedPreferences.setMockInitialValues({});
  final repo = _Repo();
  final store = SavedStore(await SharedPreferences.getInstance());
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SavedTab(
        savedStore: store,
        allHotspots: const [],
        audioService: _Audio(),
        repo: repo,
        authService: _Auth(signedIn),
      ),
    ),
  ));
  await t.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('signed in: a saved round is listed', (t) async {
    await _mount(t, signedIn: true);
    expect(find.text('Ghosts walk, 2 km'), findsOneWidget);
  });

  testWidgets('signed out: no rounds section and no load', (t) async {
    final repo = await _mount(t, signedIn: false);
    expect(find.text('Ghosts walk, 2 km'), findsNothing);
    expect(repo.calls, 0);
  });
}
