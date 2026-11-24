import 'package:flutter/material.dart';

import '../theme.dart';

class KpiMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final String? badge;
  final bool highlight;
  final VoidCallback? onTap;

  const KpiMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.color,
    this.badge,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? (highlight ? AppTheme.saffron : AppTheme.ink);
    final isCompact = subtitle == null && icon == null;

    return Card(
      color: highlight ? AppTheme.ink : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 16,
            vertical: isCompact ? 12 : 16,
          ),
          child: Column(
            crossAxisAlignment: isCompact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null || badge != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (icon != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: themeColor, size: 20),
                      )
                    else
                      const SizedBox.shrink(),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(
                value,
                textAlign: isCompact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: isCompact ? 20 : 24,
                  fontWeight: FontWeight.w800,
                  color: highlight ? AppTheme.saffron : AppTheme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                textAlign: isCompact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: isCompact ? 11 : 14,
                  fontWeight: isCompact ? FontWeight.w500 : FontWeight.w600,
                  color: highlight ? Colors.white70 : AppTheme.ink,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.slateMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
