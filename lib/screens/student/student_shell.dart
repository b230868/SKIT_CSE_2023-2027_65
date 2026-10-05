import 'package:flutter/material.dart';
import '../../features/auth/models/app_user.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/internship/presentation/internship_list_screen.dart';
import '../../models/student_models.dart';
import '../../services/student_service.dart';
import 'applications_screen.dart';
import 'notification_screen.dart';
import 'reports_screen.dart';

/// Student portal: bottom navigation with Home, Internships, Applications, Profile.
class StudentShell extends StatefulWidget {
  final AppUser user;
  const StudentShell({super.key, required this.user});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _tab = 0;
  int _version = 0; // bump to reload applications and home stats
  late AppUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  void _goTo(int i, {bool reload = false}) {
    setState(() {
      _tab = i;
      if (reload) _version++;
    });
  }

  void _refresh() => setState(() => _version++);

  @override
  Widget build(BuildContext context) {
    const titles = ['Home', 'Internships', 'My applications', 'Profile'];
    return Scaffold(
      appBar: _tab == 3
          ? null
          : AppBar(
              title: Text(titles[_tab]),
              actions: const [NotificationBell()],
            ),
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(
            key: ValueKey('home$_version'),
            user: _user,
            onNavigate: _goTo,
          ),
          InternshipListScreen(onChanged: _refresh),
          ApplicationsScreen(key: ValueKey('apps$_version')),
          ProfileScreen(
            user: _user,
            onUpdated: (user) => setState(() {
              _user = user;
              _version++;
            }),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: 'Internships'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Applications'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final AppUser user;
  final void Function(int) onNavigate;
  const _HomeTab({super.key, required this.user, required this.onNavigate});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late final Future<List<Application>> _apps = StudentService().myApplications();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = widget.user.firstName;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hello, $first', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Track your internships and applications in one place.'),
        const SizedBox(height: 16),
        FutureBuilder<List<Application>>(
          future: _apps,
          builder: (context, s) {
            final list = s.data ?? const <Application>[];
            int n(String st) => list.where((a) => a.status == st).length;
            return Row(children: [
              _Stat('Pending', n('pending')),
              _Stat('Approved', n('approved')),
              _Stat('Rejected', n('rejected')),
            ]);
          },
        ),
        const SizedBox(height: 16),
        _Action(Icons.work_outline, 'Browse internships', 'See open positions and apply',
            () => widget.onNavigate(1)),
        _Action(Icons.assignment_outlined, 'My applications', 'Check status, documents and progress',
            () => widget.onNavigate(2)),
        _Action(Icons.bar_chart_outlined, 'My report', 'See your application and progress summary',
            () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ReportsScreen()))),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Text('$value', style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ]),
          ),
        ),
      );
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _Action(this.icon, this.title, this.subtitle, this.onTap);

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
