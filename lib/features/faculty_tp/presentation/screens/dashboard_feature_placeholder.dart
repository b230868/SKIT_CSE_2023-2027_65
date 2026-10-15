import 'package:flutter/material.dart';

class DashboardFeaturePlaceholder extends StatelessWidget {
  final String title;

  const DashboardFeaturePlaceholder({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$title is not available yet.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
