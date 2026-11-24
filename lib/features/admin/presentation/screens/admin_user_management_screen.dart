import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/role_config.dart';
import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/status_chip.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _searchController = TextEditingController();
  String _selectedRole = 'all';
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('profiles')
          .select('*')
          .order('full_name', ascending: true);

      final list = List<Map<String, dynamic>>.from(rows as List);
      if (mounted) {
        setState(() {
          _users = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _users = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _users.where((u) {
      final role = (u['role'] ?? '').toString().toLowerCase();
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final branch = (u['branch'] ?? '').toString().toLowerCase();
      final enroll = (u['enrollment_no'] ?? '').toString().toLowerCase();

      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          branch.contains(query) ||
          enroll.contains(query);

      final matchesRole = _selectedRole == 'all' ||
          role == _selectedRole ||
          (_selectedRole == 'faculty' && role.contains('faculty')) ||
          (_selectedRole == 'tp' && (role.contains('tp') || role.contains('tnp'))) ||
          (_selectedRole == 'industry' && role.contains('industry'));

      return matchesQuery && matchesRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            tooltip: 'Add / Invite User',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: _showAddUserDialog,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, branch or roll number...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRoleFilterChip('all', 'All Users (${_users.length})'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('student', 'Students'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('faculty', 'Faculty Mentors'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('industry', 'Industry Supervisors'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('tp', 'T&P Cell'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const EmptyStateWidget(
                        message: 'No matching users found.',
                        icon: Icons.people_outline,
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchUsers,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final user = filtered[index];
                            return _buildUserCard(user);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add User'),
      ),
    );
  }

  Widget _buildRoleFilterChip(String key, String label) {
    final isSelected = _selectedRole == key;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.ink,
      ),
      selectedColor: AppTheme.ink,
      backgroundColor: Colors.white,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.ink : AppTheme.slateBorder,
      ),
      onSelected: (_) => setState(() => _selectedRole = key),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role'] ?? 'student';
    final name = user['full_name'] ?? 'User';
    final email = user['email'] ?? '';
    final branch = user['branch'] ?? user['department'] ?? 'General';
    final enrollment = user['enrollment_no'];
    final bool isActive = user['is_active'] ?? true;
    final badgeColor = RoleConfig.color(role);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showUserDetailsModal(user),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: badgeColor.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        RoleBadge(role: role),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.slateMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      enrollment != null ? '$enrollment · $branch' : branch,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.slateMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDetailsModal(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          bool isActive = user['is_active'] ?? true;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'User Profile Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.ink,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.ink.withValues(alpha: 0.1),
                    child: Text(
                      (user['full_name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  title: Text(
                    user['full_name'] ?? 'Unnamed',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(user['email'] ?? 'No email'),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Role', user['role'] ?? 'student'),
                if (user['enrollment_no'] != null)
                  _buildInfoRow('Enrollment No', user['enrollment_no']),
                if (user['branch'] != null)
                  _buildInfoRow('Department / Branch', user['branch']),
                if (user['designation'] != null)
                  _buildInfoRow('Designation', user['designation']),
                if (user['phone'] != null)
                  _buildInfoRow('Phone', user['phone']),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Active Account Status',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isActive
                        ? 'User can sign in and submit workflows'
                        : 'Access temporarily suspended',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: isActive,
                  onChanged: (val) {
                    setModalState(() {
                      user['is_active'] = val;
                      isActive = val;
                    });
                    setState(() {});
                    showSnack(
                      context,
                      'User status updated to ${val ? "Active" : "Suspended"}',
                    );
                  },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showSnack(
                      context,
                      'Password reset link dispatched to ${user['email']}',
                    );
                  },
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Send Password Reset Link'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.slateMuted, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final branchCtrl = TextEditingController();
    String role = 'student';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Institutional User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Official Email',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(
                      value: 'faculty_mentor',
                      child: Text('Faculty Mentor'),
                    ),
                    DropdownMenuItem(
                      value: 'tp_officer',
                      child: Text('T&P Officer'),
                    ),
                    DropdownMenuItem(
                      value: 'industry_supervisor',
                      child: Text('Industry Supervisor'),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'student'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: branchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Branch / Department',
                    hintText: 'e.g. CSE / IT / ECE',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                if (name.isEmpty || email.isEmpty) {
                  showSnack(context, 'Please fill in required fields', error: true);
                  return;
                }
                final newUser = {
                  'id': 'new-${DateTime.now().millisecondsSinceEpoch}',
                  'full_name': name,
                  'email': email,
                  'role': role,
                  'branch': branchCtrl.text.trim(),
                  'is_active': true,
                  'created_at': DateTime.now().toIso8601String(),
                };
                setState(() {
                  _users.insert(0, newUser);
                });
                Navigator.pop(ctx);
                showSnack(context, 'New user "$name" created successfully');
              },
              child: const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }
}
