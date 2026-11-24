import 'package:flutter/material.dart';

class NavigationShellTab {
  final Widget screen;
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const NavigationShellTab({
    required this.screen,
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

class AppNavigationShell extends StatefulWidget {
  final List<NavigationShellTab> tabs;
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;

  const AppNavigationShell({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.onTabChanged,
  });

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
    widget.onTabChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: widget.tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: widget.tabs.map((t) {
          return NavigationDestination(
            icon: Icon(t.icon),
            selectedIcon: Icon(t.selectedIcon ?? t.icon),
            label: t.label,
          );
        }).toList(),
      ),
    );
  }
}
