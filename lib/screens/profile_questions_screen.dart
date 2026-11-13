import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/profile_questions.dart';
import '../services/profile_store.dart';
import '../theme/dyk_theme.dart';

/// The optional interest questions: a welcome, six questions one per step, and
/// a consent step.
///
/// Everything here is skippable and nothing is recorded behind the person's
/// back:
///  * Skipping a question leaves it unanswered.
///  * Leaving part-way saves what was answered so far (if anything), and never
///    asks about offers: consent is only requested after the last question.
///  * The consent step records a yes or a no only when one of its two buttons
///    is pressed. Closing it any other way leaves consent null ("never
///    asked"), which is not the same as a no.
class ProfileQuestionsScreen extends StatefulWidget {
  final ProfileStore store;
  const ProfileQuestionsScreen({super.key, required this.store});

  @override
  State<ProfileQuestionsScreen> createState() => _ProfileQuestionsScreenState();
}

class _ProfileQuestionsScreenState extends State<ProfileQuestionsScreen> {
  /// -1 welcome, 0..n-1 questions, n consent.
  int _step = -1;
  final Map<String, List<String>> _chosen = {};
  bool _saved = false;

  int get _count => profileQuestions.length;
  bool get _onWelcome => _step < 0;
  bool get _onConsent => _step >= _count;

  Map<String, List<String>> get _answered => {
        for (final e in _chosen.entries)
          if (e.value.isNotEmpty) e.key: List.of(e.value)
      };

  void _toggle(ProfileQuestion q, String letter) {
    final cur = _chosen[q.key] ?? <String>[];
    setState(() {
      if (cur.contains(letter)) {
        cur.remove(letter);
      } else if (q.maxChoices == 1) {
        cur
          ..clear()
          ..add(letter);
      } else if (cur.length < q.maxChoices) {
        cur.add(letter);
      } // else: already at the limit, the extra tap does nothing
      _chosen[q.key] = cur;
    });
  }

  Future<void> _persist() async {
    if (_saved) return;
    final a = _answered;
    if (a.isEmpty) return; // never overwrite an earlier set with nothing
    _saved = true;
    await widget.store.save(ProfileAnswers(a));
  }

  Future<void> _advance() async {
    if (_step + 1 >= _count) {
      // Last question done. Save now, so closing the consent step still
      // keeps the answers. With nothing answered there is nothing to ask
      // consent for.
      await _persist();
      if (!mounted) return;
      if (_answered.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
    }
    setState(() => _step++);
  }

  Future<void> _close() async {
    if (!_onConsent) await _persist();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _consent(bool granted) async {
    await widget.store.setOffersConsent(granted);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: PassimColors.ink,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _onWelcome
                        ? _welcome()
                        : _onConsent
                            ? _consentStep()
                            : _question(profileQuestions[_step]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final showProgress = !_onWelcome && !_onConsent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('pq_close'),
            icon: const Icon(Icons.close, color: PassimColors.onPhoto),
            onPressed: _close,
          ),
          Expanded(
            child: showProgress
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      key: const Key('pq_progress'),
                      value: (_step + 1) / _count,
                      minHeight: 6,
                      color: PassimColors.brand,
                      backgroundColor: PassimColors.surface,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (showProgress) ...[
            const SizedBox(width: 12),
            Text('${_step + 1}/$_count',
                style: const TextStyle(
                    color: PassimColors.onPhoto, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }

  Widget _page({required List<Widget> children, required Widget footer}) =>
      Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              children: children,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: footer,
          ),
        ],
      );

  Widget _primary(String key, String label, VoidCallback? onPressed) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: Key(key),
          style: FilledButton.styleFrom(
            backgroundColor: PassimColors.brand,
            foregroundColor: PassimColors.ink,
            disabledBackgroundColor: PassimColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: onPressed,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ),
      );

  Widget _quiet(String key, String label, VoidCallback onPressed) =>
      SizedBox(
        width: double.infinity,
        child: TextButton(
          key: Key(key),
          style: TextButton.styleFrom(
            foregroundColor: PassimColors.onPhoto,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: onPressed,
          child: Text(label, style: const TextStyle(fontSize: 15)),
        ),
      );

  Widget _heading(String text) => Text(text,
      style: const TextStyle(
          color: PassimColors.onPhoto,
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w900));

  Widget _welcome() => _page(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.explore, color: PassimColors.brand, size: 48),
          const SizedBox(height: 20),
          _heading(tr('pq_welcome_title')),
          const SizedBox(height: 16),
          Text(tr('pq_welcome_line'),
              style: const TextStyle(
                  color: PassimColors.onPhoto, fontSize: 18, height: 1.4)),
          const SizedBox(height: 24),
          Text(tr('pq_welcome_privacy'),
              key: const Key('pq_welcome_privacy'),
              style: TextStyle(
                  color: PassimColors.onPhoto.withValues(alpha: 0.75),
                  fontSize: 14,
                  height: 1.45)),
        ],
        footer: Column(
          children: [
            _primary('pq_start', tr('pq_start'), () => setState(() => _step = 0)),
            _quiet('pq_not_now', tr('pq_not_now'), _close),
          ],
        ),
      );

  Widget _question(ProfileQuestion q) {
    final cur = _chosen[q.key] ?? const <String>[];
    final isLast = _step == _count - 1;
    return _page(
      children: [
        const SizedBox(height: 8),
        _heading(tr(q.labelKey)),
        const SizedBox(height: 6),
        Text(tr(q.maxChoices == 1 ? 'pq_hint_one' : 'pq_hint_two'),
            style: const TextStyle(color: PassimColors.brand, fontSize: 13)),
        const SizedBox(height: 18),
        for (final letter in q.options) _option(q, letter, cur.contains(letter)),
      ],
      footer: Column(
        children: [
          _primary('pq_next', tr(isLast ? 'pq_finish' : 'pq_next'),
              cur.isEmpty ? null : _advance),
          Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: _quiet('pq_back', tr('pq_back'),
                      () => setState(() => _step--)),
                ),
              Expanded(child: _quiet('pq_skip', tr('pq_skip'), () {
                // Skipping leaves this question unanswered.
                setState(() => _chosen.remove(q.key));
                _advance();
              })),
            ],
          ),
        ],
      ),
    );
  }

  Widget _option(ProfileQuestion q, String letter, bool selected) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: selected
              ? PassimColors.brand.withValues(alpha: 0.18)
              : PassimColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: selected ? PassimColors.brand : Colors.transparent,
                width: 2),
          ),
          child: InkWell(
            key: Key('pq_opt_${q.key}_$letter'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => _toggle(q, letter),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tr('pq_${q.key}_$letter'),
                        style: const TextStyle(
                            color: PassimColors.onPhoto,
                            fontSize: 16,
                            height: 1.3,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected
                        ? PassimColors.brand
                        : PassimColors.onPhoto.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _consentStep() => _page(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.local_offer_outlined,
              color: PassimColors.brand, size: 44),
          const SizedBox(height: 20),
          _heading(tr('pq_consent_title')),
          const SizedBox(height: 16),
          Text(tr('pq_consent_body'),
              key: const Key('pq_consent_body'),
              style: const TextStyle(
                  color: PassimColors.onPhoto, fontSize: 17, height: 1.45)),
        ],
        footer: Column(
          children: [
            _primary('pq_consent_yes', tr('pq_consent_yes'),
                () => _consent(true)),
            _quiet('pq_consent_no', tr('pq_consent_no'), () => _consent(false)),
          ],
        ),
      );
}
