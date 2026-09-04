import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/dyk_theme.dart';

/// Shown when a signed-in user's account has been paused by an admin.
class PausedScreen extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onSignedOut;

  const PausedScreen({
    super.key,
    required this.authService,
    required this.onSignedOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DykColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/images/passim_logo.png', height: 110),
              const SizedBox(height: 32),
              const Icon(Icons.pause_circle_outline,
                  size: 64, color: DykColors.yellow),
              const SizedBox(height: 20),
              const Text(
                'Your account is paused',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Access to Passim is temporarily on hold. '
                'If you think this is a mistake, please contact our support team.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.mail_outline),
                label: const Text('CONTACT SUPPORT'),
                onPressed: () {},
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'support@diduknow.app',
                  style: TextStyle(color: PassimColors.brand, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  await authService.signOut();
                  onSignedOut();
                },
                child: const Text('Sign out',
                    style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
