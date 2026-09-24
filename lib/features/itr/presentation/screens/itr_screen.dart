import 'package:flutter/material.dart';

import '../../data/models/itr_model.dart';
import '../../data/repositories/itr_repository_provider.dart';
import '../../data/services/itr_service.dart';
import 'itr_details_screen.dart';

class ItrListScreen extends StatefulWidget {
  const ItrListScreen({super.key});

  @override
  State<ItrListScreen> createState() => _ItrListScreenState();
}

class _ItrListScreenState extends State<ItrListScreen> {
  late final ItrService _itrService;
  late Future<List<ItrModel>> _itrFuture;

  @override
  void initState() {
    super.initState();

    _itrService = ItrService(itrRepository);
    _itrFuture = _itrService.getItrs();
  }

  Future<void> _refreshItrs() async {
    setState(() {
      _itrFuture = _itrService.getItrs();
    });

    await _itrFuture;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.blue;

      case 'under_review':
        return Colors.orange;

      case 'approved':
      case 'verified':
        return Colors.green;

      case 'changes_requested':
        return Colors.deepOrange;

      case 'rejected':
        return Colors.red;

      case 'draft':
        return Colors.grey;

      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My ITRs')),
      body: FutureBuilder<List<ItrModel>>(
        future: _itrFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 55,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load ITRs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refreshItrs,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final itrList = snapshot.data ?? [];

          if (itrList.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshItrs,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Icon(Icons.description_outlined, size: 70),
                  SizedBox(height: 20),
                  Center(
                    child: Text(
                      'No ITRs available yet.',
                      style: TextStyle(fontSize: 17),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(child: Text('Your internship ITR will appear here.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshItrs,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: itrList.length,
              itemBuilder: (context, index) {
                final itr = itrList[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.description)),
                    title: Text(
                      itr.internshipTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(itr.companyName),
                        const SizedBox(height: 10),
                        Chip(
                          label: Text(
                            _formatStatus(itr.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          backgroundColor: _getStatusColor(itr.status),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItrDetailsScreen(
                            itr: itr,
                            itrService: _itrService,
                          ),
                        ),
                      );

                      if (result == true) {
                        await _refreshItrs();
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
