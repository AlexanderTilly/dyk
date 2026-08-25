import '../i18n/i18n.dart';

/// "just now" / "5 min ago" / "2 h ago" / "yesterday" / "3 Aug" — localized.
String timeAgo(DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return tr('ago_now');
  if (d.inMinutes < 60) return tr('ago_min').replaceFirst('{n}', '${d.inMinutes}');
  if (d.inHours < 24) return tr('ago_h').replaceFirst('{n}', '${d.inHours}');
  if (d.inHours < 48) return tr('ago_yesterday');
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${at.day} ${months[at.month - 1]}';
}
