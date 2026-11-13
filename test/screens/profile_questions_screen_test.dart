import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/i18n/i18n.dart';
import 'package:palma_app/models/profile_questions.dart';
import 'package:palma_app/screens/profile_answers_screen.dart';
import 'package:palma_app/screens/profile_questions_screen.dart';
import 'package:palma_app/services/profile_store.dart';

class _FakeStore extends ChangeNotifier implements ProfileStore {
  ProfileAnswers _answers = ProfileAnswers.empty;
  bool? _consent;
  int saves = 0;
  bool deleteResult = true;

  @override
  ProfileAnswers get answers => _answers;
  @override
  bool? get offersConsent => _consent;
  @override
  bool get personalisedOffers => _consent == true;

  @override
  Future<void> save(ProfileAnswers a) async {
    saves++;
    _answers = a;
    notifyListeners();
  }

  @override
  Future<void> setOffersConsent(bool granted) async {
    _consent = granted;
    notifyListeners();
  }

  @override
  Future<bool> deleteEverything() async {
    _answers = ProfileAnswers.empty;
    _consent = null;
    notifyListeners();
    return deleteResult;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _open(WidgetTester t, Widget screen) async {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          key: const Key('open'),
          onPressed: () =>
              Navigator.of(c).push(MaterialPageRoute(builder: (_) => screen)),
          child: const SizedBox(width: 50, height: 50),
        ),
      ),
    ),
  ));
  await t.tap(find.byKey(const Key('open')));
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Future<void> _start(WidgetTester t, _FakeStore s) async {
  await _open(t, ProfileQuestionsScreen(store: s));
  await _tap(t, 'pq_start');
}

Future<void> _skipFrom(WidgetTester t, int fromIndex) async {
  for (var i = fromIndex; i < profileQuestions.length; i++) {
    await _tap(t, 'pq_skip');
  }
}

void main() {
  test('the model still says which questions take one answer and which two',
      () {
    expect([for (final q in profileQuestions) q.maxChoices],
        [1, 2, 1, 1, 1, 2]);
  });

  testWidgets('welcome shows the published texts verbatim', (t) async {
    await _open(t, ProfileQuestionsScreen(store: _FakeStore()));
    expect(find.text('Your city, your way'), findsOneWidget);
    expect(
        find.text(
            "Tell us what you love, and we'll help you discover a city that feels made for you."),
        findsOneWidget);
    expect(
        find.text(
            "Your answers help us suggest places, stories and routes you'll enjoy. They stay in Passim, and you can change or delete them at any time in your profile."),
        findsOneWidget);
  });

  testWidgets('a one-answer question keeps only the last pick', (t) async {
    final s = _FakeStore();
    await _start(t, s);
    await _tap(t, 'pq_opt_q1_A');
    await _tap(t, 'pq_opt_q1_B');
    await _tap(t, 'pq_next');
    await _skipFrom(t, 1);
    expect(s.answers.of('q1'), ['B']);
  });

  testWidgets('a two-answer question takes two but not three', (t) async {
    final s = _FakeStore();
    await _start(t, s);
    await _tap(t, 'pq_skip'); // q1
    await _tap(t, 'pq_opt_q2_A');
    await _tap(t, 'pq_opt_q2_B');
    await _tap(t, 'pq_opt_q2_C'); // over the limit: ignored
    await _tap(t, 'pq_next');
    await _skipFrom(t, 2);
    expect(s.answers.of('q2'), ['A', 'B']);
  });

  testWidgets('a picked answer can be taken back', (t) async {
    final s = _FakeStore();
    await _start(t, s);
    await _tap(t, 'pq_skip'); // q1
    await _tap(t, 'pq_opt_q2_A');
    await _tap(t, 'pq_opt_q2_B');
    await _tap(t, 'pq_opt_q2_A'); // untick
    await _tap(t, 'pq_opt_q2_C');
    await _tap(t, 'pq_next');
    await _skipFrom(t, 2);
    expect(s.answers.of('q2'), ['B', 'C']);
  });

  testWidgets('Next stays off until something is chosen', (t) async {
    await _start(t, _FakeStore());
    final next = t.widget<FilledButton>(find.byKey(const Key('pq_next')));
    expect(next.onPressed, isNull);
  });

  testWidgets('skipping every question saves nothing and asks no consent',
      (t) async {
    final s = _FakeStore();
    await _start(t, s);
    await _skipFrom(t, 0);
    expect(s.saves, 0);
    expect(s.answers.isEmpty, isTrue);
    expect(s.offersConsent, isNull);
    expect(find.text('Offers picked for you'), findsNothing);
    expect(find.byKey(const Key('open')), findsOneWidget); // closed
  });

  testWidgets('closing part-way keeps what was answered, no consent asked',
      (t) async {
    final s = _FakeStore();
    await _start(t, s);
    await _tap(t, 'pq_opt_q1_C');
    await _tap(t, 'pq_next');
    await _tap(t, 'pq_close');
    expect(s.answers.of('q1'), ['C']);
    expect(s.offersConsent, isNull);
    expect(find.byKey(const Key('open')), findsOneWidget);
  });

  testWidgets('consent step shows the published texts verbatim', (t) async {
    final s = _FakeStore();
    await _start(t, s);
    await _tap(t, 'pq_opt_q1_A');
    await _tap(t, 'pq_next');
    await _skipFrom(t, 1);
    expect(find.text('Offers picked for you'), findsOneWidget);
    expect(
        find.text(
            'Can we use your answers to choose which offers and partner deals you see in Passim? Your answers are never shared with the businesses. You can change this at any time in your profile.'),
        findsOneWidget);
    expect(find.text('Yes, personalise offers'), findsOneWidget);
    expect(find.text('No thanks'), findsOneWidget);
  });

  testWidgets('closing the consent step unanswered leaves it null',
      (t) async {
    final s = _FakeStore();
    await _start(t, s);
    await _tap(t, 'pq_opt_q1_A');
    await _tap(t, 'pq_next');
    await _skipFrom(t, 1);
    await _tap(t, 'pq_close');
    expect(s.offersConsent, isNull);
    expect(s.answers.of('q1'), ['A']); // answers were kept
    expect(find.byKey(const Key('open')), findsOneWidget);
  });

  testWidgets('No thanks records a real no, Yes a yes', (t) async {
    for (final yes in [false, true]) {
      final s = _FakeStore();
      await _start(t, s);
      await _tap(t, 'pq_opt_q1_A');
      await _tap(t, 'pq_next');
      await _skipFrom(t, 1);
      await _tap(t, yes ? 'pq_consent_yes' : 'pq_consent_no');
      expect(s.offersConsent, yes);
    }
  });

  group('review and delete', () {
    testWidgets('lists the answers in words', (t) async {
      final s = _FakeStore();
      await s.save(const ProfileAnswers({
        'q4': ['B']
      }));
      await _open(t, ProfileAnswersScreen(store: s));
      expect(find.text('With my partner'), findsOneWidget);
    });

    testWidgets('deleting says it worked when it did', (t) async {
      final s = _FakeStore();
      await s.save(const ProfileAnswers({
        'q4': ['B']
      }));
      await _open(t, ProfileAnswersScreen(store: s));
      await _tap(t, 'pq_delete');
      await _tap(t, 'pq_delete_confirm');
      expect(s.answers.isEmpty, isTrue);
      expect(find.byKey(const Key('pq_deleted_ok')), findsOneWidget);
      expect(find.byKey(const Key('pq_deleted_failed')), findsNothing);
    });

    testWidgets('deleting says plainly when the server copy survived',
        (t) async {
      final s = _FakeStore()..deleteResult = false;
      await s.save(const ProfileAnswers({
        'q4': ['B']
      }));
      await _open(t, ProfileAnswersScreen(store: s));
      await _tap(t, 'pq_delete');
      await _tap(t, 'pq_delete_confirm');
      expect(find.byKey(const Key('pq_deleted_failed')), findsOneWidget);
      expect(find.byKey(const Key('pq_deleted_ok')), findsNothing);
      expect(find.textContaining('That did not work'), findsOneWidget);
    });

    testWidgets('cancelling the confirm deletes nothing', (t) async {
      final s = _FakeStore();
      await s.save(const ProfileAnswers({
        'q4': ['B']
      }));
      await _open(t, ProfileAnswersScreen(store: s));
      await _tap(t, 'pq_delete');
      await _tap(t, 'pq_delete_cancel');
      expect(s.answers.isEmpty, isFalse);
    });
  });

  test('I18n is on English for these tests', () {
    expect(I18n.instance.code, 'en');
  });
}
