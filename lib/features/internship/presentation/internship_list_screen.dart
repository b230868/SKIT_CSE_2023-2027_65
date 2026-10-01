import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/internship_service.dart';
import '../models/internship.dart';
import 'internship_detail_screen.dart';
import 'internship_form_screen.dart';

class InternshipListScreen extends StatefulWidget {
  /// Called after anything changes so the dashboard can refresh.
  final VoidCallback? onChanged;
  const InternshipListScreen({super.key, this.onChanged});

  @override
  State<InternshipListScreen> createState() => _InternshipListScreenState();
}

class _InternshipListScreenState extends State<InternshipListScreen> {
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

  Future<void> _openForm() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InternshipFormScreen()),
    );
    await _reload();
    widget.onChanged?.call();
  }

  Future<void> _openDetail(Internship i) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => InternshipDetailScreen(internshipId: i.id)),
    );
    await _reload();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My internships')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Apply'),
      ),
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
                children: [
                  const SizedBox(height: 120),
                  const Center(child: Text('Could not load internships.')),
                  Center(
                    child: TextButton(
                        onPressed: _reload, child: const Text('Try again')),
                  ),
                ],
              );
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Center(child: Text('No applications yet')),
                  SizedBox(height: 6),
                  Center(child: Text('Tap Apply to add your first internship.')),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final i = items[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openDetail(i),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(i.title,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                              ),
                              StatusChip(status: i.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(i.companyName,
                              style: TextStyle(color: Colors.grey.shade700)),
                          const SizedBox(height: 4),
                          Text(
                              '${fmtDate(i.startDate)} to ${fmtDate(i.endDate)}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: i.progress / 100,
                                    minHeight: 6,
                                    backgroundColor: Colors.grey.shade200,
                                    color: AppTheme.saffron,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('${i.progress}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
