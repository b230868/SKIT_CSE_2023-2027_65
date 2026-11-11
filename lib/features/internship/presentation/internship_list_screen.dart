import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../screens/student/notification_screen.dart';
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
  String _selectedFilter = 'all'; // 'all' | 'pending' | 'approved' | 'rejected'

  @override
  void initState() {
    super.initState();
    _future = _service.fetchMine();
  }

  Future<void> _reload() async {
    final f = _service.fetchMine();
    setState(() {
      _future = f;
    });
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

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text('$label ($count)'),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 12,
      ),
      selectedColor: AppTheme.ink,
      checkmarkColor: Colors.white,
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Internships'),
        actions: const [
          NotificationBell(),
        ],
      ),
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
            final allItems = snap.data ?? [];
            if (allItems.isEmpty) {
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

            final pendingCount = allItems.where((i) => i.status == 'pending').length;
            final approvedCount = allItems.where((i) => i.status == 'approved' || i.status == 'completed').length;
            final rejectedCount = allItems.where((i) => i.status == 'rejected').length;

            final items = allItems.where((i) {
              if (_selectedFilter == 'pending') return i.status == 'pending';
              if (_selectedFilter == 'approved') return i.status == 'approved' || i.status == 'completed';
              if (_selectedFilter == 'rejected') return i.status == 'rejected';
              return true;
            }).toList();

            return Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterChip('All Applied', 'all', allItems.length),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending Faculty Approval', 'pending', pendingCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved', 'approved', approvedCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rejected', 'rejected', rejectedCount),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                _selectedFilter == 'pending'
                                    ? 'No pending applications waiting for faculty approval.'
                                    : 'No internships match this filter.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final i = items[index];
                            final isPending = i.status == 'pending';
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isPending ? Colors.orange.shade300 : Colors.grey.shade300,
                                  width: isPending ? 1.5 : 1,
                                ),
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
                                      if (isPending) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.hourglass_top, size: 14, color: Colors.orange.shade800),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Pending faculty approval',
                                                style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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
