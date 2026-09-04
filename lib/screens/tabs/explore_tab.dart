import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/app_state.dart';
import '../../services/notification_log.dart';
import '../../services/notification_router.dart';
import '../../services/saved_store.dart';
import '../../theme/dyk_theme.dart';
import '../../widgets/category_badge.dart';
import '../notification_center_screen.dart';
import '../../i18n/i18n.dart';
import '../../utils/time_ago.dart';

const _interestMeta = {
  'history': ('🏛️', 'History'),
  'otium': ('🌿', 'Otium'),
  'headline': ('📖', 'Stories & Legends'),
  'hotdeal': ('🔥', 'Hot Deals'),
};

class ExploreTab extends StatefulWidget {
  final AppState appState;
  final NotificationLog notificationLog;
  final SavedStore savedStore;

  const ExploreTab({
    super.key,
    required this.appState,
    required this.notificationLog,
    required this.savedStore,
  });

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh the notification log (written by the background isolate)
    // on start, when the app resumes, and periodically while open.
    _refreshLog();
    _timer = Timer.periodic(
        const Duration(seconds: 8), (_) => _refreshLog());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshLog();
  }

  Future<void> _refreshLog() async {
    await widget.notificationLog.refresh();
    if (mounted) setState(() {});
  }

  // Swipe right → save the discovery to the Saved tab.
  Future<void> _saveEntry(LoggedNotification entry) async {
    if (entry.type == 'hotspot' && entry.targetId != null) {
      if (!widget.savedStore.isSaved(entry.targetId!)) {
        await widget.savedStore.toggle(entry.targetId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('saved_toast').replaceFirst('{title}', entry.title))),
        );
      }
    }
    // Also drop it from the live list so the swipe feels resolved.
    final idx = widget.notificationLog.entries
        .indexWhere((e) => e.targetId == entry.targetId && e.at == entry.at);
    if (idx >= 0) await widget.notificationLog.removeAt(idx);
    if (mounted) setState(() {});
  }

  // Swipe left → dismiss from the notification list.
  Future<void> _removeEntry(int index) async {
    await widget.notificationLog.removeAt(index);
    if (mounted) setState(() {});
  }


  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final notificationLog = widget.notificationLog;
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final entries = notificationLog.entries;
        // Only the three most recent discoveries; the rest live on the
        // Notifications page ("See all").
        final latest = entries.take(3).toList();
        return Column(
          children: [
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(tr('active_interests'),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in _interestMeta.entries)
                        Expanded(
                          child: _InterestChip(
                            categoryKey: entry.key,
                            label: tr('cat_${entry.key}'),
                            active: appState.interests.contains(entry.key),
                            onTap: () => appState.toggleInterest(entry.key),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(tr('latest_notifications'),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  if (latest.isNotEmpty)
                    Text(tr('swipe_hint'),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (latest.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          tr('nothing_yet'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < latest.length; i++)
                      _SwipeableNotification(
                        key: ValueKey(
                            '${latest[i].targetId}_${latest[i].at.toIso8601String()}'),
                        entry: latest[i],
                        onSave: () => _saveEntry(latest[i]),
                        onRemove: () => _removeEntry(i),
                      ),

                  // See all → full Notifications page.
                  if (entries.isNotEmpty)
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => NotificationCenterScreen(
                              notificationLog: widget.notificationLog,
                              savedStore: widget.savedStore,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                        child: Text('${tr('see_all')} (${entries.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800)),
                      ),
                    ),

                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String categoryKey;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _InterestChip({
    required this.categoryKey,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: active ? 1.0 : 0.45,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          active ? DykColors.yellow : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: CategoryBadge(category: categoryKey, size: 64),
                ),
                if (active)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: DykColors.yellow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, height: 1.1)),
          ],
        ),
      ),
    );
  }
}

class _SwipeableNotification extends StatelessWidget {
  final LoggedNotification entry;
  final VoidCallback onSave;
  final VoidCallback onRemove;

  const _SwipeableNotification({
    super.key,
    required this.entry,
    required this.onSave,
    required this.onRemove,
  });

  bool get _canSave => entry.type == 'hotspot' && entry.targetId != null;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      // Right swipe (save) only enabled for hotspots.
      direction: _canSave
          ? DismissDirection.horizontal
          : DismissDirection.endToStart,
      background: _SwipeBg(
        color: DykColors.yellow,
        icon: Icons.favorite,
        label: 'SAVE',
        alignment: Alignment.centerLeft,
        textColor: DykColors.black,
      ),
      secondaryBackground: const _SwipeBg(
        color: Colors.redAccent,
        icon: Icons.delete_outline,
        label: 'REMOVE',
        alignment: Alignment.centerRight,
        textColor: Colors.white,
      ),
      onDismissed: (dir) {
        if (dir == DismissDirection.startToEnd) {
          onSave();
        } else {
          onRemove();
        }
      },
      child: _NotificationCard(entry: entry),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;
  final Color textColor;

  const _SwipeBg({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13)),
        ],
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
    return GestureDetector(
      onTap: entry.payload == null
          ? null
          : () => NotificationRouter.handlePayload(entry.payload),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (entry.imageUrl != null && entry.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: entry.imageUrl!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                    width: 52, height: 52, color: Colors.black12),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(categoryLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: PassimColors.brand,
                          )),
                    ),
                    Text(timeAgo(entry.at),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
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
      ),
    );
  }
}
