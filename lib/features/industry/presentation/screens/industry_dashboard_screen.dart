import 'package:flutter/material.dart';

import '../../data/models/industry_internship_model.dart';
import '../../data/services/industry_service.dart';
import 'internship_management_screen.dart';

class IndustryDashboardScreen extends StatefulWidget {
  const IndustryDashboardScreen({super.key});

  @override
  State<IndustryDashboardScreen> createState() =>
      _IndustryDashboardScreenState();
}

class _IndustryDashboardScreenState
    extends State<IndustryDashboardScreen> {
  final IndustryService _service = IndustryService();

  late Future<List<IndustryInternshipModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getIndustryInternships();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.getIndustryInternships();
    });

    await _future;
  }

  int _count(
    List<IndustryInternshipModel> data,
    bool Function(IndustryInternshipModel) test,
  ) {
    return data.where(test).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Industry Dashboard'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<IndustryInternshipModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load dashboard.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data ?? [];

          final active = _count(
            data,
            (item) => item.status == 'active',
          );

          final pendingItr = _count(
            data,
            (item) => [
              'draft',
              'submitted',
              'under_review',
            ].contains(item.itrStatus),
          );

          final pendingEvaluation = _count(
            data,
            (item) => [
              'pending',
              'in_progress',
            ].contains(item.evaluationStatus),
          );

          final completed = _count(
            data,
            (item) => item.status == 'completed',
          );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DashboardCard(
                        title: 'Active Interns',
                        value: active.toString(),
                        icon: Icons.people,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DashboardCard(
                        title: 'ITR Pending',
                        value: pendingItr.toString(),
                        icon: Icons.description,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _DashboardCard(
                        title: 'Evaluations Pending',
                        value:
                            pendingEvaluation.toString(),
                        icon:
                            Icons.assignment_turned_in,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DashboardCard(
                        title: 'Completed',
                        value: completed.toString(),
                        icon: Icons.check_circle,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  child: ListTile(
                    leading:
                        const Icon(Icons.business_center),
                    title: const Text(
                      'Manage Internships',
                    ),
                    subtitle: const Text(
                      'View assigned internship records',
                    ),
                    trailing:
                        const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const InternshipManagementScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.refresh),
                    title: const Text('Refresh Dashboard'),
                    trailing:
                        const Icon(Icons.refresh),
                    onTap: _refresh,
                  ),
                ),

                if (data.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'No internship data available.',
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 30),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}