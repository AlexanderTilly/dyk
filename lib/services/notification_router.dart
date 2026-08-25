import 'package:flutter/foundation.dart';

/// Bridges a tapped notification to the app's navigator. The notification
/// payload format is "hotspot:<id>" or "deal:<id>". The UI listens to
/// [pending] and routes to the right screen, then clears it.
class NotificationRouter {
  static final ValueNotifier<String?> pending = ValueNotifier<String?>(null);

  static void handlePayload(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      pending.value = payload;
    }
  }
}
