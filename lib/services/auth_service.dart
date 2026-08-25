import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase Auth for the app. Email + password for now;
/// social logins can be added later.
class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Returns null on success, or an error message to show the user.
  Future<String?> signUp(String email, String password,
      {String? displayName, String? gender}) async {
    try {
      final data = <String, dynamic>{};
      if (displayName != null && displayName.trim().isNotEmpty) {
        data['display_name'] = displayName.trim();
      }
      if (gender != null && gender.isNotEmpty) {
        data['gender'] = gender;
      }
      await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: 'https://diduknow.app/',
        data: data.isEmpty ? null : data,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Returns null on success, or an error message.
  Future<String?> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Update display name and/or avatar gender. Returns null on success.
  Future<String?> updateProfile({String? displayName, String? gender}) async {
    try {
      final data = <String, dynamic>{};
      if (displayName != null) data['display_name'] = displayName.trim();
      if (gender != null) data['gender'] = gender;
      if (data.isEmpty) return null;
      await _client.auth.updateUser(UserAttributes(data: data));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Permanently delete the signed-in account and all its data.
  /// Returns null on success, or an error message.
  Future<String?> deleteAccount() async {
    try {
      await _client.rpc('delete_account');
      await _client.auth.signOut();
      return null;
    } catch (_) {
      return 'Could not delete the account. Please try again.';
    }
  }

  String get displayLabel {
    final u = currentUser;
    if (u == null) return 'Guest';
    final name = u.userMetadata?['display_name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    return u.email ?? 'Explorer';
  }

  /// Default avatar asset based on the gender chosen at sign-up. Falls back to
  /// the male explorer when unknown (e.g. guests or older accounts).
  String get avatarAsset {
    final g = currentUser?.userMetadata?['gender'] as String?;
    if (g == 'female') return 'assets/images/avatar_female.png';
    return 'assets/images/avatar_male.png';
  }
}
