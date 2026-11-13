/// The six optional interest questions, exactly as Jose specified them.
///
/// Answers are stored as option letters ("A".."D") against a question key,
/// never as the English text: the text is translated and may be reworded, and
/// a stored answer must keep meaning the same thing afterwards.
///
/// [questionVersion] travels with every saved answer set. Rewriting the
/// questions later changes it, so old answers are never silently read as
/// replies to questions nobody asked them.
const String questionVersion = '2026-11-13';

class ProfileQuestion {
  final String key;

  /// i18n key for the question text: `pq_<key>`.
  String get labelKey => 'pq_$key';

  /// Option letters in order. The i18n key for each is `pq_<key>_<letter>`.
  final List<String> options;

  /// Jose's spec: questions 1, 3, 4 and 5 take one answer; 2 and 6 take two.
  final int maxChoices;

  const ProfileQuestion(this.key, this.options, this.maxChoices);
}

const List<ProfileQuestion> profileQuestions = [
  ProfileQuestion('q1', ['A', 'B', 'C', 'D'], 1),
  ProfileQuestion('q2', ['A', 'B', 'C', 'D'], 2),
  ProfileQuestion('q3', ['A', 'B', 'C', 'D'], 1),
  ProfileQuestion('q4', ['A', 'B', 'C', 'D'], 1),
  ProfileQuestion('q5', ['A', 'B', 'C', 'D'], 1),
  ProfileQuestion('q6', ['A', 'B', 'C', 'D'], 2),
];

/// The version of the consent wording a person was shown.
///
/// Stored beside their yes or no, because "they consented" is not enough —
/// we have to be able to say which words they agreed to. Reword the consent
/// screen and this changes, and anyone who agreed to the old words is asked
/// again rather than carried over.
const String consentVersion = '2026-11-13';

/// What someone answered. Empty means they have not answered, which is a
/// different thing from having answered nothing.
class ProfileAnswers {
  /// question key → chosen option letters.
  final Map<String, List<String>> byQuestion;
  final String version;

  const ProfileAnswers(this.byQuestion, {this.version = questionVersion});

  static const empty = ProfileAnswers({});

  bool get isEmpty => byQuestion.isEmpty;

  List<String> of(String questionKey) => byQuestion[questionKey] ?? const [];

  /// True when this answer set came from a question list we no longer ask.
  /// Personalisation ignores those rather than guessing what they meant.
  bool get isStale => version != questionVersion;

  Map<String, dynamic> toJson() =>
      {'version': version, 'answers': byQuestion};

  factory ProfileAnswers.fromJson(Map<String, dynamic> json) {
    final raw = json['answers'];
    final out = <String, List<String>>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && v is List) {
          final letters = v.whereType<String>().toList();
          if (letters.isNotEmpty) out[k] = letters;
        }
      });
    }
    return ProfileAnswers(out,
        version: (json['version'] as String?) ?? questionVersion);
  }
}
