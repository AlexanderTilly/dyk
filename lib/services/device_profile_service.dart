import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Captures device/install info and writes it to Supabase:
/// - app_installs: one anonymous row per device (guest tracking)
/// - profiles: device details for signed-in users
class DeviceProfileService {
  final SupabaseClient _client;
  DeviceProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // Each lookup is isolated so one failing plugin can't wipe the others.
  Future<Map<String, dynamic>> _collect() async {
    String platform = 'unknown';
    String model = 'unknown';
    String version = '';
    String country = '';

    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        platform = 'android';
        final a = await info.androidInfo;
        model = '${a.manufacturer} ${a.model}';
      } else if (Platform.isIOS) {
        platform = 'ios';
        final i = await info.iosInfo;
        model = i.utsname.machine;
      }
    } catch (_) {}

    try {
      final pkg = await PackageInfo.fromPlatform();
      version = pkg.version;
    } catch (_) {}

    try {
      country = PlatformDispatcher.instance.locale.countryCode ?? '';
    } catch (_) {}

    return {
      'platform': platform,
      'device_model': model,
      'app_version': version,
      'country': country,
    };
  }

  /// Anonymous install record — called on every launch. Best-effort.
  Future<void> recordInstall() async {
    String anonId;
    try {
      final prefs = await SharedPreferences.getInstance();
      anonId = prefs.getString('anon_install_id') ?? const Uuid().v4();
      await prefs.setString('anon_install_id', anonId);
    } catch (_) {
      anonId = const Uuid().v4();
    }

    final info = await _collect();
    try {
      // Use a security-definer RPC so the anonymous client can write its
      // install without RLS/select-back issues.
      await _client.rpc('record_install', params: {
        'p_anon_id': anonId,
        'p_platform': info['platform'],
        'p_device_model': info['device_model'],
        'p_app_version': info['app_version'],
        'p_country': info['country'],
        'p_became_user': _client.auth.currentUser != null,
      });
    } catch (e) {
      // ignore: avoid_print
      print('recordInstall failed: $e');
    }
  }

  /// Device details for the signed-in user's profile.
  Future<void> syncProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final info = await _collect();
      await _client.from('profiles').update({
        ...info,
        'registered_city': info['country'],
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('user_id', user.id);
    } catch (_) {}
  }

  /// Returns true if the signed-in user's account is paused.
  Future<bool> isPaused() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final row = await _client
          .from('profiles')
          .select('status')
          .eq('user_id', user.id)
          .maybeSingle();
      return row?['status'] == 'paused';
    } catch (_) {
      return false;
    }
  }
}
