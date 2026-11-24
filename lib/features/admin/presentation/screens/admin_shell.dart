import 'package:flutter/material.dart';

import '../../../../core/widgets/app_navigation_shell.dart';
import '../../../auth/models/app_user.dart';
import '../../../auth/presentation/profile_screen.dart';
import 'admin_affiliations_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_erp_sync_screen.dart';
import 'admin_user_management_screen.dart';

class AdminShell extends StatefulWidget {
  final AppUser user;

  const AdminShell({super.key, required this.user});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late AppUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    return AppNavigationShell(
      tabs: [
        NavigationShellTab(
          screen: AdminDashboardScreen(user: _user),
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Overview',
        ),
        const NavigationShellTab(
          screen: AdminUserManagementScreen(),
          icon: Icons.group_outlined,
          selectedIcon: Icons.group,
          label: 'Users',
        ),
        const NavigationShellTab(
          screen: AdminAffiliationsScreen(),
          icon: Icons.apartment_outlined,
          selectedIcon: Icons.apartment,
          label: 'Affiliations',
        ),
        const NavigationShellTab(
          screen: AdminErpSyncScreen(),
          icon: Icons.sync_alt_outlined,
          selectedIcon: Icons.sync_alt,
          label: 'ERP Sync',
        ),
        NavigationShellTab(
          screen: ProfileScreen(
            user: _user,
            onUpdated: (u) => setState(() => _user = u),
          ),
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profile',
        ),
      ],
    );
  }
}
