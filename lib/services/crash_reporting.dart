import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Crash and error reporting.
///
/// Sentry rather than Crashlytics: one DSN and no per-platform config files,
/// so nothing extra has to be present for Codemagic to sign and ship iOS.
///
/// The DSN is supplied at build time and is absent by default, so a developer
/// build reports nothing and a release without the flag still runs — reporting
/// that silently disables itself is far better than a crash on launch because
/// a key was missing.
const String _dsn = String.fromEnvironment('SENTRY_DSN');

/// Whether reporting is actually switched on for this build.
bool get crashReportingEnabled => _dsn.isNotEmpty;

/// Boot the app with crash reporting around it.
///
/// [body] does everything `main` used to do, including `runApp`. Errors thrown
/// before the first frame are the ones hardest to reproduce, which is exactly
/// why the whole startup sits inside this and not just the widget tree.
Future<void> initCrashReporting(Future<void> Function() body) async {
  if (!crashReportingEnabled) {
    if (kDebugMode) {
      debugPrint('Crash reporting off (no SENTRY_DSN passed to this build).');
    }
    await body();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _dsn;
      options.environment = kReleaseMode ? 'production' : 'development';

      // This app follows people around a city. Nothing that could place a
      // named individual anywhere may leave the device:
      //
      // - sendDefaultPii off keeps IP addresses and usernames out.
      // - The breadcrumb hook drops anything carrying coordinates, because
      //   Flutter and our own logging both produce breadcrumbs that quote
      //   whatever they were handed, and a stray lat/lng in a crash report is
      //   a location leak no matter how well-intentioned the log line was.
      options.sendDefaultPii = false;
      options.beforeBreadcrumb = _dropLocationBreadcrumbs;

      // Crash reporting, not performance monitoring. Traces cost money and
      // answer a question nobody is asking yet.
      options.tracesSampleRate = 0.0;

      // A guide app spends long stretches in the background doing geofencing;
      // that is normal here and not worth an event every time.
      options.enableAppLifecycleBreadcrumbs = false;
    },
    appRunner: body,
  );
}

/// Drops breadcrumbs that look like they carry a position.
@visibleForTesting
Breadcrumb? dropLocationBreadcrumbs(Breadcrumb? crumb, Hint hint) =>
    _dropLocationBreadcrumbs(crumb, hint);

Breadcrumb? _dropLocationBreadcrumbs(Breadcrumb? crumb, Hint hint) {
  if (crumb == null) return null;

  bool looksLikeLocation(String? s) {
    if (s == null) return false;
    final l = s.toLowerCase();
    return l.contains('lat') ||
        l.contains('lng') ||
        l.contains('longitude') ||
        l.contains('latitude') ||
        l.contains('position(');
  }

  if (looksLikeLocation(crumb.message) || looksLikeLocation(crumb.category)) {
    return null;
  }
  if (crumb.data != null &&
      crumb.data!.keys.any((k) => looksLikeLocation(k))) {
    return null;
  }
  return crumb;
}
