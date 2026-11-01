import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../models/notification_models.dart';
import '../../../../models/report_insights.dart';

class ProgressAnalyticsScreen extends StatefulWidget {
  const ProgressAnalyticsScreen({super.key});

  @override
  State<ProgressAnalyticsScreen> createState() => _ProgressAnalyticsScreenState();
}

class _ProgressAnalyticsScreenState extends State<ProgressAnalyticsScreen> {
  static const _boxName = 'progress_analytics_cache';
  static const _cacheKey = 'student_analytics';

  ReportSummary? _full;
  bool _loading = true;
  bool _offline = false;
  String? _error;
  int _window = 0; // 0 = all weeks

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---- data ----

  Future<Box?> _box() async {
    try {
      return Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client.rpc('get_student_analytics');
      final map = Map<String, dynamic>.from(res as Map);
      final box = await _box();
      await box?.put(_cacheKey, jsonEncode(map));

      if (!mounted) return;
      setState(() {
        _full = ReportSummary.fromMap(map);
        _offline = false;
        _loading = false;
      });
    } catch (_) {
      final box = await _box();
      final raw = box?.get(_cacheKey) as String?;
      if (!mounted) return;
      setState(() {
        if (raw != null) {
          _full = ReportSummary.fromMap(
              Map<String, dynamic>.from(jsonDecode(raw) as Map));
          _offline = true;
        } else {
          _error = 'Could not load your report. Pull down to retry.';
        }
        _loading = false;
      });
    }
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress Analytics')),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _full == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final full = _full;
    if (full == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(child: Text(_error ?? 'No report data yet')),
          ],
        ),
      );
    }

    final s = _window == 0 ? full : full.lastWeeks(_window);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            s.studentName == null ? 'Your report' : 'Hi, ${s.studentName}',
            style: theme.textTheme.headlineSmall,
          ),
          if (_offline)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, size: 16),
                  const SizedBox(width: 6),
                  Text('Offline: showing saved data',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('All')),
              ButtonSegment(value: 8, label: Text('8 weeks')),
              ButtonSegment(value: 4, label: Text('4 weeks')),
            ],
            selected: {_window},
            onSelectionChanged: (v) => setState(() => _window = v.first),
          ),
          const SizedBox(height: 16),
          _progressCard(context, s),
          const SizedBox(height: 12),
          _trendCard(context, s),
          const SizedBox(height: 12),
          _sectionTitle(context, 'Applications'),
          _statsGrid([
            _Stat('Total', '${s.totalApplications}'),
            _Stat('Approved', '${s.approved}'),
            _Stat('Pending', '${s.pending}'),
            _Stat('Rejected', '${s.rejected}'),
            _Stat('Completed', '${s.completed}'),
            _Stat('Approval rate', '${s.approvalRate.toStringAsFixed(0)}%'),
          ]),
          const SizedBox(height: 12),
          _sectionTitle(context, 'Documents (${s.documentsUploaded})'),
          _chips(s.documentsByType, 'No documents uploaded yet'),
          const SizedBox(height: 12),
          _sectionTitle(
              context, 'Notifications (${s.totalNotifications}, ${s.unreadNotifications} unread)'),
          _chips(s.notificationsByType, 'No notifications yet'),
          const SizedBox(height: 12),
          _sectionTitle(context, 'Insights'),
          ..._insightCards(context, s),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _progressCard(BuildContext context, ReportSummary s) {
    final theme = Theme.of(context);
    final weeksLeft = s.estimatedWeeksLeft;
    final days = s.daysSinceLastUpdate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overall progress', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${s.latestProgress}%', style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (s.latestProgress.clamp(0, 100)) / 100,
              minHeight: 8,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _metric(context, 'Avg gain / week',
                    '${s.averageWeeklyGain.toStringAsFixed(1)} pts'),
                _metric(context, 'Stalled weeks', '${s.stalledWeeks}'),
                _metric(context, 'Weeks to 100%',
                    weeksLeft == null ? '-' : '$weeksLeft'),
                _metric(context, 'Last update',
                    days == null ? '-' : '$days d ago'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _trendCard(BuildContext context, ReportSummary s) {
    final theme = Theme.of(context);
    final history = s.progressHistory;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly trend', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Log progress to see your trend')),
              )
            else ...[
              SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter(
                    values: history.map((p) => p.progress).toList(),
                    lineColor: theme.colorScheme.primary,
                    gridColor: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Week ${history.first.weekNo}',
                      style: theme.textTheme.bodySmall),
                  Text('Week ${history.last.weekNo}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statsGrid(List<_Stat> stats) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.25,
      children: [
        for (final s in stats)
          Card(
            margin: EdgeInsets.zero,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.value,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(s.label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _chips(Map<String, int> data, String emptyText) {
    if (data.isEmpty) return Text(emptyText);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in data.entries) Chip(label: Text('${e.key}: ${e.value}')),
      ],
    );
  }

  List<Widget> _insightCards(BuildContext context, ReportSummary s) {
    final scheme = Theme.of(context).colorScheme;
    final insights = s.insights;
    if (insights.isEmpty) return [const Text('Nothing to flag right now')];

    return [
      for (final i in insights)
        Card(
          color: switch (i.severity) {
            InsightSeverity.warning => scheme.errorContainer,
            InsightSeverity.success => scheme.primaryContainer,
            InsightSeverity.info => scheme.secondaryContainer,
          },
          child: ListTile(
            leading: Icon(switch (i.severity) {
              InsightSeverity.warning => Icons.warning_amber_rounded,
              InsightSeverity.success => Icons.check_circle_outline,
              InsightSeverity.info => Icons.info_outline,
            }),
            title: Text(i.title),
            subtitle: Text(i.message),
          ),
        ),
    ];
  }
}

class _Stat {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  final List<int> values;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final v in [0, 50, 100]) {
      final y = size.height - size.height * v / 100;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = size.height - size.height * values[i].clamp(0, 100) / 100;
      points.add(Offset(x, y));
    }

    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = lineColor;
    for (final p in points) {
      canvas.drawCircle(p, 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}
