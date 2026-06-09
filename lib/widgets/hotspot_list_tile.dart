import 'package:flutter/material.dart';
import '../models/hotspot.dart';

class HotspotListTile extends StatelessWidget {
  final Hotspot hotspot;
  final VoidCallback onTap;

  const HotspotListTile({
    super.key,
    required this.hotspot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withValues(alpha: 0.1),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: hotspot.images.isNotEmpty
                  ? Image.asset(
                      hotspot.images.first,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFFED7AA),
                        child: const Icon(Icons.place,
                            color: Color(0xFFF97316)),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFFFED7AA),
                      child: const Icon(Icons.place,
                          color: Color(0xFFF97316)),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotspot.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF431407),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hotspot.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF9A3412),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Color(0xFFF97316)),
            ),
          ],
        ),
      ),
    );
  }
}
