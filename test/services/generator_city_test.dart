import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:palma_app/services/dyk_repository.dart';

import '../widget_test.dart' show FakeDykRepository;

void main() {
  group('generatorAvailable', () {
    test('a city in the set offers the generator', () {
      expect(generatorAvailable('palma', {'palma'}), isTrue);
    });

    test('a city outside the set does not', () {
      expect(generatorAvailable('madrid', {'palma'}), isFalse);
    });

    test('an empty set hides it everywhere', () {
      expect(generatorAvailable('palma', {}), isFalse);
      expect(generatorAvailable('madrid', {}), isFalse);
    });

    test('no selected city hides it', () {
      expect(generatorAvailable(null, {'palma'}), isFalse);
    });
  });

  group('loadGeneratorCities', () {
    test('the fake returns an empty set, so the generator is hidden', () async {
      final cities = await FakeDykRepository().loadGeneratorCities();
      expect(cities, isEmpty);
      expect(generatorAvailable('palma', cities), isFalse);
    });

    test('fails closed: an unreachable backend yields an empty set', () async {
      // Nothing listens on port 1, so the request errors out exactly as it
      // would offline or with the view missing (migration 051 not run yet).
      final repo = DykRepository(client: SupabaseClient('http://127.0.0.1:1', 'anon'));
      final cities = await repo.loadGeneratorCities();
      expect(cities, isEmpty);
      expect(generatorAvailable('palma', cities), isFalse);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('a PostgrestException (view missing) yields an empty set', () async {
      final cities = await generatorCitiesFrom(() => throw const PostgrestException(
          message: 'relation "public.generator_cities" does not exist',
          code: '42P01'));
      expect(cities, isEmpty);
    });
  });

  group('generatorCitiesFromRows', () {
    test('maps a normal response to both ids', () {
      expect(
          generatorCitiesFromRows([
            {'citypack_id': 'a', 'narrated_count': 30},
            {'citypack_id': 'b', 'narrated_count': 21},
          ]),
          {'a', 'b'});
    });
    test('empty list gives empty set', () {
      expect(generatorCitiesFromRows([]), isEmpty);
    });
    test('null or non-string ids are skipped, not invented', () {
      expect(
          generatorCitiesFromRows([
            {'citypack_id': null},
            {'citypack_id': 5},
            {'other': 'x'},
            {'citypack_id': 'ok'},
          ]),
          {'ok'});
    });
  });
}
