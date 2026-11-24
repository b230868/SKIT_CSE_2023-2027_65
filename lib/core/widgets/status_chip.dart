import 'package:flutter/material.dart';

import '../config/role_config.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  Color get _color {
    final s = status.trim().toLowerCase();
    switch (s) {
      case 'approved':
      case 'verified':
      case 'success':
      case 'completed':
        return const Color(0xFF15803D);
      case 'rejected':
      case 'failed':
      case 'error':
        return const Color(0xFFDC2626);
      case 'active':
      case 'in_progress':
      case 'issued':
        return const Color(0xFF1D4ED8);
      case 'warning':
        return const Color(0xFFB45309);
      case 'pending':
      case 'submitted':
      default:
        return const Color(0xFFC2410C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = status.trim();
    final label = s.isEmpty
        ? 'Unknown'
        : s.replaceAll('_', ' ').split(' ').map((w) {
            return w.isEmpty
                ? ''
                : w[0].toUpperCase() + w.substring(1).toLowerCase();
          }).join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class RoleBadge extends StatelessWidget {
  final String role;
  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final color = RoleConfig.color(role);
    final label = RoleConfig.label(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
