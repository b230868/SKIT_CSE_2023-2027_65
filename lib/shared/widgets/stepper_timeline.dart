import 'package:flutter/material.dart';

import '../../core/theme.dart';

enum StepStateStatus {
  completed,
  current,
  upcoming,
  rejected,
}

class TimelineStep {
  final String title;
  final String? subtitle;
  final IconData icon;
  final StepStateStatus status;

  const TimelineStep({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.status,
  });
}

/// A responsive, accessible stepper and timeline for internship lifecycle:
/// Applied > Approved > Documents > Progress > ITR > Certificate.
class StepperTimeline extends StatelessWidget {
  final List<TimelineStep> steps;
  final void Function(int index)? onStepTap;

  const StepperTimeline({
    super.key,
    required this.steps,
    this.onStepTap,
  });

  /// Factory helper to build the standard 6-step lifecycle based on application state.
  factory StepperTimeline.fromApplicationState({
    Key? key,
    required String status,
    required int documentCount,
    required int progressPercentage,
    bool hasItr = false,
    bool hasCertificate = false,
    void Function(int index)? onStepTap,
  }) {
    final normalized = status.toLowerCase().trim();
    final isRejected = normalized == 'rejected';
    final isApproved = normalized == 'approved' ||
        normalized == 'active' ||
        normalized == 'completed' ||
        normalized == 'in_progress';

    final steps = <TimelineStep>[
      // 1. Applied
      TimelineStep(
        title: 'Applied',
        subtitle: 'Submitted',
        icon: Icons.send_outlined,
        status: StepStateStatus.completed,
      ),
      // 2. Approved
      TimelineStep(
        title: 'Approved',
        subtitle: isRejected ? 'Rejected' : (isApproved ? 'Approved' : 'Under review'),
        icon: isRejected ? Icons.cancel_outlined : Icons.verified_outlined,
        status: isRejected
            ? StepStateStatus.rejected
            : (isApproved ? StepStateStatus.completed : StepStateStatus.current),
      ),
      // 3. Documents
      TimelineStep(
        title: 'Documents',
        subtitle: documentCount > 0 ? '$documentCount uploaded' : 'Pending',
        icon: Icons.file_present_outlined,
        status: isRejected
            ? StepStateStatus.upcoming
            : (documentCount > 0
                ? StepStateStatus.completed
                : (isApproved ? StepStateStatus.current : StepStateStatus.upcoming)),
      ),
      // 4. Progress
      TimelineStep(
        title: 'Progress',
        subtitle: progressPercentage > 0 ? '$progressPercentage% done' : 'Weekly logs',
        icon: Icons.trending_up,
        status: isRejected
            ? StepStateStatus.upcoming
            : (progressPercentage >= 100
                ? StepStateStatus.completed
                : (documentCount > 0 ? StepStateStatus.current : StepStateStatus.upcoming)),
      ),
      // 5. ITR
      TimelineStep(
        title: 'ITR',
        subtitle: hasItr ? 'Submitted' : 'Report',
        icon: Icons.assignment_outlined,
        status: isRejected
            ? StepStateStatus.upcoming
            : (hasItr
                ? StepStateStatus.completed
                : (progressPercentage >= 60 ? StepStateStatus.current : StepStateStatus.upcoming)),
      ),
      // 6. Certificate
      TimelineStep(
        title: 'Certificate',
        subtitle: hasCertificate ? 'Issued' : 'Final',
        icon: Icons.workspace_premium_outlined,
        status: hasCertificate
            ? StepStateStatus.completed
            : (hasItr ? StepStateStatus.current : StepStateStatus.upcoming),
      ),
    ];

    return StepperTimeline(
      key: key,
      steps: steps,
      onStepTap: onStepTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(steps.length, (i) {
          final s = steps[i];
          final isLast = i == steps.length - 1;

          final (color, bgColor, borderColor) = switch (s.status) {
            StepStateStatus.completed => (
                Colors.green.shade700,
                isDark ? Colors.green.shade900.withValues(alpha: 0.3) : const Color(0xFFE8F5E9),
                Colors.green.shade600
              ),
            StepStateStatus.current => (
                AppTheme.saffron,
                isDark ? Colors.amber.shade900.withValues(alpha: 0.3) : const Color(0xFFFFFBEB),
                AppTheme.saffron
              ),
            StepStateStatus.rejected => (
                Colors.red.shade700,
                isDark ? Colors.red.shade900.withValues(alpha: 0.3) : const Color(0xFFFFEBEE),
                Colors.red.shade600
              ),
            StepStateStatus.upcoming => (
                isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                isDark ? Colors.grey.shade700 : Colors.grey.shade300
              ),
          };

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: '${s.title}: ${s.status.name}',
                button: onStepTap != null,
                child: InkWell(
                  onTap: onStepTap != null ? () => onStepTap!(i) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: borderColor,
                              width: s.status == StepStateStatus.current ? 2.0 : 1.2,
                            ),
                          ),
                          child: Icon(
                            s.status == StepStateStatus.completed ? Icons.check : s.icon,
                            size: 20,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: s.status == StepStateStatus.current
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.ink,
                          ),
                        ),
                        if (s.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            s.subtitle!,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 32,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 22, left: 4, right: 4),
                  color: s.status == StepStateStatus.completed
                      ? Colors.green.shade400
                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                ),
            ],
          );
        }),
      ),
    );
  }
}
