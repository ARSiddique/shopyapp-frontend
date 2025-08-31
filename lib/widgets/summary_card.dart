import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? count;
  final String? value;
  final Color color;
  final VoidCallback? onTap; // ✅ NEW PARAM

  const SummaryCard({
    super.key,
    required this.icon,
    required this.title,
    this.count,
    this.value,
    required this.color,
    this.onTap, // ✅ NEW PARAM
  });

  @override
  Widget build(BuildContext context) {
    final String displayValue = count ?? value ?? '--';

    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: onTap, // ✅ MAKE CARD CLICKABLE
        borderRadius: BorderRadius.circular(12),
        child: Card(
          margin: const EdgeInsets.all(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    displayValue,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
