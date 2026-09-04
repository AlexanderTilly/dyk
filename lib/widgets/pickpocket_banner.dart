import 'package:flutter/material.dart';
import '../theme/dyk_theme.dart';

/// "See and report Pickpocket activity" call-to-action banner shown on the
/// Explore tab. Styled to match the DYK safety design (white card, blue
/// accents, pin icon). Tapping opens the report / see-all chooser.
class PickpocketBanner extends StatelessWidget {
  final VoidCallback onTap;

  /// A slimmer, more discreet variant (height ~ a single button) used at the
  /// bottom of the Explore tab.
  final bool compact;

  const PickpocketBanner({super.key, required this.onTap, this.compact = false});

  static const _blue = Color(0xFF1559D6);

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images/badges/pickpocket_mappin.png',
              height: 64,
              width: 64,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 52, color: const Color(0xFFE3E8F0)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See and report',
                    style: TextStyle(
                      color: PassimColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Pickpocket activity',
                    style: TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _blue, size: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3E8F0)),
        ),
        child: Row(
          children: [
            // Round pickpocket icon.
            Image.asset(
              'assets/images/badges/pickpocket.png',
              height: 38,
              width: 38,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text(
              'Pickpocket activity',
              style: TextStyle(
                color: _blue,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Text(
              'See or Report',
              style: TextStyle(
                color: Color(0xFF5B6573),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: _blue, size: 22),
          ],
        ),
      ),
    );
  }
}
