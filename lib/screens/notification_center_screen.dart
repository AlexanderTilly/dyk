import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../i18n/i18n.dart';

import '../services/notification_log.dart';
import '../utils/time_ago.dart';
import '../services/notification_router.dart';
import '../services/saved_store.dart';
import '../theme/dyk_theme.dart';

/// Full history of geofence notifications. Tap to open, swipe to remove,
/// or clear everything with "Rensa".
class NotificationCenterScreen extends StatefulWidget {
  final NotificationLog notificationLog;
  final SavedStore savedStore;

  const NotificationCenterScreen({
    super.key,
    required this.notificationLog,
    required this.savedStore,
  });

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keep the "x min ago" labels fresh while the page is open.
    _ticker = Timer.periodic(
        const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('clear_all_q')),
        content: Text(tr('clear_all_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('clear')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.notificationLog.clear();
      if (mounted) setState(() {});
    }
  }

  Future<void> _remove(int index) async {
    await widget.notificationLog.removeAt(index);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final entries = widget.notificationLog.entries;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('notifications'),
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (entries.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              label: Text(tr('clear'),
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/landing_background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Container(
          color: dark
              ? Colors.black.withValues(alpha: 0.72)
              : const Color(0xFFFAF6EE).withValues(alpha: 0.85),
          child: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  tr('nothing_yet'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                return Dismissible(
                  key: ValueKey('${e.targetId}_${e.at.toIso8601String()}_$i'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) => _remove(i),
                  child: _NotificationCard(entry: e, dark: dark),
                );
              },
            ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final LoggedNotification entry;
  final bool dark;
  const _NotificationCard({required this.entry, required this.dark});

  @override
  Widget build(BuildContext context) {
    final categoryLabel = entry.type == 'deal'
        ? 'HOT DEAL'
        : entry.type == 'city'
            ? 'NEW CITY'
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
                              color: Colors.amber.shade700,
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
