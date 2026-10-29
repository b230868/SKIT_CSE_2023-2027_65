import 'package:flutter/material.dart';
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

String _docLabel(String key) => _docLabels[key] ?? key;

String _fmtDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${m[l.month - 1]} ${l.year}';
}

/// Analytics integrated this week: status breakdown, weekly progress trend,
/// documents by type and derived insights. The PDF export carries the same data.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<ReportSummary> _future = ReportService().studentSummary();
  bool _exporting = false;

  Future<void> _refresh() async {
    setState(() => _future = ReportService().studentSummary());
    await _future.then((_) {}, onError: (_) {});
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
          pw.TableRow(children: [for (final h in header) _cell(h, bold: true)]),
          for (final r in rows) pw.TableRow(children: [for (final c in r) _cell(c)]),
        ],
      );

  Future<void> _exportPdf(ReportSummary r) async {
    setState(() => _exporting = true);
    try {
      final doc = pw.Document();
      final heading = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
      doc.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text('Prashikshan - Internship Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Generated ${_fmtDate(DateTime.now())}'),
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
            if (r.estimatedWeeksLeft != null)
              pw.Text('Estimated weeks to reach 100%: ${r.estimatedWeeksLeft}'),
            pw.SizedBox(height: 10),
            if (r.progressHistory.isEmpty)
              pw.Text('No weekly progress has been logged yet.')
            else
              _pdfTable(
                ['Week', 'Progress', 'Recorded on'],
                [
                  for (final p in r.progressHistory)
                    [
                      '${p.weekNo}',
                      '${p.progress}%',
                      p.recordedAt == null ? '-' : _fmtDate(p.recordedAt!),
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
          ],
        ),
      );
      await Printing.sharePdf(bytes: await doc.save(), filename: 'prashikshan_report.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not generate the PDF. Try again.')));
      }
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

  Widget _content(ReportSummary r) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Application summary', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(children: [
          _StatCard('Total', r.totalApplications, Icons.assignment_outlined),
          _StatCard('Approved', r.approved, Icons.check_circle_outline, color: Colors.green),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _StatCard('Pending', r.pending, Icons.hourglass_empty, color: Colors.orange),
          _StatCard('Rejected', r.rejected, Icons.cancel_outlined, color: Colors.red),
        ]),
        const SizedBox(height: 8),
        _StatusBar(r),
        const SizedBox(height: 24),
        Text('Insights', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _Insights(r),
        const SizedBox(height: 24),
        Text('Weekly progress', style: theme.textTheme.titleMedium),
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
        Text('Documents (${r.documentsUploaded})', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _DocsByType(r),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _exporting ? null : () => _exportPdf(r),
          icon: _exporting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_exporting ? 'Preparing PDF...' : 'Export as PDF'),
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
    final tiles = <(IconData, String, String)>[
      (Icons.trending_up, 'Latest progress', '${r.latestProgress}%'),
      (Icons.event_repeat, 'Weeks logged', '${r.weeksLogged}'),
      (Icons.speed, 'Average gain per week', '${r.averageWeeklyGain.toStringAsFixed(1)} pts'),
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
