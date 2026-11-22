import 'package:flutter/material.dart';

/// Pure Flutter skeleton shimmer effect for loading states.
/// Requires zero external dependencies.
class SkeletonLoader extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonLoader({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }

    final base = widget.baseColor ?? (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF374151) : const Color(0xFFF8FAFC));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-2.0 + val * 4.0, -0.3),
              end: Alignment(val * 4.0, 0.3),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A convenient rectangular skeleton box with rounded corners.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A loading placeholder for student dashboard cards.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SkeletonBox(width: 180, height: 28),
          const SizedBox(height: 8),
          const SkeletonBox(width: 260, height: 16),
          const SizedBox(height: 24),
          // Stat cards row
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 90, borderRadius: 16)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 90, borderRadius: 16)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 90, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 24),
          // Progress ring card
          const SkeletonBox(height: 120, borderRadius: 20),
          const SizedBox(height: 24),
          // Recent internships section
          const SkeletonBox(width: 160, height: 20),
          const SizedBox(height: 12),
          const SkeletonBox(height: 72, borderRadius: 12),
          const SizedBox(height: 10),
          const SkeletonBox(height: 72, borderRadius: 12),
          const SizedBox(height: 10),
          const SkeletonBox(height: 72, borderRadius: 12),
        ],
      ),
    );
  }
}
