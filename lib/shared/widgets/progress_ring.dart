import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// An interactive radial progress card showing internship completion percentage.
///
/// Features:
/// - Custom animated circular painter with gradient stroke.
/// - Center percentage label + contextual status message.
/// - Tap to view reports.
/// - Optional "Log this week's progress" action button for approved internships.
class ProgressRingCard extends StatefulWidget {
  final int progress; // 0 to 100
  final String? companyName;
  final String? roleTitle;
  final int? weeksLogged;
  final bool isApproved;
  final VoidCallback? onTap;
  final VoidCallback? onLogProgress;

  const ProgressRingCard({
    super.key,
    required this.progress,
    this.companyName,
    this.roleTitle,
    this.weeksLogged,
    this.isApproved = false,
    this.onTap,
    this.onLogProgress,
  });

  @override
  State<ProgressRingCard> createState() => _ProgressRingCardState();
}

class _ProgressRingCardState extends State<ProgressRingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final clamped = widget.progress.clamp(0, 100);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final cardBg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return Semantics(
      label: 'Internship progress: $clamped percent complete.',
      button: widget.onTap != null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered && widget.onTap != null ? AppTheme.ink : borderColor,
              width: _hovered && widget.onTap != null ? 1.6 : 1.0,
            ),
            boxShadow: [
              if (_hovered && widget.onTap != null)
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Progress Radial Ring
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              reduceMotion
                                  ? CustomPaint(
                                      size: const Size(84, 84),
                                      painter: _RingPainter(
                                        progress: clamped / 100.0,
                                        trackColor: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
                                        progressColor: clamped >= 100
                                            ? Colors.green
                                            : (clamped > 0 ? AppTheme.saffron : AppTheme.ink),
                                      ),
                                    )
                                  : TweenAnimationBuilder<double>(
                                      key: ValueKey('ring-$clamped'),
                                      tween: Tween<double>(begin: 0, end: clamped / 100.0),
                                      duration: const Duration(milliseconds: 900),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, val, _) {
                                        return CustomPaint(
                                          size: const Size(84, 84),
                                          painter: _RingPainter(
                                            progress: val,
                                            trackColor: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
                                            progressColor: val >= 1.0
                                                ? Colors.green
                                                : (val > 0 ? AppTheme.saffron : AppTheme.ink),
                                          ),
                                        );
                                      },
                                    ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$clamped%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppTheme.ink,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    'Done',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        // Context details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: widget.isApproved
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : AppTheme.saffron.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.isApproved ? 'Active Internship' : 'Overall Progress',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: widget.isApproved ? Colors.green.shade800 : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.companyName ?? 'Internship Journey',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppTheme.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.roleTitle ??
                                    (widget.weeksLogged != null
                                        ? '${widget.weeksLogged} week(s) logged'
                                        : 'Tap to view full report & analytics'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.isApproved && widget.onLogProgress != null) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: widget.onLogProgress,
                          icon: const Icon(Icons.edit_calendar, size: 16),
                          label: const Text("Log this week's progress"),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.ink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}
