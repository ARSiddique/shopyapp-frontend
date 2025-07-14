import 'package:flutter/material.dart';

class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            elevation: 4,
            shape: const CircleBorder(),
            color: isDark
                ? Colors.deepPurple.shade700.withAlpha(
                    51,
                  ) // Because 255 * 0.2 = 51

                : Colors.deepPurple.shade100,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Icon(
                icon,
                size: 28,
                color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
