import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/main.dart';

void main() {
  testWidgets('Prashikshan app uses the configured home', (tester) async {
    await tester.pumpWidget(
      const PrashikshanApp(home: Scaffold(body: Text('Test home'))),
    );
    expect(find.text('Test home'), findsOneWidget);
    expect(find.text('Test home'), findsOneWidget);
  });
}
