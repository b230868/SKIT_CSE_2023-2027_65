import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/auth/data/auth_service.dart';
import 'package:prashikshan/features/auth/presentation/register_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthService extends AuthService {
  bool shouldThrowRateLimit = false;
  bool shouldThrowDbError = false;
  bool shouldThrowNetworkError = false;
  bool shouldThrowDuplicateUser = false;
  bool shouldThrowOtpError = false;
  bool shouldThrowResendError = false;
  int registerCallCount = 0;
  int verifyOtpCallCount = 0;
  int resendOtpCallCount = 0;
  Completer<AuthResponse>? registerCompleter;
  String? lastRegisteredEmail;
  String? lastRegisteredPassword;
  String? lastVerifiedToken;
  String? lastResentEmail;

  @override
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? enrollmentNo,
    String? branch,
    String? phone,
    String? companyName,
    String? emailRedirectTo,
  }) async {
    registerCallCount++;
    lastRegisteredEmail = email;
    lastRegisteredPassword = password;
    if (registerCompleter != null) {
      return registerCompleter!.future;
    }
    if (shouldThrowRateLimit) {
      throw const AuthException(
        'Email rate limit exceeded',
        statusCode: '429',
        code: 'over_email_send_rate_limit',
      );
    }
    if (shouldThrowDbError) {
      throw const AuthException(
        'Database error saving new user',
        statusCode: '500',
        code: 'unexpected_failure',
      );
    }
    if (shouldThrowNetworkError) {
      throw const AuthException(
        'Connection refused',
        statusCode: '0',
        code: 'network_error',
      );
    }
    if (shouldThrowDuplicateUser) {
      throw const AuthException(
        'User already registered',
        statusCode: '400',
        code: 'user_already_exists',
      );
    }
    return AuthResponse(
      user: User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {'full_name': fullName},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    OtpType type = OtpType.signup,
  }) async {
    verifyOtpCallCount++;
    lastVerifiedToken = token;
    if (shouldThrowOtpError) {
      throw const AuthException(
        'Token has expired or is invalid',
        statusCode: '400',
        code: 'otp_expired',
      );
    }
    return AuthResponse(
      session: Session(
        accessToken: 'mock-access-token',
        tokenType: 'bearer',
        user: User(
          id: 'test-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      ),
    );
  }

  @override
  Future<ResendResponse> resendSignupOtp(String email) async {
    resendOtpCallCount++;
    lastResentEmail = email;
    if (shouldThrowResendError) {
      throw const AuthException(
        'Email rate limit exceeded',
        statusCode: '429',
        code: 'over_email_send_rate_limit',
      );
    }
    return ResendResponse(messageId: 'mock-msg-id');
  }
}

void main() {
  group('RegisterScreen Validation and Security Tests', () {
    testWidgets('prevents submission when fields are empty or invalid', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(authService: fakeAuth)),
      );

      // Tap Create account without filling any fields
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      // Form validation errors should be displayed
      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Enter your enrollment number'), findsOneWidget);
      expect(find.text('Select your branch'), findsOneWidget);
      expect(find.text('Enter a password'), findsOneWidget);

      // No call to register should have been made
      expect(fakeAuth.registerCallCount, 0);
    });

    testWidgets(
      'provides concise field-level feedback as user types password and avoids large permanent panel',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeAuth = FakeAuthService();

        await tester.pumpWidget(
          MaterialApp(home: RegisterScreen(authService: fakeAuth)),
        );

        // Switch to Industry mentor
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Industry mentor').last);
        await tester.pumpAndSettle();

        // Initially empty: displays single-line requirement hint
        expect(
          find.text(
            'Requirements: 8+ chars, uppercase, lowercase, number, special char',
          ),
          findsOneWidget,
        );

        final fields = find.byType(TextFormField);
        // Form fields for Industry: 0: name, 1: email, 2: phone, 3: company, 4: password, 5: confirm
        final passwordField = fields.at(4);

        // Type only uppercase 'A' -> displays compact badges with Uppercase met
        await tester.enterText(passwordField, 'A');
        await tester.pumpAndSettle();
        expect(find.text('8+ chars'), findsOneWidget);
        expect(find.text('Uppercase'), findsOneWidget);
        expect(find.text('Lowercase'), findsOneWidget);
        expect(find.text('Number'), findsOneWidget);
        expect(find.text('Special char'), findsOneWidget);
        expect(
          find.byIcon(Icons.check),
          findsNWidgets(1),
        ); // only uppercase is met
        expect(find.byIcon(Icons.circle), findsNWidgets(4));

        // Type 'Ab' -> uppercase and lowercase met
        await tester.enterText(passwordField, 'Ab');
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check), findsNWidgets(2));
        expect(find.byIcon(Icons.circle), findsNWidgets(3));

        // Type 'Ab1' -> uppercase, lowercase, digit met
        await tester.enterText(passwordField, 'Ab1');
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check), findsNWidgets(3));
        expect(find.byIcon(Icons.circle), findsNWidgets(2));

        // Type 'Ab1@' -> uppercase, lowercase, digit, special met (length < 8)
        await tester.enterText(passwordField, 'Ab1@');
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check), findsNWidgets(4));
        expect(find.byIcon(Icons.circle), findsNWidgets(1));

        // Type 'Ab1@cdef' -> all 5 criteria met: collapses to single-line 'Strong password'
        await tester.enterText(passwordField, 'Ab1@cdef');
        await tester.pumpAndSettle();
        expect(find.text('Strong password'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        // Badges collapsed: no permanent large panel
        expect(find.text('8+ chars'), findsNothing);
      },
    );

    testWidgets(
      'validates confirm-password field as user types and shows matching state',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeAuth = FakeAuthService();

        await tester.pumpWidget(
          MaterialApp(home: RegisterScreen(authService: fakeAuth)),
        );

        // Switch to Industry mentor
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Industry mentor').last);
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        // Form fields for Industry: 0: name, 1: email, 2: phone, 3: company, 4: password, 5: confirm
        final passwordField = fields.at(4);
        final confirmField = fields.at(5);

        await tester.enterText(passwordField, 'Strong@Pass1');
        await tester.pumpAndSettle();

        // Enter mismatching confirm password
        await tester.enterText(confirmField, 'Different@123');
        await tester.pumpAndSettle();

        // Clear mismatch indicator displayed
        expect(find.text('Passwords do not match'), findsWidgets);

        // Update to matching confirm password
        await tester.enterText(confirmField, 'Strong@Pass1');
        await tester.pumpAndSettle();

        // Clear matching indicator displayed
        expect(find.text('Passwords match'), findsOneWidget);
      },
    );

    testWidgets('masks passwords by default and supports show/hide toggle', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(authService: fakeAuth)),
      );

      // Switch to Industry mentor
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Industry mentor').last);
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      // Form fields for Industry: 0: name, 1: email, 2: phone, 3: company, 4: password, 5: confirm
      final passwordField = fields.at(4);
      final confirmField = fields.at(5);

      // Verify both are masked initially
      EditableText pwdEditable = tester.widget<EditableText>(
        find.descendant(of: passwordField, matching: find.byType(EditableText)),
      );
      EditableText confirmEditable = tester.widget<EditableText>(
        find.descendant(of: confirmField, matching: find.byType(EditableText)),
      );
      expect(pwdEditable.obscureText, isTrue);
      expect(confirmEditable.obscureText, isTrue);

      // Toggle password visibility
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();

      pwdEditable = tester.widget<EditableText>(
        find.descendant(of: passwordField, matching: find.byType(EditableText)),
      );
      expect(pwdEditable.obscureText, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);

      // Toggle back to hide
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pumpAndSettle();
      pwdEditable = tester.widget<EditableText>(
        find.descendant(of: passwordField, matching: find.byType(EditableText)),
      );
      expect(pwdEditable.obscureText, isTrue);

      // Toggle confirm password visibility
      await tester.tap(find.byTooltip('Show confirm password'));
      await tester.pumpAndSettle();
      confirmEditable = tester.widget<EditableText>(
        find.descendant(of: confirmField, matching: find.byType(EditableText)),
      );
      expect(confirmEditable.obscureText, isFalse);
    });

    testWidgets(
      'blocks registration when password is weak or confirm does not match',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeAuth = FakeAuthService();

        await tester.pumpWidget(
          MaterialApp(home: RegisterScreen(authService: fakeAuth)),
        );

        // Switch to Industry mentor
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Industry mentor').last);
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'John Doe');
        await tester.enterText(fields.at(1), 'john@example.com');
        await tester.enterText(fields.at(2), '9876543211');
        await tester.enterText(fields.at(3), 'Acme Inc');
        // Weak password
        await tester.enterText(fields.at(4), 'weakpass1');
        await tester.enterText(fields.at(5), 'weakpass1');
        await tester.pumpAndSettle();

        // Tap Create account
        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await tester.pumpAndSettle();

        // Registration blocked
        expect(fakeAuth.registerCallCount, 0);
        expect(
          find.text('Include at least one uppercase letter (A-Z)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'allows registration with strong password and displays confirmation feedback with route pop',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeAuth = FakeAuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RegisterScreen(authService: fakeAuth),
                      ),
                    );
                  },
                  child: const Text('Open Register'),
                ),
              ),
            ),
          ),
        );

        // Open RegisterScreen
        await tester.tap(find.text('Open Register'));
        await tester.pumpAndSettle();

        // Switch to Industry mentor
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Industry mentor').last);
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'John Mentor');
        await tester.enterText(fields.at(1), 'john@mentor.com');
        await tester.enterText(fields.at(2), '9876543211');
        await tester.enterText(fields.at(3), 'Acme Corporation');
        await tester.enterText(fields.at(4), 'Strong@Pass1');
        await tester.enterText(fields.at(5), 'Strong@Pass1');
        await tester.pumpAndSettle();

        // Tap Create account
        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Exactly 1 call was initiated
        expect(fakeAuth.registerCallCount, 1);
        expect(fakeAuth.lastRegisteredEmail, 'john@mentor.com');
        expect(fakeAuth.lastRegisteredPassword, 'Strong@Pass1');

        // SnackBar appears informing user to check inbox for verification
        expect(
          find.text(
            'Account created! Please check your email inbox to verify your account before signing in.',
          ),
          findsOneWidget,
        );

        // RegisterScreen was popped back to the calling screen
        expect(find.text('Open Register'), findsOneWidget);
        expect(find.byType(RegisterScreen), findsNothing);
      },
    );

    testWidgets(
      'handles registration database error (unexpected_failure) with clear diagnosis',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeAuth = FakeAuthService();
        fakeAuth.shouldThrowDbError = true;

        await tester.pumpWidget(
          MaterialApp(home: RegisterScreen(authService: fakeAuth)),
        );

        // Switch to Industry mentor
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Industry mentor').last);
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Jane Doe');
        await tester.enterText(fields.at(1), 'jane@doe.com');
        await tester.enterText(fields.at(2), '9876543211');
        await tester.enterText(fields.at(3), 'Acme Corporation');
        await tester.enterText(fields.at(4), 'Strong@Pass1');
        await tester.enterText(fields.at(5), 'Strong@Pass1');
        await tester.pumpAndSettle();

        // Tap Create account
        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await tester.pumpAndSettle();

        // Expect database error banner
        expect(find.text('Database Profile Error'), findsOneWidget);
        expect(
          find.textContaining('Could not save your user profile'),
          findsWidgets,
        );
      },
    );

    testWidgets('handles duplicate account error (user_already_exists)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeAuthService();
      fakeAuth.shouldThrowDuplicateUser = true;

      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(authService: fakeAuth)),
      );

      // Switch to Industry mentor
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Industry mentor').last);
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Existing User');
      await tester.enterText(fields.at(1), 'existing@user.com');
      await tester.enterText(fields.at(2), '9876543211');
      await tester.enterText(fields.at(3), 'Acme Corporation');
      await tester.enterText(fields.at(4), 'Strong@Pass1');
      await tester.enterText(fields.at(5), 'Strong@Pass1');
      await tester.pumpAndSettle();

      // Tap Create account
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      // Expect user friendly duplicate message
      expect(
        find.textContaining('An account with this email already exists'),
        findsOneWidget,
      );
    });

    testWidgets('handles network connection error gracefully', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeAuthService();
      fakeAuth.shouldThrowNetworkError = true;

      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(authService: fakeAuth)),
      );

      // Switch to Industry mentor
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Industry mentor').last);
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Network User');
      await tester.enterText(fields.at(1), 'net@user.com');
      await tester.enterText(fields.at(2), '9876543211');
      await tester.enterText(fields.at(3), 'Acme Corporation');
      await tester.enterText(fields.at(4), 'Strong@Pass1');
      await tester.enterText(fields.at(5), 'Strong@Pass1');
      await tester.pumpAndSettle();

      // Tap Create account
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Network connection error'), findsOneWidget);
    });

    testWidgets(
      'handles email rate limit error by activating cooldown, displaying banner, and disabling button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeAuth = FakeAuthService();
        fakeAuth.shouldThrowRateLimit = true;

        await tester.pumpWidget(
          MaterialApp(home: RegisterScreen(authService: fakeAuth)),
        );

        // Switch role to Industry mentor
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Industry mentor').last);
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Jane Partner');
        await tester.enterText(fields.at(1), 'jane@partner.com');
        await tester.enterText(fields.at(2), '9876543211');
        await tester.enterText(fields.at(3), 'Acme Corporation');
        await tester.enterText(fields.at(4), 'Strong@Pass1');
        await tester.enterText(fields.at(5), 'Strong@Pass1');
        await tester.pumpAndSettle();

        // Tap Create account
        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should have attempted registration once
        expect(fakeAuth.registerCallCount, 1);

        // Rate limit banner must now be visible
        expect(find.text('Email Rate Limit Active'), findsOneWidget);
        expect(find.textContaining('Email rate limit exceeded'), findsWidgets);
        expect(find.text('Already registered? Go to Login'), findsOneWidget);

        // Button should now be disabled and display countdown
        expect(find.text('Please wait (60s)'), findsOneWidget);

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);

        // Repeated click while in cooldown must NOT trigger new requests
        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        await tester.pump();
        expect(fakeAuth.registerCallCount, 1);
      },
    );

    testWidgets(
      'validates mobile phone field format when entered',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeAuth = FakeAuthService();

        await tester.pumpWidget(
          MaterialApp(home: RegisterScreen(authService: fakeAuth)),
        );

        // Switch to Industry mentor
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Industry mentor').last);
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Test User');
        await tester.enterText(fields.at(1), 'test@example.com');
        // Invalid mobile number (dummy repeated sequence)
        await tester.enterText(fields.at(2), '9999999999');
        await tester.enterText(fields.at(3), 'Acme Inc');
        await tester.enterText(fields.at(4), 'Strong@Pass1');
        await tester.enterText(fields.at(5), 'Strong@Pass1');
        await tester.pumpAndSettle();

        // Tap Create account
        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await tester.pumpAndSettle();

        // Phone validation error displayed and submission blocked
        expect(
          find.text('Enter a valid registered mobile number, not a dummy or sequential combination'),
          findsOneWidget,
        );
        expect(fakeAuth.registerCallCount, 0);

        // Fix phone number to valid 10 digits
        await tester.enterText(fields.at(2), '9876543211');
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(fakeAuth.registerCallCount, 1);
      },
    );

    testWidgets(
      'handles student registration flow with branch and enrollment fields',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeAuth = FakeAuthService();

        await tester.pumpWidget(
          MaterialApp(home: RegisterScreen(authService: fakeAuth)),
        );

        // By default role is 'student'
        final fields = find.byType(TextFormField);
        // Student fields: 0: name, 1: email, 2: phone, 3: enrollment, 4: password, 5: confirm
        await tester.enterText(fields.at(0), 'Student User');
        await tester.enterText(fields.at(1), 'student@university.edu');
        await tester.enterText(fields.at(2), '9876543211');
        await tester.enterText(fields.at(3), 'ENROLL12345');

        // Select branch dropdown (second dropdown on screen: first is role, second is branch)
        final dropdowns = find.byType(DropdownButtonFormField<String>);
        await tester.tap(dropdowns.at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CSE').last);
        await tester.pumpAndSettle();

        await tester.enterText(fields.at(4), 'Strong@Pass1');
        await tester.enterText(fields.at(5), 'Strong@Pass1');
        await tester.pumpAndSettle();

        // Tap Create account
        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(fakeAuth.registerCallCount, 1);
        expect(fakeAuth.lastRegisteredEmail, 'student@university.edu');
      },
    );

    testWidgets(
      'supports repeated valid/invalid submissions in a session without crashing or state leak',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeAuth = FakeAuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RegisterScreen(authService: fakeAuth),
                      ),
                    );
                  },
                  child: const Text('Open Register'),
                ),
              ),
            ),
          ),
        );

        // Open Register
        await tester.tap(find.text('Open Register'));
        await tester.pumpAndSettle();

        // Step 1: Click without data -> validation error
        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await tester.pumpAndSettle();
        expect(fakeAuth.registerCallCount, 0);

        // Step 2: Switch to Industry mentor and fill valid data
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Industry mentor').last);
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Session User 1');
        await tester.enterText(fields.at(1), 'user1@session.com');
        await tester.enterText(fields.at(2), '9876543211');
        await tester.enterText(fields.at(3), 'Acme Inc');
        await tester.enterText(fields.at(4), 'Strong@Pass1');
        await tester.enterText(fields.at(5), 'Strong@Pass1');
        await tester.pumpAndSettle();

        // Submit first valid registration
        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(fakeAuth.registerCallCount, 1);
        expect(fakeAuth.lastRegisteredEmail, 'user1@session.com');
        expect(
          find.text(
            'Account created! Please check your email inbox to verify your account before signing in.',
          ),
          findsOneWidget,
        );

        // Step 3: Open Register again to register a second user in the session
        await tester.tap(find.text('Open Register'));
        await tester.pumpAndSettle();

        // Switch to Industry mentor for second user
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Industry mentor').last);
        await tester.pumpAndSettle();

        final fields2 = find.byType(TextFormField);
        await tester.enterText(fields2.at(0), 'Session User 2');
        await tester.enterText(fields2.at(1), 'user2@session.com');
        await tester.enterText(fields2.at(2), '9876543212');
        await tester.enterText(fields2.at(3), 'Beta Corp');
        await tester.enterText(fields2.at(4), 'Strong@Pass2');
        await tester.enterText(fields2.at(5), 'Strong@Pass2');
        await tester.pumpAndSettle();

        // Submit second valid registration
        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(fakeAuth.registerCallCount, 2);
        expect(fakeAuth.lastRegisteredEmail, 'user2@session.com');
        expect(
          find.text(
            'Account created! Please check your email inbox to verify your account before signing in.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
