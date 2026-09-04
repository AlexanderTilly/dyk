import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/device_profile_service.dart';
import '../theme/dyk_theme.dart';
import '../i18n/i18n.dart';

class AuthScreen extends StatefulWidget {
  final AuthService authService;
  const AuthScreen({super.key, required this.authService});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = true;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _gender; // 'female' | 'male' — picks the default avatar
  bool _loading = false;
  String? _error;
  String? _info;
  // Set after a successful sign-up that requires email confirmation —
  // swaps the whole form for a "check your inbox" view.
  bool _awaitingConfirm = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final error = _isSignUp
        ? await widget.authService.signUp(
            _email.text,
            _password.text,
            displayName: _name.text,
            gender: _gender,
          )
        : await widget.authService.signIn(_email.text, _password.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    // Signed up but no active session = email confirmation required.
    if (_isSignUp && !widget.authService.isSignedIn) {
      setState(() => _awaitingConfirm = true);
      return;
    }

    if (widget.authService.isSignedIn && mounted) {
      // Capture device info for the freshly signed-in user.
      await DeviceProfileService().syncProfile();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: dark ? Colors.white : DykColors.black,
      ),
      body: SafeArea(
        child: _awaitingConfirm
            ? _buildCheckInbox(context)
            : SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/images/passim_logo.png', height: 110),
              const SizedBox(height: 16),
              Text(
                _isSignUp ? tr('create_account_title') : tr('welcome_back'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                _isSignUp ? tr('auth_signup_sub') : tr('auth_signin_sub'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              if (_isSignUp) ...[
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: tr('name'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(tr('choose_avatar'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _AvatarChoice(
                        asset: 'assets/images/avatar_female.png',
                        label: 'Female',
                        selected: _gender == 'female',
                        onTap: () => setState(() => _gender = 'female'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AvatarChoice(
                        asset: 'assets/images/avatar_male.png',
                        label: 'Male',
                        selected: _gender == 'male',
                        onTap: () => setState(() => _gender = 'male'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: tr('email'),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: tr('password'),
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(_info!,
                    style: TextStyle(
                        color: DykColors.green, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : Text(_isSignUp ? tr('create_account_btn') : tr('sign_in_btn')),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() {
                  _isSignUp = !_isSignUp;
                  _error = null;
                  _info = null;
                }),
                child: Text(_isSignUp ? tr('have_account') : tr('new_here')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Full-screen confirmation view after sign-up: impossible to miss.
  Widget _buildCheckInbox(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: DykColors.yellow.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined,
                  size: 48, color: DykColors.yellow),
            ),
          ),
          const SizedBox(height: 20),
          Text(tr('check_inbox'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            '${tr('confirm_sent')}\n${_email.text.trim()}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            tr('confirm_hint'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => setState(() {
                _awaitingConfirm = false;
                _isSignUp = false; // jump straight to sign-in, email prefilled
                _password.clear();
                _error = null;
                _info = null;
              }),
              child: Text(tr('ive_confirmed')),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _awaitingConfirm = false),
            child: Text(tr('wrong_email')),
          ),
        ],
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarChoice({
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? DykColors.yellow.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? DykColors.yellow : Colors.black12,
            width: 2.5,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: DykColors.yellow,
              backgroundImage: AssetImage(asset),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? DykColors.black : null)),
          ],
        ),
      ),
    );
  }
}
