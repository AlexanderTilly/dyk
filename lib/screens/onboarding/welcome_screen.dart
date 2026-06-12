import 'package:flutter/material.dart';

import '../../theme/dyk_theme.dart';
import 'interests_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onFinished;
  final void Function(Set<String>)? onInterestsChosen;

  const WelcomeScreen({super.key, required this.onFinished, this.onInterestsChosen});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo placeholder until the PNG asset is added.
              Text(
                'Did You\nKnow?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 56,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: dark ? Colors.white : DykColors.black,
                  shadows: const [
                    Shadow(color: DykColors.yellow, offset: Offset(3, 3)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('💡', style: TextStyle(fontSize: 40)),
              const Spacer(flex: 2),
              Text(
                'Explore cities. Discover stories.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text.rich(
                TextSpan(
                  text: 'Unlock ',
                  children: [
                    TextSpan(
                      text: 'hidden gems',
                      style: TextStyle(
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.explore),
                  label: const Text('START EXPLORING'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InterestsScreen(
                            onFinished: onFinished,
                            onInterestsChosen: onInterestsChosen),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
