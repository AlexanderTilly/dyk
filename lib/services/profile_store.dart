import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_questions.dart';

/// Where someone's interest answers live.
///
/// **Without an account they never leave the phone.** The server tables are
/// keyed to `auth.uid()` and have no room for an anonymous row — deliberately.
/// Keying preferences to an install id would build a profile the person
/// cannot see, cannot reach and never knowingly created, and the published
/// privacy text promises the opposite: "otherwise they are only stored on
/// your phone."
///
/// Signing in uploads whatever is on the phone. Signing out leaves the local
/// copy alone, so the app keeps working the way it did before.
class ProfileStore extends ChangeNotifier {
  static const _answersKey = 'profile_answers';
  static const _consentKey = 'profile_offers_consent';
  static const _consentVersionKey = 'profile_consent_version';
  static const _promptedKey = 'profile_prompted';
  static const _storiesKey = 'profile_stories_heard';

  /// The welcome screen waits for a first finished walk or three stories,
  /// whichever comes first. Three because that is where someone stops
  /// sampling and starts using the app: one story is curiosity, three is a
  /// decision. A finished tour is a stronger signal, so either qualifies.
  static const storiesBeforePrompt = 3;

  final SupabaseClient _client;
  ProfileStore({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  ProfileAnswers _answers = ProfileAnswers.empty;
  ProfileAnswers get answers => _answers;

  bool? _offersConsent;

  /// Null means "never asked". That is not the same as "said no", and only a
  /// null may be asked again.
  bool? get offersConsent => _offersConsent;

  bool get personalisedOffers => _offersConsent == true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_answersKey);
    if (raw != null) {
      try {
        _answers = ProfileAnswers.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _answers = ProfileAnswers.empty;
      }
    }
    if (prefs.containsKey(_consentKey)) {
      _offersConsent = prefs.getBool(_consentKey);
    }
    notifyListeners();

    // The server copy wins when signed in: it is what follows the person to a
    // new phone. Best-effort — a failure here leaves the local answers alone.
    if (_client.auth.currentUser != null) {
      try {
        final rows = await _client.rpc('get_profile_answers') as List<dynamic>;
        if (rows.isNotEmpty) {
          final r = rows.first as Map<String, dynamic>;
          _answers = ProfileAnswers.fromJson({
            'version': r['question_version'],
            'answers': r['answers'],
          });
          await prefs.setString(_answersKey, jsonEncode(_answers.toJson()));
        }
        final c = await _client.rpc('get_offers_consent') as List<dynamic>;
        if (c.isNotEmpty) {
          _offersConsent =
              (c.first as Map<String, dynamic>)['offers_consent'] as bool?;
          if (_offersConsent != null) {
            await prefs.setBool(_consentKey, _offersConsent!);
          }
        }
        notifyListeners();
      } catch (e) {
        debugPrint('ProfileStore.load: server copy unavailable: $e');
      }
    }
  }

  Future<void> save(ProfileAnswers a) async {
    _answers = a;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_answersKey, jsonEncode(a.toJson()));
    await _pushAnswers();
  }

  Future<void> setOffersConsent(bool granted) async {
    _offersConsent = granted;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, granted);
    await prefs.setString(_consentVersionKey, consentVersion);
    if (_client.auth.currentUser == null) return;
    try {
      await _client.rpc('set_offers_consent', params: {
        'p_granted': granted,
        'p_consent_version': consentVersion,
      });
    } catch (e) {
      debugPrint('ProfileStore.setOffersConsent failed: $e');
    }
  }

  /// Delete means delete. The privacy text promises it, so a failure to reach
  /// the server is reported rather than swallowed — otherwise someone is told
  /// their data is gone while a row of it survives.
  Future<bool> deleteEverything() async {
    _answers = ProfileAnswers.empty;
    _offersConsent = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_answersKey);
    await prefs.remove(_consentKey);
    await prefs.remove(_consentVersionKey);
    if (_client.auth.currentUser == null) return true;
    try {
      await _client.rpc('delete_profile_answers');
      return true;
    } catch (e) {
      debugPrint('ProfileStore.deleteEverything: server delete failed: $e');
      return false;
    }
  }

  /// Called after a sign-in: carries whatever is on the phone up to the
  /// account, so answering before making an account is not wasted.
  Future<void> onSignedIn() async {
    if (_answers.isEmpty && _offersConsent == null) return;
    await _pushAnswers();
    if (_offersConsent != null) await setOffersConsent(_offersConsent!);
  }

  Future<void> _pushAnswers() async {
    if (_client.auth.currentUser == null || _answers.isEmpty) return;
    try {
      await _client.rpc('save_profile_answers', params: {
        'p_answers': _answers.byQuestion,
        'p_question_version': _answers.version,
      });
    } catch (e) {
      debugPrint('ProfileStore._pushAnswers failed: $e');
    }
  }

  // --- when to offer the questionnaire -------------------------------------

  Future<bool> shouldPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_promptedKey) == true) return false;
    if (!_answers.isEmpty) return false;
    return (prefs.getInt(_storiesKey) ?? 0) >= storiesBeforePrompt;
  }

  Future<void> markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptedKey, true);
  }

  /// A finished walk counts as enough on its own.
  Future<void> noteTourFinished() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storiesKey, storiesBeforePrompt);
  }

  Future<void> noteStoryHeard() async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_storiesKey) ?? 0) + 1;
    await prefs.setInt(_storiesKey, n);
  }
}
