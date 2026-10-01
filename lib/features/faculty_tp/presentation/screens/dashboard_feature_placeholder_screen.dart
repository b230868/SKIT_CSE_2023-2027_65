import 'package:flutter/material.dart';

class DashboardFeaturePlaceholderScreen extends StatelessWidget {
  final String title;

  const DashboardFeaturePlaceholderScreen({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title is not available yet.'),
      ),
    );
  }
}
