import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// An interactive, accessible stat card that animates numbers counting up from 0.
///
/// Features:
/// - Smooth [TweenAnimationBuilder] count-up.
/// - Touch & hover states with Material 3 styling.
/// - Minimum 48dp touch target and semantic accessibility.
/// - Respects [MediaQuery.disableAnimations] (reduced motion).
class AnimatedCountCard extends StatefulWidget {
  final String label;
  final int count;
  final IconData? icon;
  final Color? color;
  final bool highlight;
  final VoidCallback? onTap;
  final String? tooltip;
  final Duration duration;

  const AnimatedCountCard({
    super.key,
    required this.label,
    required this.count,
    this.icon,
    this.color,
    this.highlight = false,
    this.onTap,
    this.tooltip,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  State<AnimatedCountCard> createState() => _AnimatedCountCardState();
}

class _AnimatedCountCardState extends State<AnimatedCountCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final primaryColor = widget.color ?? (widget.highlight ? AppTheme.saffron : AppTheme.ink);
    final bgColor = widget.highlight
        ? (isDark ? const Color(0xFF1E293B) : AppTheme.ink)
        : (isDark ? const Color(0xFF1F2937) : Colors.white);
    final labelColor = widget.highlight
        ? (isDark ? Colors.white70 : Colors.white70)
        : (isDark ? Colors.grey.shade400 : Colors.grey.shade700);
    final numberColor = widget.highlight
        ? AppTheme.saffron
        : (widget.color ?? (isDark ? Colors.white : AppTheme.ink));

    final cardContent = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        offset: Offset(0, _hovered && widget.onTap != null ? -0.03 : 0.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered && widget.onTap != null
                ? primaryColor
                : (widget.highlight ? AppTheme.ink : (isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
            width: _hovered && widget.onTap != null ? 1.6 : 1.0,
          ),
          boxShadow: [
            if (_hovered && widget.onTap != null)
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88, minWidth: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 20, color: numberColor),
                      const SizedBox(height: 6),
                    ],
                    reduceMotion
                        ? Text(
                            '${widget.count}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: numberColor,
                              letterSpacing: -0.5,
                            ),
                          )
                        : TweenAnimationBuilder<double>(
                            key: ValueKey('count-${widget.count}'),
                            tween: Tween<double>(begin: 0, end: widget.count.toDouble()),
                            duration: widget.duration,
                            curve: Curves.easeOutCubic,
                            builder: (context, val, _) {
                              return Text(
                                '${val.round()}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: numberColor,
                                  letterSpacing: -0.5,
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 4),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

    return Semantics(
      label: '${widget.label}: ${widget.count}',
      button: widget.onTap != null,
      tooltip: widget.tooltip ?? widget.label,
      child: widget.tooltip != null
          ? Tooltip(message: widget.tooltip!, child: cardContent)
          : cardContent,
    );
  }
}
