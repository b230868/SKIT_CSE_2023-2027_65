import 'package:flutter/material.dart';

import '../../core/storage/cache_service.dart';
import '../../core/theme.dart';
import '../auth/models/app_user.dart';
import '../auth/presentation/profile_screen.dart';
import '../internship/presentation/internship_list_screen.dart';
import '../itr/presentation/screens/itr_screen.dart';
import '../placement/presentation/screens/student_placements_hub_screen.dart';
import 'presentation/student_applications_screen.dart';
import 'student_dashboard_screen.dart';

/// Responsive student portal shell:
/// - NavigationRail on wide screens (web / desktop)
/// - NavigationBar on mobile screens
/// - Light & Dark theme toggle remembered via Hive (CacheService)
/// - Seamless cross-tab navigation with filtered application views
class StudentShell extends StatefulWidget {
  final AppUser user;
  const StudentShell({super.key, required this.user});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;
  int _version = 0;
  String _applicationsFilter = 'all';
  late AppUser _user;
  bool _isDark = false;

  static const String _themeKey = 'app_theme_is_dark';

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadThemePreference();
  }

  void _loadThemePreference() {
    try {
      final saved = CacheService.box.get(_themeKey);
      if (saved is bool) {
        setState(() => _isDark = saved);
      }
    } catch (_) {}
  }

  void _toggleTheme() {
    setState(() => _isDark = !_isDark);
    try {
      CacheService.box.put(_themeKey, _isDark);
    } catch (_) {}
  }

  void _refreshDashboard() => setState(() => _version++);

  void _navigate(int tabIndex, {String? filter}) {
    setState(() {
      if (filter != null) {
        _applicationsFilter = filter;
      }
      _index = tabIndex;
      _version++;
    });
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTheme.ink,
      primary: AppTheme.saffron,
      secondary: AppTheme.saffron,
      brightness: Brightness.dark,
      surface: const Color(0xFF1E293B),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardColor: const Color(0xFF1E293B),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: AppTheme.saffron.withValues(alpha: 0.3),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: AppTheme.saffron.withValues(alpha: 0.3),
        selectedIconTheme: const IconThemeData(color: AppTheme.saffron),
        selectedLabelTextStyle: const TextStyle(
          color: AppTheme.saffron,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final currentTheme = _isDark ? _buildDarkTheme() : AppTheme.light;

    final pages = [
      StudentDashboardScreen(
        key: ValueKey('dashboard-$_version'),
        user: _user,
        onApply: () => _navigate(3), // Switch to Internships catalog
        onNavigate: _navigate,
      ),
      StudentPlacementsHubScreen(
        key: ValueKey('placements-$_version'),
        user: _user,
      ),
      StudentApplicationsScreen(
        key: ValueKey('apps-$_version-$_applicationsFilter'),
        initialFilter: _applicationsFilter,
        onBrowseInternships: () => _navigate(3),
      ),
      InternshipListScreen(onChanged: _refreshDashboard),
      ItrListScreen(key: ValueKey('itrs-$_version')),
      ProfileScreen(
        user: _user,
        onUpdated: (u) => setState(() => _user = u),
      ),
    ];

    final destinations = const [
      (Icons.dashboard_outlined, Icons.dashboard, 'Home'),
      (Icons.campaign_outlined, Icons.campaign, 'Placements'),
      (Icons.assignment_outlined, Icons.assignment, 'Applied'),
      (Icons.work_outline, Icons.work, 'Internships'),
      (Icons.fact_check_outlined, Icons.fact_check, 'ITRs'),
      (Icons.person_outline, Icons.person, 'Profile'),
    ];

    final bodyContent = IndexedStack(
      index: _index,
      children: pages,
    );

    return Theme(
      data: currentTheme,
      child: Scaffold(
        body: isWide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: (i) {
                      setState(() {
                        if (i == 0 && _index != 0) _version++;
                        if (i == 2) _applicationsFilter = 'all';
                        _index = i;
                      });
                    },
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 16),
                      child: Tooltip(
                        message: 'Toggle theme (${_isDark ? 'Dark' : 'Light'})',
                        child: IconButton(
                          icon: Icon(
                            _isDark ? Icons.light_mode : Icons.dark_mode,
                            color: _isDark ? AppTheme.saffron : AppTheme.ink,
                          ),
                          onPressed: _toggleTheme,
                        ),
                      ),
                    ),
                    destinations: destinations
                        .map(
                          (d) => NavigationRailDestination(
                            icon: Icon(d.$1),
                            selectedIcon: Icon(d.$2),
                            label: Text(d.$3),
                          ),
                        )
                        .toList(),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: bodyContent),
                ],
              )
            : bodyContent,
        bottomNavigationBar: isWide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) {
                  setState(() {
                    if (i == 0 && _index != 0) _version++;
                    if (i == 2) _applicationsFilter = 'all';
                    _index = i;
                  });
                },
                destinations: destinations
                    .map(
                      (d) => NavigationDestination(
                        icon: Icon(d.$1),
                        selectedIcon: Icon(d.$2),
                        label: d.$3,
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}
