import 'package:flutter/material.dart';

import '../../services/app_state.dart';
import '../../services/notification_log.dart';
import '../../theme/dyk_theme.dart';

const _interestMeta = {
  'history': ('🏛️', 'History'),
  'funfact': ('💡', 'Fun Facts'),
  'headline': ('📰', 'Headlines'),
  'hotdeal': ('🔥', 'Hot Deals'),
};

class ExploreTab extends StatelessWidget {
  final AppState appState;
  final NotificationLog notificationLog;
  final VoidCallback onToggleExploring;

  const ExploreTab({
    super.key,
    required this.appState,
    required this.notificationLog,
    required this.onToggleExploring,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final exploring = appState.isExploring;
        final entries = notificationLog.entries;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Exploring toggle — yellow when active, dark when paused.
            SizedBox(
              height: 64,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      exploring ? DykColors.yellow : Colors.grey.shade800,
                  foregroundColor:
                      exploring ? DykColors.black : Colors.white,
                ),
                icon: Icon(exploring ? Icons.pause_circle : Icons.explore),
                label: Text(
                  exploring ? 'EXPLORING — TAP TO PAUSE' : 'START EXPLORING',
                  style: const TextStyle(fontSize: 16),
                ),
                onPressed: onToggleExploring,
              ),
            ),
            const SizedBox(height: 20),
            Text('Active interests',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final entry in _interestMeta.entries)
                  Expanded(
                    child: _InterestChip(
                      emoji: entry.value.$1,
                      label: entry.value.$2,
                      active: appState.interests.contains(entry.key),
                      onTap: () => appState.toggleInterest(entry.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Latest notifications',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white10
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'Nothing yet — start walking and your discoveries will show up here!',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final e in entries) _NotificationCard(entry: e),
          ],
        );
      },
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _InterestChip({
    required this.emoji,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: dark ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? DykColors.yellow : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                if (active)
                  const Positioned(
                    right: -8,
                    top: -4,
                    child: Icon(Icons.check_circle,
                        size: 14, color: DykColors.yellow),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final LoggedNotification entry;
  const _NotificationCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final categoryLabel = entry.type == 'deal'
        ? 'HOT DEAL'
        : (entry.category ?? 'history').toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade700,
                    )),
                const SizedBox(height: 2),
                Text(entry.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                Text(entry.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (entry.redeemCode != null && entry.redeemCode!.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: DykColors.yellow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DykColors.black, width: 1.5),
              ),
              child: Text('CODE\n${entry.redeemCode}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DykColors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  )),
            ),
        ],
      ),
    );
  }
}
