import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/status_chip.dart';
import '../auth/models/app_user.dart';
import '../internship/data/internship_service.dart';
import '../internship/models/internship.dart';
import '../internship/presentation/internship_detail_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onApply;

  const StudentDashboardScreen({
    super.key,
    required this.user,
    required this.onApply,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final _service = InternshipService();
  late Future<List<Internship>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchMine();
  }

  Future<void> _reload() async {
    final f = _service.fetchMine();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prashikshan')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Internship>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Center(child: Text('Could not load your internships.')),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                        onPressed: _reload, child: const Text('Try again')),
                  ),
                ],
              );
            }
            final items = snap.data ?? [];
            final pending = items.where((i) => i.status == 'pending').length;
            final approved = items
                .where((i) => i.status == 'approved' || i.status == 'completed')
                .length;
            final avg = items.isEmpty
                ? 0
                : (items.map((i) => i.progress).reduce((a, b) => a + b) /
                        items.length)
                    .round();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text('Hello, ${widget.user.firstName}',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink)),
                const SizedBox(height: 4),
                Text(
                  items.isEmpty
                      ? 'Apply for your first internship to start tracking it.'
                      : 'Here is where your internships stand.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _Stat(label: 'Applied', value: '${items.length}'),
                    const SizedBox(width: 10),
                    _Stat(label: 'Pending', value: '$pending'),
                    const SizedBox(width: 10),
                    _Stat(label: 'Approved', value: '$approved'),
                    const SizedBox(width: 10),
                    _Stat(label: 'Avg progress', value: '$avg%', highlight: true),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Recent internships',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                        onPressed: widget.onApply,
                        child: const Text('See all')),
                  ],
                ),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const Text('No internships yet'),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: widget.onApply,
                            child: const Text('Apply for an internship')),
                      ],
                    ),
                  )
                else
                  ...items.take(3).map(
                        (i) => Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: ListTile(
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    InternshipDetailScreen(internshipId: i.id),
                              ));
                              _reload();
                            },
                            title: Text(i.title,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${i.companyName} · ${fmtDate(i.startDate)}'),
                            trailing: StatusChip(status: i.status),
                          ),
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _Stat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight ? AppTheme.ink : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: highlight ? AppTheme.ink : Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: highlight ? AppTheme.saffron : AppTheme.ink)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: highlight ? Colors.white70 : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
