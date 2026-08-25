import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../services/step_store.dart';
import '../theme/dyk_theme.dart';

/// End-of-tour summary: steps, time and stops in a shareable-looking card.
class TourCompleteScreen extends StatelessWidget {
  final String tourTitle;
  final int? steps;
  final int? minutes;
  final int? stopsVisited;
  final int? stopsTotal;

  const TourCompleteScreen({
    super.key,
    required this.tourTitle,
    this.steps,
    this.minutes,
    this.stopsVisited,
    this.stopsTotal,
  });

  Widget _stat(IconData? icon, String value, String label,
      {bool feet = false}) {
    return Expanded(
      child: Column(
        children: [
          if (feet)
            const FootstepsIcon(size: 26)
          else
            Icon(icon, color: DykColors.yellow, size: 26),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mins = minutes ?? 0;
    final timeLabel =
        mins >= 90 ? '${(mins / 60).toStringAsFixed(1)} h' : '$mins min';
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 14),
              const Text('TOUR COMPLETE',
                  style: TextStyle(
                      color: DykColors.yellow,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(tourTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 26),
              // Summary card.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: DykColors.yellow.withValues(alpha: 0.5),
                      width: 1.5),
                ),
                child: Row(
                  children: [
                    if (steps != null && steps! > 100)
                      _stat(null, StepStore.fmt(steps!), tr('steps_unit'),
                          feet: true),
                    if (mins > 0)
                      _stat(Icons.schedule, timeLabel, tr('time_label')),
                    if (stopsVisited != null)
                      _stat(
                          Icons.place_outlined,
                          stopsTotal != null
                              ? '$stopsVisited/$stopsTotal'
                              : '$stopsVisited',
                          tr('stops').toLowerCase()),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: DykColors.yellow,
                      foregroundColor: DykColors.black),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('DONE',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
