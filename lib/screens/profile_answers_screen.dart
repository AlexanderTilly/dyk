import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/profile_questions.dart';
import '../services/profile_store.dart';
import '../theme/dyk_theme.dart';
import 'profile_questions_screen.dart';

/// Review, retake and delete the interest answers, and change the offers
/// choice. The privacy text promises all of it lives here.
class ProfileAnswersScreen extends StatefulWidget {
  final ProfileStore store;
  const ProfileAnswersScreen({super.key, required this.store});

  @override
  State<ProfileAnswersScreen> createState() => _ProfileAnswersScreenState();
}

class _ProfileAnswersScreenState extends State<ProfileAnswersScreen> {
  bool _deleting = false;

  Future<void> _retake() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfileQuestionsScreen(store: widget.store)));

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(tr('pq_delete_confirm')),
        actions: [
          TextButton(
              key: const Key('pq_delete_cancel'),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          TextButton(
              key: const Key('pq_delete_confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    bool removed;
    try {
      removed = await widget.store.deleteEverything();
    } catch (_) {
      removed = false;
    }
    if (!mounted) return;
    setState(() => _deleting = false);
    // Say plainly which it was. A failure must not look like success.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: Key(removed ? 'pq_deleted_ok' : 'pq_deleted_failed'),
      duration: Duration(seconds: removed ? 4 : 8),
      content: Text(tr(removed ? 'pq_deleted' : 'pq_delete_failed')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('pq_profile_entry'),
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final answers = widget.store.answers;
          final shown = answers.isEmpty || answers.isStale
              ? const <ProfileQuestion>[]
              : [
                  for (final q in profileQuestions)
                    if (answers.of(q.key).isNotEmpty) q
                ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(tr('pq_review_empty'),
                      key: const Key('pq_review_empty'),
                      textAlign: TextAlign.center),
                ),
              for (final q in shown)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: dark ? PassimColors.surface : PassimColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(q.labelKey),
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      for (final letter in answers.of(q.key))
                        Text(tr('pq_${q.key}_$letter'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Material(
                color: dark ? PassimColors.surface : PassimColors.card,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  key: const Key('pq_offers_switch'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(tr('pq_consent_title'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  value: widget.store.personalisedOffers,
                  activeThumbColor: PassimColors.brand,
                  onChanged: (v) => widget.store.setOffersConsent(v),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('pq_retake'),
                style: FilledButton.styleFrom(
                  backgroundColor: PassimColors.brand,
                  foregroundColor: PassimColors.ink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _retake,
                child: Text(
                    tr(answers.isEmpty ? 'pq_answer_now' : 'pq_retake'),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('pq_delete'),
                onPressed: _deleting ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(tr('pq_delete')),
              ),
            ],
          );
        },
      ),
    );
  }
}
