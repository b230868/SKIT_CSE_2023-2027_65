import 'package:flutter/material.dart';
import 'features/industry/presentation/screens/industry_dashboard_screen.dart';

void main() {
  runApp(const PrashikshanApp());
}

class PrashikshanApp extends StatelessWidget {
  const PrashikshanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prashikshan',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const IndustryDashboardScreen(),
    );
  }
}