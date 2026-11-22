import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../models/student_models.dart';
import '../../../services/document_progress_service.dart';
import '../../../services/student_service.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import 'student_application_detail_screen.dart';

class StudentApplicationsScreen extends StatefulWidget {
  final StudentDataSource? service;
  final DocumentProgressDataSource? documentService;
  final String initialFilter;
  final VoidCallback? onBrowseInternships;

  const StudentApplicationsScreen({
    super.key,
    this.service,
    this.documentService,
    this.initialFilter = 'all',
    this.onBrowseInternships,
  });

  @override
  State<StudentApplicationsScreen> createState() => _StudentApplicationsScreenState();
}

class _StudentApplicationsScreenState extends State<StudentApplicationsScreen> {
  late final StudentDataSource _service;
  late Future<List<Application>> _future;

  late String _selectedFilter;
  String _searchQuery = '';
  String _sortBy = 'newest'; // 'newest' | 'company' | 'status'
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter.toLowerCase().trim();
    _service = widget.service ?? StudentService();
    _future = _service.myApplications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.myApplications();
    });
    await _future.catchError((_) => <Application>[]);
  }

  void _showItemOptions(Application a) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.ink,
                  child: const Icon(Icons.work, color: Colors.white, size: 20),
                ),
                title: Text(
                  a.internship.companyName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(a.internship.title),
                trailing: StatusChip(status: a.status),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('View Full Details & Lifecycle'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openDetail(a);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_present_outlined),
                title: const Text('Manage Documents'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openDetail(a, tabIndex: 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timeline),
                title: const Text('View / Log Progress'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openDetail(a, tabIndex: 2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(Application a, {int tabIndex = 0}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            StudentApplicationDetailScreen(
          application: a,
          service: widget.documentService,
          initialTabIndex: tabIndex,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) => _refresh());
  }

  List<Application> _filterAndSort(List<Application> list) {
    var result = list;

    // Status filter
    if (_selectedFilter != 'all') {
      result = result
          .where((a) => a.status.toLowerCase().trim() == _selectedFilter)
          .toList();
    }

    // Search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      result = result.where((a) {
        final title = a.internship.title.toLowerCase();
        final company = a.internship.companyName.toLowerCase();
        return title.contains(q) || company.contains(q);
      }).toList();
    }

    // Sort
    result.sort((a, b) {
      switch (_sortBy) {
        case 'company':
          return a.internship.companyName
              .toLowerCase()
              .compareTo(b.internship.companyName.toLowerCase());
        case 'status':
          return a.status.toLowerCase().compareTo(b.status.toLowerCase());
        case 'newest':
        default:
          return b.appliedAt.compareTo(a.appliedAt);
      }
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      appBar: canPop
          ? AppBar(
              title: const Text('My Applications'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Application>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SkeletonLoader(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SkeletonBox(height: 48, borderRadius: 12),
                      SizedBox(height: 12),
                      SkeletonBox(height: 40, borderRadius: 20),
                      SizedBox(height: 16),
                      SkeletonBox(height: 90, borderRadius: 14),
                      SizedBox(height: 12),
                      SkeletonBox(height: 90, borderRadius: 14),
                      SizedBox(height: 12),
                      SkeletonBox(height: 90, borderRadius: 14),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return ErrorStateView(
                title: 'Could not load applications',
                message: 'Please check your connection and pull down to refresh.',
                onRetry: _refresh,
              );
            }

            final allList = snapshot.data ?? [];
            if (allList.isEmpty) {
              return EmptyStateView(
                icon: Icons.assignment_outlined,
                title: 'No applications yet',
                description:
                    'Browse available internships in the catalogue and submit your first application.',
                actionLabel: 'Browse Internships',
                onAction: widget.onBrowseInternships,
              );
            }

            int countFor(String st) => allList
                .where((a) => a.status.toLowerCase().trim() == st)
                .length;

            final filteredList = _filterAndSort(allList);

            return Column(
              children: [
                // Search bar & Sort selector
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search role or company...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        tooltip: 'Sort applications',
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1F2937) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            ),
                          ),
                          child: const Icon(Icons.sort, size: 20),
                        ),
                        onSelected: (val) => setState(() => _sortBy = val),
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'newest',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 18,
                                  color: _sortBy == 'newest' ? AppTheme.ink : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Newest applied',
                                  style: TextStyle(
                                    fontWeight: _sortBy == 'newest'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'company',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.sort_by_alpha,
                                  size: 18,
                                  color: _sortBy == 'company' ? AppTheme.ink : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Company (A-Z)',
                                  style: TextStyle(
                                    fontWeight: _sortBy == 'company'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'status',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 18,
                                  color: _sortBy == 'status' ? AppTheme.ink : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Status',
                                  style: TextStyle(
                                    fontWeight: _sortBy == 'status'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All (${allList.length})',
                        selected: _selectedFilter == 'all',
                        onSelected: () => setState(() => _selectedFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Pending (${countFor('pending')})',
                        selected: _selectedFilter == 'pending',
                        color: AppTheme.saffron,
                        onSelected: () => setState(() => _selectedFilter = 'pending'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Approved (${countFor('approved')})',
                        selected: _selectedFilter == 'approved',
                        color: Colors.green,
                        onSelected: () => setState(() => _selectedFilter = 'approved'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Rejected (${countFor('rejected')})',
                        selected: _selectedFilter == 'rejected',
                        color: Colors.red,
                        onSelected: () => setState(() => _selectedFilter = 'rejected'),
                      ),
                    ],
                  ),
                ),

                // List View
                Expanded(
                  child: filteredList.isEmpty
                      ? EmptyStateView(
                          icon: Icons.search_off,
                          title: 'No matching applications',
                          description:
                              'Try adjusting your search terms or filter selection.',
                          actionLabel: 'Reset filters',
                          onAction: () => setState(() {
                            _selectedFilter = 'all';
                            _searchQuery = '';
                            _searchController.clear();
                          }),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: ListView.builder(
                            key: ValueKey('apps-$_selectedFilter-$_sortBy-$_searchQuery'),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredList.length,
                            itemBuilder: (context, i) {
                              final app = filteredList[i];
                              final job = app.internship;

                              return Hero(
                                tag: 'app-card-${app.id}',
                                child: Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _openDetail(app),
                                    onLongPress: () => _showItemOptions(app),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  job.title,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              StatusChip(status: app.status),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            job.companyName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.grey.shade300
                                                  : Colors.grey.shade800,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Applied ${fmtDate(app.appliedAt)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                job.mode.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? AppTheme.saffron
                                                      : AppTheme.ink,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.chevron_right,
                                                size: 18,
                                                color: Colors.grey,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected
            ? Colors.white
            : (isDark ? Colors.grey.shade300 : AppTheme.ink),
      ),
      selectedColor: color ?? AppTheme.ink,
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? Colors.transparent
              : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
      ),
    );
  }
}
