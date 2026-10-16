import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/core/auth/auth_service.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/faculty_dashboard_screen.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/student_dashboard_screen.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/tp_dashboard_screen.dart';

void main() {
  group('AuthDialog UI and Validation Tests', () {
    testWidgets(
      'Demo Faculty and Demo T&P buttons are completely removed from dialog',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AuthService.showAuthDialog(context),
                    child: const Text('Open Auth'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open auth dialog
        await tester.tap(find.text('Open Auth'));
        await tester.pumpAndSettle();

        // Verify Sign In dialog opened
        expect(find.text('Sign In'), findsWidgets);

        // Verify Demo Faculty & Demo T&P buttons DO NOT exist
        expect(find.text('Demo Faculty'), findsNothing);
        expect(find.text('Demo T&P'), findsNothing);
        expect(find.text('faculty@faculty.com'), findsNothing);
        expect(find.text('tp@college.com'), findsNothing);
      },
    );

    testWidgets(
      'Sign in fields include show/hide password toggle and required buttons',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AuthService.showAuthDialog(context),
                    child: const Text('Open Auth'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Auth'));
        await tester.pumpAndSettle();

        // Check fields
        expect(find.byType(TextField), findsNWidgets(2)); // Email and Password
        expect(find.text('Email Address'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Forgot Password?'), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);
        expect(
          find.byIcon(Icons.visibility_off),
          findsOneWidget,
        ); // Password obscured by default

        // Toggle password visibility
        await tester.tap(find.byIcon(Icons.visibility_off));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.visibility), findsOneWidget);
      },
    );

    testWidgets(
      'Sign in displays validation error for empty or invalid email',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AuthService.showAuthDialog(context),
                    child: const Text('Open Auth'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Auth'));
        await tester.pumpAndSettle();

        // Click Sign In with empty fields
        await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter an email address.'), findsOneWidget);

        // Enter invalid email format
        await tester.enterText(
          find.widgetWithText(TextField, 'Email Address'),
          'invalid-email',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter a valid email address format.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Sign in displays validation error for empty password', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => AuthService.showAuthDialog(context),
                  child: const Text('Open Auth'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Auth'));
      await tester.pumpAndSettle();

      // Enter valid email but empty password
      await tester.enterText(
        find.widgetWithText(TextField, 'Email Address'),
        'student@college.edu',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your password.'), findsOneWidget);
    });

    testWidgets(
      'Switching to Create Account shows full registration fields and validations',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AuthService.showAuthDialog(context),
                    child: const Text('Open Auth'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Auth'));
        await tester.pumpAndSettle();

        // Tap Create Account
        await tester.tap(find.text('Create Account'));
        await tester.pumpAndSettle();

        // Verify fields present
        expect(find.text('Full Name'), findsOneWidget);
        expect(find.text('Email Address'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Confirm Password'), findsOneWidget);
        expect(find.text('Already have an account? Sign In'), findsOneWidget);

        // Click Create Account without filling Full Name
        await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();
        expect(find.text('Please enter an email address.'), findsOneWidget);

        // Enter valid email, then test full name check
        await tester.enterText(
          find.widgetWithText(TextField, 'Email Address'),
          'newstudent@college.edu',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();
        expect(find.text('Please enter your full name.'), findsOneWidget);

        // Enter short full name
        await tester.enterText(
          find.widgetWithText(TextField, 'Full Name'),
          'A',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();
        expect(
          find.text('Full name must be at least 2 characters.'),
          findsOneWidget,
        );

        // Enter proper full name
        await tester.enterText(
          find.widgetWithText(TextField, 'Full Name'),
          'Alice Smith',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();
        expect(find.text('Please enter a password.'), findsOneWidget);

        // Enter password less than 6 characters
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          '12345',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();
        expect(
          find.text('Password must be at least 6 characters long.'),
          findsOneWidget,
        );

        // Enter password but mismatched confirm password
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          'SecretPass@123',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm Password'),
          'DifferentPass@123',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();
        expect(
          find.text('Passwords do not match. Please verify.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Switching to Forgot Password mode displays recovery instructions and back link',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AuthService.showAuthDialog(context),
                    child: const Text('Open Auth'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Auth'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Forgot Password?'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Password'), findsWidgets);
        expect(find.textContaining('recovery instructions'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Send Reset Link'),
          findsOneWidget,
        );

        // Can navigate back to sign in
        await tester.tap(find.text('Already have an account? Sign In'));
        await tester.pumpAndSettle();
        expect(find.text('Sign In'), findsWidgets);
      },
    );
  });

  group('Role-Based Navigation Tests', () {
    testWidgets('navigateForRole routes tpOfficer to TpDashboardScreen', (
      tester,
    ) async {
      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              testContext = context;
              return const Scaffold(body: Text('Initial Screen'));
            },
          ),
        ),
      );

      AuthService.navigateForRole(testContext, AppRole.tpOfficer);
      await tester.pumpAndSettle();

      expect(find.byType(TpDashboardScreen), findsOneWidget);
      expect(find.text('T&P Dashboard'), findsOneWidget);
    });

    testWidgets(
      'navigateForRole routes facultyMentor to FacultyDashboardScreen',
      (tester) async {
        late BuildContext testContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                testContext = context;
                return const Scaffold(body: Text('Initial Screen'));
              },
            ),
          ),
        );

        AuthService.navigateForRole(testContext, AppRole.facultyMentor);
        await tester.pumpAndSettle();

        expect(find.byType(FacultyDashboardScreen), findsOneWidget);
        expect(find.text('Faculty & T&P Dashboard'), findsOneWidget);
      },
    );

    testWidgets('navigateForRole routes student to StudentDashboardScreen', (
      tester,
    ) async {
      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              testContext = context;
              return const Scaffold(body: Text('Initial Screen'));
            },
          ),
        ),
      );

      AuthService.navigateForRole(testContext, AppRole.student);
      await tester.pumpAndSettle();

      expect(find.byType(StudentDashboardScreen), findsOneWidget);
      expect(find.text('Student Dashboard'), findsOneWidget);
    });
  });
}
