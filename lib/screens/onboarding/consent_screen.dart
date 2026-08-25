import 'package:flutter/material.dart';
import '../../i18n/i18n.dart';

import '../../theme/dyk_theme.dart';
import '../../widgets/dyk_page_route.dart';
import 'location_screen.dart';

/// Terms + location-sharing consent. Must be accepted to continue.
class ConsentScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const ConsentScreen({super.key, required this.onFinished});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(tr('ob_before_start'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    tr('ob_consent_body'),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: dark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false),
                activeColor: DykColors.yellow,
                checkColor: DykColors.black,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  tr('ob_consent_agree'),
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _accepted
                      ? () {
                          Navigator.of(context).push(
                            DykPageRoute(
                              page:
                                  LocationScreen(onFinished: widget.onFinished),
                            ),
                          );
                        }
                      : null,
                  child: const Text('CONTINUE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
