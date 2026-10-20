import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/tour.dart';
import 'package:palma_app/services/tour_generator.dart';

void main() {
  test('signed out: needsAccount and no write attempted', () async {
    var writes = 0;
    final k = TourKeeper(
        isSignedIn: () => false,
        userId: () => null,
        write: (_, __) async => writes++);
    expect(await k.saveTour('t1'), SaveResult.needsAccount);
    expect(writes, 0);
  });

  test('signed in: saved, writing both ids', () async {
    final rows = <(String, String)>[];
    final k = TourKeeper(
        isSignedIn: () => true,
        userId: () => 'u1',
        write: (u, t) async => rows.add((u, t)));
    expect(await k.saveTour('t1'), SaveResult.saved);
    expect(rows, [('u1', 't1')]);
  });

  test('saving twice stays saved', () async {
    final k = TourKeeper(
        isSignedIn: () => true, userId: () => 'u1', write: (_, __) async {});
    expect(await k.saveTour('t1'), SaveResult.saved);
    expect(await k.saveTour('t1'), SaveResult.saved);
  });

  test('a failing write is failed, not thrown', () async {
    final k = TourKeeper(
        isSignedIn: () => true,
        userId: () => 'u1',
        write: (_, __) async => throw Exception('rls'));
    expect(await k.saveTour('t1'), SaveResult.failed);
  });

  test('isGenerated: false by default and from json, true from generator', () {
    final j = {'id': 'a', 'citypack_id': 'c', 'title': 'x'};
    expect(Tour.fromJson(j).isGenerated, isFalse);
    expect(Tour.fromJson({...j, 'is_generated': true}).isGenerated, isTrue);
    const g = GeneratedTour(
        tourId: 't', title: 'x', meters: 1, minutes: 1, stops: []);
    expect(g.toTour('c').isGenerated, isTrue);
  });
}
