import 'package:flutter/material.dart';

class DashboardStatItem {
  final String title;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;

  const DashboardStatItem({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });
}
