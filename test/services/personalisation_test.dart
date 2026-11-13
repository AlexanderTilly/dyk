import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/hot_deal.dart';
import 'package:palma_app/models/profile_questions.dart';
import 'package:palma_app/models/subcategories.dart';
import 'package:palma_app/models/themes.dart';
import 'package:palma_app/models/tour.dart';
import 'package:palma_app/services/personalisation.dart';

Personalisation answered(Map<String, List<String>> a, {bool consent = false}) =>
    Personalisation(ProfileAnswers(a), offersConsent: consent);

Personalisation stale(Map<String, List<String>> a) => Personalisation(
    ProfileAnswers(a, version: 'an-older-question-set'),
    offersConsent: true);

HotDeal deal(String id, {String mode = 'scan', int from = 0, int to = 24}) =>
    HotDeal(
        id: id,
        businessName: id,
        offerText: 'x',
        redeemMode: mode,
        lat: 0,
        lng: 0,
        radiusMeters: 50,
        activeHourFrom: from,
        activeHourTo: to);

Tour tour(String id, int? minutes) => Tour(
    id: id,
    citypackId: 'c',
    type: 'history_walk',
    title: id,
    estMinutes: minutes);

void main() {
  group('no answers, stale answers', () {
    test('empty answers leave every order unchanged', () {
      const p = Personalisation.none;
      expect(orderThemes(tourThemes, p), tourThemes);
      final chips = subcategoryChipsFor({'otium'});
      expect(orderSubcategories(chips, p), chips);
      expect(orderTourTypes(['history_walk', 'food_drink', 'custom'], p),
          ['history_walk', 'food_drink', 'custom']);
    });

    test('stale answers are ignored, consent or not', () {
      final p = stale({
        'q2': ['C'],
        'q6': ['D'],
        'q5': ['D'],
        'q3': ['C'],
      });
      expect(p.active, isFalse);
      expect(orderThemes(tourThemes, p), tourThemes);
      final chips = subcategoryChipsFor({'otium'});
      expect(orderSubcategories(chips, p), chips);
      final tours = [tour('long', 200), tour('short', 30)];
      expect(orderToursByLength(tours, p), tours);
      final deals = [deal('a'), deal('b', mode: 'show')];
      expect(orderDeals(deals, p), deals);
    });
  });

  group('reorder, never filter', () {
    test('a chosen theme rises and nothing is dropped', () {
      final p = answered({
        'q2': ['B', 'C']
      });
      final out = orderThemes(tourThemes, p);
      expect(out.take(3).toSet(), {'ghosts', 'food_drink', 'old_shops'});
      expect(out.toSet(), tourThemes.toSet());
      expect(out.length, tourThemes.length);
    });

    test('unchosen themes keep their relative order', () {
      final out = orderThemes(tourThemes, answered({'q2': ['B']}));
      expect(out.first, 'ghosts');
      expect(out.skip(1).toList(), [for (final t in tourThemes) if (t != 'ghosts') t]);
    });

    test('q6 lifts leisure chips, all chips remain', () {
      final chips = subcategoryChipsFor({'otium'});
      final out = orderSubcategories(chips, answered({'q6': ['B', 'D']}));
      expect(out.take(2).toSet(), {'shops', 'natural_spaces'});
      expect(out.toSet(), chips.toSet());
      expect(out.last, unclassifiedKey);
    });

    test('q4 D lifts family-friendly places and records nothing else', () {
      final chips = subcategoryChipsFor({'otium'});
      final out = orderSubcategories(chips, answered({'q4': ['D']}));
      expect(out.first, 'natural_spaces');
      expect(out.toSet(), chips.toSet());
    });

    test('q3 orders tours by length, keeps all', () {
      final tours = [tour('mid', 90), tour('long', 150), tour('short', 40), tour('?', null)];
      final shortFirst = orderToursByLength(tours, answered({'q3': ['C']}));
      expect(shortFirst.first.id, 'short');
      expect(shortFirst.map((t) => t.id).toSet(), {'mid', 'long', 'short', '?'});
      final longFirst = orderToursByLength(tours, answered({'q3': ['D']}));
      expect(longFirst.first.id, 'long');
      expect(longFirst.length, 4);
    });

    test('q2 lifts the matching tour section', () {
      final out = orderTourTypes(['history_walk', 'food_drink', 'custom'],
          answered({'q2': ['C']}));
      expect(out, ['food_drink', 'history_walk', 'custom']);
    });
  });

  group('offers', () {
    final deals = [deal('scan'), deal('show', mode: 'show')];

    test('without consent Hot Deals keep their order', () {
      final p = answered({'q5': ['D']}, consent: false);
      expect(orderDeals(deals, p), deals);
    });

    test('with consent they reorder and none are dropped', () {
      final p = answered({'q5': ['D']}, consent: true);
      final out = orderDeals(deals, p);
      expect(out.first.id, 'show');
      expect(out.map((d) => d.id).toSet(), {'scan', 'show'});
    });

    test('consent without q5 answer changes nothing', () {
      expect(orderDeals(deals, answered({'q2': ['A']}, consent: true)), deals);
    });
  });
}
