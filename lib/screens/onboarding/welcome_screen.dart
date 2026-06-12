import 'package:flutter/material.dart';

import 'interests_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onFinished;
  final void Function(Set<String>)? onInterestsChosen;

  const WelcomeScreen(
      {super.key, required this.onFinished, this.onInterestsChosen});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/landing_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Image.asset(
                  'assets/images/dyk_logo.png',
                  height: 220,
                  fit: BoxFit.contain,
                ),
                const Spacer(flex: 2),
                const Text(
                  'Explore cities. Discover stories.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    text: 'Unlock ',
                    children: [
                      TextSpan(
                        text: 'hidden gems',
                        style: TextStyle(
                          color: Colors.amber.shade400,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.explore),
                    label: const Text('START EXPLORING',
                        style: TextStyle(fontSize: 17)),
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
