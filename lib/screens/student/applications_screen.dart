import 'package:flutter/material.dart';
import '../../models/student_models.dart';
import '../../services/student_service.dart';
import 'application_detail_screen.dart';
import 'student_ui.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  late Future<List<Application>> _future = StudentService().myApplications();

  Future<void> _refresh() async {
    setState(() => _future = StudentService().myApplications());
    await _future.catchError((_) => <Application>[]);
  }

  static Widget _message(String text) => ListView(children: [
        const SizedBox(height: 160),
        Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center))),
      ]);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Application>>(
        future: _future,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return _message('Could not load applications. Pull down to retry.');
          final list = s.data!;
          if (list.isEmpty) return _message('No applications yet. Open the Internships tab and apply.');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final a = list[i];
              return Card(
                child: ListTile(
                  title: Text(a.internship.title),
                  subtitle: Text(
                    '${a.internship.companyName}\nApplied ${formatDate(a.appliedAt)}',
                  ),
                  isThreeLine: true,
                  trailing: statusChip(a.status),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ApplicationDetailScreen(application: a))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
