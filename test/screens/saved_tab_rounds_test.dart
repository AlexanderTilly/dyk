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
  bool has = true;
  @override
  Future<List<Tour>> loadSavedTours() async {
    calls++;
    if (!has) return [];
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

  testWidgets('a tab that becomes active after a save shows the round',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _Repo()..has = false;
    final store = SavedStore(await SharedPreferences.getInstance());
    Widget tab(bool active) => MaterialApp(
          home: Scaffold(
            body: SavedTab(
              savedStore: store,
              allHotspots: const [],
              audioService: _Audio(),
              repo: repo,
              authService: _Auth(true),
              isActive: active,
            ),
          ),
        );
    await t.pumpWidget(tab(false));
    await t.pumpAndSettle();
    expect(find.text('Ghosts walk, 2 km'), findsNothing);
    expect(find.textContaining('Nothing saved yet'), findsOneWidget);

    repo.has = true; // the person saved a round on another tab
    await t.pumpWidget(tab(false)); // rebuild while inactive: no fetch
    await t.pumpAndSettle();
    expect(repo.calls, 1);
    await t.pumpWidget(tab(true));
    await t.pumpAndSettle();
    expect(find.text('Ghosts walk, 2 km'), findsOneWidget);
    // Rounds only: the empty note must not contradict the round.
    expect(find.textContaining('Nothing saved yet'), findsNothing);
  });
}
