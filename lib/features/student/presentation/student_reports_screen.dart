import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme.dart';
import '../../../models/notification_models.dart';
import '../../../services/report_service.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/skeleton_loader.dart';

String _two(int v) => v.toString().padLeft(2, '0');

String _fmtDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${m[l.month - 1]} ${l.year}';
}

String _fmtTime(DateTime d) {
  final l = d.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

String _fileDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _signed(int v) => v > 0 ? '+$v' : '$v';

class StudentReportsScreen extends StatefulWidget {
  final Future<ReportSummary> Function({bool force})? loader;

  const StudentReportsScreen({super.key, this.loader});

  @override
  State<StudentReportsScreen> createState() => _StudentReportsScreenState();
}

class _StudentReportsScreenState extends State<StudentReportsScreen> {
  late final ReportService _service = ReportService();

  Future<ReportSummary> _load({bool force = false}) {
    final custom = widget.loader;
    return custom != null ? custom(force: force) : _service.studentSummary(force: force);
  }

  late Future<ReportSummary> _future = _load();
  bool _exporting = false;
  int _window = 0; // 0 = all weeks, 8 = last 8, 4 = last 4

  Future<void> _refresh() async {
    setState(() {
      _future = _load(force: true);
    });
    await _future.then((_) {}, onError: (_) {});
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copySummary(ReportSummary r) async {
    final b = StringBuffer()
      ..writeln('Prashikshan Report - ${r.studentName ?? 'Student'}')
      ..writeln('Applications: ${r.totalApplications} (Approved: ${r.approved}, Pending: ${r.pending}, Rejected: ${r.rejected})')
      ..writeln('Latest progress: ${r.latestProgress}% over ${r.weeksLogged} week(s)')
      ..writeln('Documents uploaded: ${r.documentsUploaded}')
      ..writeln('Unread notifications: ${r.unreadNotifications}');
    await Clipboard.setData(ClipboardData(text: b.toString()));
    _toast('Summary copied to clipboard');
  }

  Future<void> _exportPdf(ReportSummary r) async {
    setState(() => _exporting = true);
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Prashikshan - Internship & Progress Report',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_fmtDate(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Student: ${r.studentName ?? 'Student'}'),
              pw.SizedBox(height: 8),
              pw.Text('Applications: ${r.totalApplications} (Approved: ${r.approved}, Pending: ${r.pending}, Rejected: ${r.rejected})'),
              pw.Text('Latest Progress: ${r.latestProgress}% across ${r.weeksLogged} week(s)'),
              pw.Text('Documents Uploaded: ${r.documentsUploaded}'),
              pw.SizedBox(height: 16),
              pw.Text('Weekly Progress History', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Week', 'Progress (%)', 'Date Recorded'],
                data: r.progressHistory
                    .map((p) => [
                          'Week ${p.weekNo}',
                          '${p.progress}%',
                          p.recordedAt != null ? _fmtDate(p.recordedAt!) : '-',
                        ])
                    .toList(),
              ),
            ],
          ),
        ),
      );

      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'prashikshan-report-${_fileDate(DateTime.now())}.pdf',
      );
    } catch (_) {
      _toast('Could not export PDF report.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Report & Analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<ReportSummary>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SkeletonLoader(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SkeletonBox(height: 100, borderRadius: 16),
                      SizedBox(height: 16),
                      SkeletonBox(height: 48, borderRadius: 12),
                      SizedBox(height: 16),
                      SkeletonBox(height: 220, borderRadius: 16),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return ErrorStateView(
                title: 'Could not load your report',
                message: 'Please verify your internet connection and pull down to retry.',
                onRetry: _refresh,
              );
            }

            final full = snapshot.data ?? ReportSummary.empty();

            if (full.totalApplications == 0 &&
                full.progressHistory.isEmpty &&
                full.documentsUploaded == 0) {
              return const EmptyStateView(
                icon: Icons.bar_chart_outlined,
                title: 'Nothing to report yet',
                description:
                    'Apply for an internship, upload your documents and log weekly progress to generate report analytics.',
              );
            }

            final r = full.lastWeeks(_window);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Top Header Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Performance Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.ink,
                      ),
                    ),
                    if (ReportService.lastFetchedAt != null)
                      Text(
                        'Synced ${_fmtTime(ReportService.lastFetchedAt!)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Application Status Proportional Bar
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${full.approvalRate.toStringAsFixed(0)}% of your applications were approved',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Row(
                            children: [
                              if (full.approved > 0)
                                Expanded(
                                  flex: full.approved,
                                  child: Container(height: 12, color: Colors.green),
                                ),
                              if (full.pending > 0)
                                Expanded(
                                  flex: full.pending,
                                  child: Container(height: 12, color: AppTheme.saffron),
                                ),
                              if (full.rejected > 0)
                                Expanded(
                                  flex: full.rejected,
                                  child: Container(height: 12, color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 16,
                          children: [
                            _Legend(Colors.green, 'Approved: ${full.approved}'),
                            _Legend(AppTheme.saffron, 'Pending: ${full.pending}'),
                            _Legend(Colors.red, 'Rejected: ${full.rejected}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Progress Analytics with Time-Window Filter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress Analytics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Time window segment selector
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('All Weeks')),
                      ButtonSegment(value: 8, label: Text('Last 8 Wks')),
                      ButtonSegment(value: 4, label: Text('Last 4 Wks')),
                    ],
                    selected: {_window},
                    onSelectionChanged: (s) => setState(() => _window = s.first),
                  ),
                ),
                const SizedBox(height: 14),

                // Interactive Progress Chart with Hover & Tap Tooltips
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.insights, size: 18, color: AppTheme.ink),
                            const SizedBox(width: 8),
                            const Text(
                              'Weekly Progress Trend',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const Spacer(),
                            Text(
                              'Tap/hover data points for details',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (r.progressHistory.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Center(child: Text('No weekly progress logs for this window.')),
                          )
                        else
                          _InteractiveProgressChart(points: r.progressHistory),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Key Insights Cards Grid
                _InsightsCard(r: r),
                const SizedBox(height: 24),

                // Export & Copy Actions
                FilledButton.icon(
                  onPressed: _exporting ? null : () => _exportPdf(full),
                  icon: _exporting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_exporting ? 'Generating PDF report...' : 'Export as PDF Report'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _copySummary(full),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy Report Summary'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;

  const _Legend(this.color, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final ReportSummary r;

  const _InsightsCard({required this.r});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wow = r.weekOverWeekGain;
    final best = r.bestWeek;
    final left = r.estimatedWeeksLeft;

    final items = [
      ('Latest progress', '${r.latestProgress}%', Icons.trending_up),
      ('Weeks logged', '${r.weeksLogged}', Icons.calendar_month_outlined),
      ('Weekly avg gain', '${r.averageWeeklyGain.toStringAsFixed(1)} pts', Icons.speed),
      ('Week-over-week', wow == null ? '-' : '${_signed(wow)} pts', Icons.compare_arrows),
      ('Best week', best == null ? '-' : 'Week $best', Icons.emoji_events_outlined),
      ('Est. to 100%', left == null ? '-' : (left == 0 ? 'Complete' : '$left wks'), Icons.flag_outlined),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Icon(items[i].$3, size: 18, color: AppTheme.ink),
                    const SizedBox(width: 10),
                    Text(items[i].$1, style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text(
                      items[i].$2,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

/// An interactive weekly progress chart responding to tap and hover with rich tooltips.
class _InteractiveProgressChart extends StatefulWidget {
  final List<ProgressPoint> points;

  const _InteractiveProgressChart({required this.points});

  @override
  State<_InteractiveProgressChart> createState() => _InteractiveProgressChartState();
}

class _InteractiveProgressChartState extends State<_InteractiveProgressChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final points = widget.points;

    return Column(
      children: [
        // Tooltip Banner when a point is hovered or tapped
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _hoveredIndex != null
                ? AppTheme.ink
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_hoveredIndex != null && _hoveredIndex! < points.length) ...[
                const Icon(Icons.touch_app, size: 14, color: AppTheme.saffron),
                const SizedBox(width: 8),
                Text(
                  'Week ${points[_hoveredIndex!].weekNo}: ${points[_hoveredIndex!].progress}% '
                  '${points[_hoveredIndex!].recordedAt != null ? "(${_fmtDate(points[_hoveredIndex!].recordedAt!)})" : ""}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap or hover any dot to view week, percentage & date',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Custom Canvas Chart with Touch & Hover Interaction
        SizedBox(
          height: 190,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const left = 36.0, right = 16.0;
              final w = constraints.maxWidth - left - right;

              var minWeek = points.first.weekNo, maxWeek = points.first.weekNo;
              for (final p in points) {
                if (p.weekNo < minWeek) minWeek = p.weekNo;
                if (p.weekNo > maxWeek) maxWeek = p.weekNo;
              }

              double xOf(int week) => maxWeek == minWeek
                  ? left + w / 2
                  : left + w * (week - minWeek) / (maxWeek - minWeek);

              void updateHover(Offset localPos) {
                int closest = 0;
                double minDist = double.infinity;
                for (int i = 0; i < points.length; i++) {
                  final px = xOf(points[i].weekNo);
                  final dist = (localPos.dx - px).abs();
                  if (dist < minDist) {
                    minDist = dist;
                    closest = i;
                  }
                }
                if (minDist < 40 && _hoveredIndex != closest) {
                  setState(() => _hoveredIndex = closest);
                }
              }

              return MouseRegion(
                onHover: (e) => updateHover(e.localPosition),
                onExit: (_) => setState(() => _hoveredIndex = null),
                child: GestureDetector(
                  onTapDown: (e) => updateHover(e.localPosition),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 190),
                    painter: _InteractiveTrendPainter(
                      points: points,
                      hoveredIndex: _hoveredIndex,
                      lineColor: isDark ? AppTheme.saffron : AppTheme.ink,
                      gridColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      textColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      highlightColor: AppTheme.saffron,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InteractiveTrendPainter extends CustomPainter {
  final List<ProgressPoint> points;
  final int? hoveredIndex;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final Color highlightColor;

  _InteractiveTrendPainter({
    required this.points,
    required this.hoveredIndex,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.highlightColor,
  });

  void _text(Canvas canvas, String s, Offset o, {bool bold = false, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 10,
          fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
          color: color ?? textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0, right = 16.0, top = 12.0, bottom = 28.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    // Grid lines for 0%, 50%, 100%
    for (final v in [0, 50, 100]) {
      final y = top + h * (1 - v / 100.0);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
      _text(canvas, '$v%', Offset(2, y - 6));
    }

    if (points.isEmpty) return;

    var minWeek = points.first.weekNo, maxWeek = points.first.weekNo;
    for (final p in points) {
      if (p.weekNo < minWeek) minWeek = p.weekNo;
      if (p.weekNo > maxWeek) maxWeek = p.weekNo;
    }

    double xOf(int week) => maxWeek == minWeek
        ? left + w / 2
        : left + w * (week - minWeek) / (maxWeek - minWeek);
    double yOf(int progress) => top + h * (1 - progress.clamp(0, 100) / 100.0);

    final offsets = [for (final p in points) Offset(xOf(p.weekNo), yOf(p.progress))];

    // Shaded gradient area under line
    final area = Path()..moveTo(offsets.first.dx, top + h);
    for (final o in offsets) {
      area.lineTo(o.dx, o.dy);
    }
    area
      ..lineTo(offsets.last.dx, top + h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.25),
            lineColor.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTRB(left, top, left + w, top + h)),
    );

    // Trend line
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.8,
    );

    // Dots and week labels
    final dotPaint = Paint()..color = lineColor;
    for (var i = 0; i < points.length; i++) {
      final isHovered = hoveredIndex == i;
      final o = offsets[i];

      if (isHovered) {
        // Vertical dashed guideline
        final guidePaint = Paint()
          ..color = highlightColor.withValues(alpha: 0.5)
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(o.dx, top), Offset(o.dx, top + h), guidePaint);

        // Highlight ring
        canvas.drawCircle(
          o,
          8,
          Paint()..color = highlightColor.withValues(alpha: 0.3),
        );
        canvas.drawCircle(
          o,
          5,
          Paint()..color = highlightColor,
        );
        _text(
          canvas,
          'W${points[i].weekNo}',
          Offset(o.dx - 8, top + h + 8),
          bold: true,
          color: highlightColor,
        );
      } else {
        canvas.drawCircle(o, 4, dotPaint);
        _text(canvas, 'W${points[i].weekNo}', Offset(o.dx - 8, top + h + 8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InteractiveTrendPainter old) =>
      old.hoveredIndex != hoveredIndex ||
      old.points != points ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor;
}
