import 'package:flutter/material.dart';

import '../../services/notification_log.dart';
import '../../services/saved_store.dart';
import '../../theme/dyk_theme.dart';

class ProfileTab extends StatelessWidget {
  final SavedStore savedStore;
  final NotificationLog notificationLog;

  const ProfileTab({
    super.key,
    required this.savedStore,
    required this.notificationLog,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final visited = notificationLog.entries
        .where((e) => e.type == 'hotspot')
        .length;
    final savedCount = savedStore.savedIds.length;

    Widget statCard(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );

    Widget menuRow(IconData icon, String label, VoidCallback onTap) =>
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: dark ? Colors.white10 : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: Icon(icon, color: Colors.amber.shade700),
            title: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        );

    void comingSoon() {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Coming soon'),
          content: const Text('This feature is on its way!'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: savedStore,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: DykColors.yellow,
                  child: Text('🧭', style: TextStyle(fontSize: 36)),
                ),
                const SizedBox(height: 8),
                Text('Explorer',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                Text('"Collect moments, not things."',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: dark ? Colors.white10 : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                statCard('1', 'Cities\nExplored'),
                statCard('$visited', 'Hotspots\nVisited'),
                statCard('$savedCount', 'Saved\nItems'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Go Premium banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DykColors.yellow.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('👑', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Go Premium',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      Text(
                          'Unlock unlimited downloads, exclusive content and more perks.',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: comingSoon,
                  child: const Text('View Plans'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          menuRow(Icons.person_outline, 'Edit Profile', comingSoon),
          menuRow(Icons.settings_outlined, 'Settings', comingSoon),
          menuRow(Icons.help_outline, 'Help & Support', comingSoon),
          menuRow(Icons.info_outline, 'About Did You Know?', () {
            showAboutDialog(
              context: context,
              applicationName: 'Did You Know?',
              applicationVersion: '1.0.0-alpha',
              children: const [
                Text('Explore cities. Discover stories. Unlock hidden gems.'),
              ],
            );
          }),
        ],
      ),
    );
  }
}
