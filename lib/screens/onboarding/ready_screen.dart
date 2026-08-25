import 'package:flutter/material.dart';
import '../../i18n/i18n.dart';

class ReadyScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const ReadyScreen({super.key, required this.onFinished});

  @override
  State<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends State<ReadyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScaleTransition(
                scale: CurvedAnimation(
                    parent: _controller, curve: Curves.elasticOut),
                child: const Text('🎉',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 72)),
              ),
              const SizedBox(height: 24),
              Text(tr('ob_all_set'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                "Start walking and we'll let you know when something interesting is nearby.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: widget.onFinished,
                child: const Text("LET'S GO"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
