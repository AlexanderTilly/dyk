import 'package:flutter/material.dart';
import '../../widgets/flag_icon.dart';

import '../../i18n/i18n.dart';
import '../../services/onboarding_music.dart';
import '../../widgets/dyk_page_route.dart';
import 'interests_screen.dart';
import '../../theme/dyk_theme.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final void Function(Set<String>)? onInterestsChosen;

  const WelcomeScreen(
      {super.key, required this.onFinished, this.onInterestsChosen});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    OnboardingMusic.start();
  }

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
                Text(
                  tr('welcome_line1'),
                  style: const TextStyle(
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
                          color: PassimColors.brand,
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
                // Pick your language before anything else — pre-selected to
                // the device language, changeable later in Settings.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final code in I18n.supported)
                      ChoiceChip(
                        selected: I18n.instance.code == code,
                        selectedColor: PassimColors.brand,
                        backgroundColor: Colors.black45,
                        labelStyle: TextStyle(
                          color: I18n.instance.code == code
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FlagIcon(code: code, width: 24),
                            const SizedBox(width: 7),
                            Text(I18n.names[code]!),
                          ],
                        ),
                        onSelected: (_) async {
                          await I18n.instance.setCode(code);
                          if (mounted) setState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tr('lang_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.explore),
                    label: Text(tr('start_exploring'),
                        style: const TextStyle(fontSize: 17)),
                    onPressed: () {
                      Navigator.of(context).push(
                        DykPageRoute(
                          page: InterestsScreen(
                              onFinished: widget.onFinished,
                              onInterestsChosen: widget.onInterestsChosen),
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
