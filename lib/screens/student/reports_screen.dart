import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/notification_models.dart';
import '../../services/report_service.dart';

const _docLabels = {
  'resume': 'Resume',
  'offer_letter': 'Offer letter',
  'noc': 'NOC',
  'certificate': 'Certificate',
  'other': 'Other',
};

const _notifLabels = {
  'application': 'Applications',
  'document': 'Documents',
  'progress': 'Progress',
  'general': 'General',
};

String _docLabel(String key) => _docLabels[key] ?? key;
String _notifLabel(String key) => _notifLabels[key] ?? key;

String _fmtDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${m[l.month - 1]} ${l.year}';
}

String _signed(int v) => v > 0 ? '+$v' : '$v';

/// Refined analytics: selectable time window, week-over-week change, best and
/// stalled weeks, notification statistics, a polished PDF with the student's
/// name and page numbers, and a quick "copy summary" action.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _service = ReportService();
  late Future<ReportSummary> _future = _service.studentSummary();
  bool _exporting = false;
  int _window = 0; // 0 = all weeks, otherwise the last N weeks

  Future<void> _refresh() async {
    setState(() => _future = _service.studentSummary(force: true));
    await _future.then((_) {}, onError: (_) {});
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- copy summary ----------------

  Future<void> _copySummary(ReportSummary r) async {
    final b = StringBuffer()
      ..writeln('Prashikshan report - ${r.studentName ?? 'Student'}')
      ..writeln('Applications: ${r.totalApplications} '
          '(approved ${r.approved}, pending ${r.pending}, rejected ${r.rejected})')
      ..writeln('Latest progress: ${r.latestProgress}% over ${r.weeksLogged} week(s)')
      ..writeln('Documents uploaded: ${r.documentsUploaded}')
      ..writeln('Unread notifications: ${r.unreadNotifications}');
    await Clipboard.setData(ClipboardData(text: b.toString()));
    _toast('Summary copied');
  }

  // ---------------- PDF ----------------

  pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(text,
            style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  pw.Widget _pdfTable(List<String> header, List<List<String>> rows) => pw.Table(
        border: pw.TableBorder.all(),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [for (final h in header) _cell(h, bold: true)],
          ),
          for (final r in rows) pw.TableRow(children: [for (final c in r) _cell(c)]),
        ],
      );

  Future<void> _exportPdf(ReportSummary r) async {
    setState(() => _exporting = true);
    try {
      final doc = pw.Document();
      final heading = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
      final gains = r.weeklyGains;
      doc.addPage(
        pw.MultiPage(
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 9)),
          ),
          build: (context) => [
            pw.Text('Prashikshan - Internship Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Student: ${r.studentName ?? 'Student'}'),
            pw.Text('Generated on ${_fmtDate(DateTime.now())}'),
            pw.SizedBox(height: 18),
            pw.Text('Application summary', style: heading),
            pw.SizedBox(height: 6),
            _pdfTable(
              ['Total', 'Approved', 'Pending', 'Rejected', 'Approval rate'],
              [
                [
                  '${r.totalApplications}',
                  '${r.approved}',
                  '${r.pending}',
                  '${r.rejected}',
                  '${r.approvalRate.toStringAsFixed(0)}%',
                ]
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text('Progress analytics', style: heading),
            pw.SizedBox(height: 6),
            pw.Text('Latest progress: ${r.latestProgress}%'),
            pw.Text('Weeks logged: ${r.weeksLogged}'),
            pw.Text('Average gain per week: ${r.averageWeeklyGain.toStringAsFixed(1)} points'),
            if (r.bestWeek != null) pw.Text('Best week: Week ${r.bestWeek}'),
            pw.Text('Weeks without progress: ${r.stalledWeeks}'),
            if (r.estimatedWeeksLeft != null)
              pw.Text('Estimated weeks to reach 100%: ${r.estimatedWeeksLeft}'),
            pw.SizedBox(height: 10),
            if (r.progressHistory.isEmpty)
              pw.Text('No weekly progress has been logged yet.')
            else
              _pdfTable(
                ['Week', 'Progress', 'Gain', 'Recorded on'],
                [
                  for (var i = 0; i < r.progressHistory.length; i++)
                    [
                      '${r.progressHistory[i].weekNo}',
                      '${r.progressHistory[i].progress}%',
                      _signed(gains[i]),
                      r.progressHistory[i].recordedAt == null
                          ? '-'
                          : _fmtDate(r.progressHistory[i].recordedAt!),
                    ]
                ],
              ),
            pw.SizedBox(height: 18),
            pw.Text('Documents (${r.documentsUploaded})', style: heading),
            pw.SizedBox(height: 6),
            if (r.documentsByType.isEmpty)
              pw.Text('No documents uploaded yet.')
            else
              _pdfTable(
                ['Type', 'Count'],
                [for (final e in r.documentsByType.entries) [_docLabel(e.key), '${e.value}']],
              ),
            pw.SizedBox(height: 18),
            pw.Text('Notifications', style: heading),
            pw.SizedBox(height: 6),
            pw.Text('Total: ${r.totalNotifications}, unread: ${r.unreadNotifications}'),
          ],
        ),
      );
      await Printing.sharePdf(bytes: await doc.save(), filename: 'prashikshan_report.pdf');
    } catch (_) {
      _toast('Could not generate the PDF. Try again.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My report')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<ReportSummary>(
          future: _future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) {
              return ListView(children: [
                const SizedBox(height: 160),
                const Center(child: Text('Could not load your report.')),
                Center(child: TextButton(onPressed: _refresh, child: const Text('Retry'))),
              ]);
            }
            return _content(s.data ?? ReportSummary.empty());
          },
        ),
      ),
    );
  }

  Widget _content(ReportSummary full) {
    final theme = Theme.of(context);
    final r = full.lastWeeks(_window);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Application summary', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(children: [
          _StatCard('Total', full.totalApplications, Icons.assignment_outlined),
          _StatCard('Approved', full.approved, Icons.check_circle_outline, color: Colors.green),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _StatCard('Pending', full.pending, Icons.hourglass_empty, color: Colors.orange),
          _StatCard('Rejected', full.rejected, Icons.cancel_outlined, color: Colors.red),
        ]),
        const SizedBox(height: 8),
        _StatusBar(full),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: Text('Progress analytics', style: theme.textTheme.titleMedium)),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('All')),
              ButtonSegment(value: 4, label: Text('Last 4 weeks')),
            ],
            selected: {_window},
            onSelectionChanged: (s) => setState(() => _window = s.first),
          ),
        ]),
        const SizedBox(height: 12),
        _Insights(r),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
            child: r.progressHistory.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No weekly progress logged yet.')),
                  )
                : SizedBox(
                    height: 190,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _TrendPainter(
                        points: r.progressHistory,
                        line: theme.colorScheme.primary,
                        grid: theme.colorScheme.outlineVariant,
                        textColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Documents (${full.documentsUploaded})', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _DocsByType(full),
        const SizedBox(height: 24),
        Text('Notifications', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _NotificationStats(full),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _exporting ? null : () => _exportPdf(full),
          icon: _exporting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_exporting ? 'Preparing PDF...' : 'Export as PDF'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _copySummary(full),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy summary'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color? color;
  const _StatCard(this.label, this.value, this.icon, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(icon, color: c),
            const SizedBox(height: 8),
            Text('$value', style: Theme.of(context).textTheme.headlineSmall),
            Text(label),
          ]),
        ),
      ),
    );
  }
}

/// Stacked bar showing approved / pending / rejected as proportions.
class _StatusBar extends StatelessWidget {
  final ReportSummary r;
  const _StatusBar(this.r);

  @override
  Widget build(BuildContext context) {
    if (r.totalApplications == 0) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('No applications yet. Apply from the Internships tab.'),
        ),
      );
    }
    final parts = <(int, Color)>[
      (r.approved, Colors.green),
      (r.pending, Colors.orange),
      (r.rejected, Colors.red),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(children: [
              for (final (n, c) in parts)
                if (n > 0) Expanded(flex: n, child: Container(height: 14, color: c)),
            ]),
          ),
          const SizedBox(height: 8),
          Text('${r.approvalRate.toStringAsFixed(0)}% of your applications were approved'),
        ]),
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  final ReportSummary r;
  const _Insights(this.r);

  @override
  Widget build(BuildContext context) {
    final days = r.daysSinceLastUpdate;
    final left = r.estimatedWeeksLeft;
    final wow = r.weekOverWeekGain;
    final best = r.bestWeek;
    final tiles = <(IconData, String, String)>[
      (Icons.trending_up, 'Latest progress', '${r.latestProgress}%'),
      (Icons.event_repeat, 'Weeks logged', '${r.weeksLogged}'),
      (Icons.speed, 'Average gain per week', '${r.averageWeeklyGain.toStringAsFixed(1)} pts'),
      (
        Icons.compare_arrows,
        'Change since previous week',
        wow == null ? 'Not enough data' : '${_signed(wow)} pts'
      ),
      (Icons.emoji_events_outlined, 'Best week', best == null ? '-' : 'Week $best'),
      (Icons.pause_circle_outline, 'Weeks without progress', '${r.stalledWeeks}'),
      (
        Icons.update,
        'Last update',
        days == null ? 'No updates yet' : (days == 0 ? 'Today' : '$days day(s) ago')
      ),
      (
        Icons.flag_outlined,
        'Estimated weeks to 100%',
        left == null ? 'Not enough data' : (left == 0 ? 'Completed' : '$left')
      ),
    ];
    return Card(
      child: Column(children: [
        for (var i = 0; i < tiles.length; i++) ...[
          ListTile(
            dense: true,
            leading: Icon(tiles[i].$1),
            title: Text(tiles[i].$2),
            trailing: Text(tiles[i].$3, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (i < tiles.length - 1) const Divider(height: 1),
        ],
      ]),
    );
  }
}

class _DocsByType extends StatelessWidget {
  final ReportSummary r;
  const _DocsByType(this.r);

  @override
  Widget build(BuildContext context) {
    if (r.documentsByType.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('No documents uploaded yet.'),
        ),
      );
    }
    var maxCount = 1;
    for (final v in r.documentsByType.values) {
      if (v > maxCount) maxCount = v;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          for (final e in r.documentsByType.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 100, child: Text(_docLabel(e.key))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: e.value / maxCount, minHeight: 10),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${e.value}'),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _NotificationStats extends StatelessWidget {
  final ReportSummary r;
  const _NotificationStats(this.r);

  @override
  Widget build(BuildContext context) {
    if (r.totalNotifications == 0) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.notifications_none),
          title: Text('No notifications yet.'),
        ),
      );
    }
    return Card(
      child: Column(children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.mark_email_unread_outlined),
          title: const Text('Unread'),
          trailing: Text('${r.unreadNotifications} of ${r.totalNotifications}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        for (final e in r.notificationsByType.entries) ...[
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.notifications_outlined),
            title: Text(_notifLabel(e.key)),
            trailing: Text('${e.value}'),
          ),
        ],
      ]),
    );
  }
}

/// Simple line chart of progress (0-100%) against week number.
class _TrendPainter extends CustomPainter {
  final List<ProgressPoint> points;
  final Color line, grid, textColor;
  const _TrendPainter({
    required this.points,
    required this.line,
    required this.grid,
    required this.textColor,
  });

  void _text(Canvas canvas, String s, Offset o) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: 10, color: textColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0, right = 8.0, top = 8.0, bottom = 24.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [0, 50, 100]) {
      final y = top + h * (1 - v / 100);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
      _text(canvas, '$v%', Offset(0, y - 6));
    }
    if (points.isEmpty) return;

    var minWeek = points.first.weekNo, maxWeek = points.first.weekNo;
    for (final p in points) {
      if (p.weekNo < minWeek) minWeek = p.weekNo;
      if (p.weekNo > maxWeek) maxWeek = p.weekNo;
    }
    double xOf(int week) =>
        maxWeek == minWeek ? left + w / 2 : left + w * (week - minWeek) / (maxWeek - minWeek);
    double yOf(int progress) => top + h * (1 - progress.clamp(0, 100) / 100);

    final offsets = [for (final p in points) Offset(xOf(p.weekNo), yOf(p.progress))];

    final area = Path()..moveTo(offsets.first.dx, top + h);
    for (final o in offsets) {
      area.lineTo(o.dx, o.dy);
    }
    area
      ..lineTo(offsets.last.dx, top + h)
      ..close();
    canvas.drawPath(area, Paint()..color = line.withValues(alpha: 0.12));

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final dot = Paint()..color = line;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(offsets[i], 4, dot);
      _text(canvas, 'W${points[i].weekNo}', Offset(offsets[i].dx - 8, top + h + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}
