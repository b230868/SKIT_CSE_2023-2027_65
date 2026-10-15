import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/core/auth/auth_service.dart';

/// In-memory mock simulating PostgreSQL logic of public.admin_assign_user_role()
/// and public.handle_new_user() triggers under the security migration.
class MockPostgresSecurityContext {
  final Map<String, Map<String, dynamic>> profiles = {};

  /// Simulates public.current_user_role() for the current session.
  String? currentUserRole;

  /// Simulates PostgreSQL ternary logic for:
  /// (SELECT public.current_user_role()) IS DISTINCT FROM 'admin'::public.app_role
  bool isCallerDenied() {
    // In PostgreSQL:
    // NULL IS DISTINCT FROM 'admin' -> TRUE (Denied!)
    // 'student' IS DISTINCT FROM 'admin' -> TRUE (Denied!)
    // 'faculty_mentor' IS DISTINCT FROM 'admin' -> TRUE (Denied!)
    // 'tp_officer' IS DISTINCT FROM 'admin' -> TRUE (Denied!)
    // 'admin' IS DISTINCT FROM 'admin' -> FALSE (Allowed!)
    const adminRole = 'admin';
    if (currentUserRole == null) return true;
    return currentUserRole != adminRole;
  }

  /// Simulates public.admin_assign_user_role(target_user_id uuid, new_role public.app_role)
  void adminAssignUserRole({
    required String? targetUserId,
    required String? newRole,
  }) {
    // 1. Authorization check
    if (isCallerDenied()) {
      throw Exception(
        'Access denied: Only administrators can assign elevated user roles.',
      );
    }

    // 2. Input validation
    if (targetUserId == null || targetUserId.trim().isEmpty) {
      throw ArgumentError(
        'Invalid target user: target_user_id cannot be NULL.',
      );
    }

    const validRoles = [
      'student',
      'faculty_mentor',
      'tp_officer',
      'industry_supervisor',
      'admin',
    ];

    if (newRole == null || !validRoles.contains(newRole.toLowerCase().trim())) {
      throw ArgumentError(
        'Invalid role: new_role cannot be NULL or unrecognized.',
      );
    }

    // 3. Ensure target profile exists
    if (!profiles.containsKey(targetUserId)) {
      throw Exception('Target user profile not found.');
    }

    // 4. Update profile role
    profiles[targetUserId]!['role'] = newRole;
    profiles[targetUserId]!['updated_at'] = DateTime.now().toIso8601String();
  }

  /// Simulates public.handle_new_user() trigger function
  void handleNewUser({
    required String userId,
    required String email,
    Map<String, dynamic>? rawUserMetaData,
    Map<String, dynamic>? rawAppMetaData,
  }) {
    // Client-supplied raw_user_meta_data->>'role' is strictly IGNORED
    String assignedRole;
    if (rawAppMetaData != null && rawAppMetaData.containsKey('role')) {
      final appRole = (rawAppMetaData['role'] as String).toLowerCase().trim();
      switch (appRole) {
        case 'admin':
          assignedRole = 'admin';
          break;
        case 'faculty':
        case 'faculty_mentor':
          assignedRole = 'faculty_mentor';
          break;
        case 'tnp':
        case 'tp_officer':
          assignedRole = 'tp_officer';
          break;
        case 'industry':
        case 'industry_supervisor':
          assignedRole = 'industry_supervisor';
          break;
        default:
          assignedRole = 'student';
      }
    } else {
      // Default to student strictly
      assignedRole = 'student';
    }

    if (profiles.containsKey(userId)) {
      // ON CONFLICT (id) DO UPDATE - role is intentionally preserved!
      final existing = profiles[userId]!;
      existing['email'] = email;
      existing['updated_at'] = DateTime.now().toIso8601String();
      // Notice: existing['role'] is NOT modified!
    } else {
      profiles[userId] = {
        'id': userId,
        'email': email,
        'role': assignedRole,
        'full_name': rawUserMetaData?['full_name'] ?? rawUserMetaData?['name'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
  }
}

void main() {
  group('Supabase Role Escalation Migration File Static Audit', () {
    late String migrationSql;

    setUpAll(() {
      final migrationFile = File(
        'supabase/migrations/20261015154500_prevent_self_signup_role_escalation.sql',
      );
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Migration file must exist at expected path',
      );
      migrationSql = migrationFile.readAsStringSync();
    });

    test(
      'admin_assign_user_role uses IS DISTINCT FROM for caller authorization',
      () {
        expect(
          migrationSql.contains("IS DISTINCT FROM 'admin'::public.app_role"),
          isTrue,
          reason: "Authorization check must use IS DISTINCT FROM 'admin'::public.app_role so NULL/missing caller role is denied",
        );
      },
    );

    test('admin_assign_user_role does NOT use vulnerable != comparison for caller authorization', () {
      // In PostgreSQL, NULL != 'admin' evaluates to NULL (UNKNOWN), which evaluates to FALSE in IF conditions, bypassing checks!
      expect(
        migrationSql.contains("current_user_role()) != 'admin'"),
        isFalse,
        reason: "Must NOT use != comparison which allows NULL bypass",
      );
    });

    test(
      'admin_assign_user_role explicitly revokes EXECUTE from PUBLIC and anon',
      () {
        expect(
          migrationSql.contains(
            'REVOKE ALL ON FUNCTION public.admin_assign_user_role(uuid, public.app_role) FROM PUBLIC;',
          ),
          isTrue,
          reason: 'Must revoke execute on admin_assign_user_role from PUBLIC',
        );
        expect(
          migrationSql.contains(
            'REVOKE ALL ON FUNCTION public.admin_assign_user_role(uuid, public.app_role) FROM anon;',
          ),
          isTrue,
          reason: 'Must revoke execute on admin_assign_user_role from anon',
        );
      },
    );

    test('admin_assign_user_role grants EXECUTE strictly to minimum required roles', () {
      expect(
        migrationSql.contains(
          'GRANT EXECUTE ON FUNCTION public.admin_assign_user_role(uuid, public.app_role) TO authenticated;',
        ),
        isTrue,
        reason: 'Must grant execute to authenticated role with internal check retained',
      );
      expect(
        migrationSql.contains(
          'GRANT EXECUTE ON FUNCTION public.admin_assign_user_role(uuid, public.app_role) TO service_role;',
        ),
        isTrue,
        reason: 'Must grant execute to service_role',
      );
    });

    test('handle_new_user explicitly revokes EXECUTE from PUBLIC and anon', () {
      expect(
        migrationSql.contains(
          'REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;',
        ),
        isTrue,
        reason:
            'Must revoke direct execute on handle_new_user trigger from PUBLIC',
      );
      expect(
        migrationSql.contains(
          'REVOKE ALL ON FUNCTION public.handle_new_user() FROM anon;',
        ),
        isTrue,
        reason:
            'Must revoke direct execute on handle_new_user trigger from anon',
      );
    });

    test('handle_new_user grants EXECUTE to supabase_auth_admin to ensure trigger functionality', () {
      expect(
        migrationSql.contains(
          'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;',
        ),
        isTrue,
        reason: 'Must grant execute to supabase_auth_admin so GoTrue auth trigger functions without permission denial',
      );
    });

    test('handle_new_user ignores raw_user_meta_data role and only trusts raw_app_meta_data', () {
      // Filter out SQL comment lines to verify executable statements
      final executableSql = migrationSql
          .split('\n')
          .where((line) => !line.trim().startsWith('--'))
          .join('\n');

      expect(
        executableSql.contains("raw_user_meta_data->>'role'"),
        isFalse,
        reason: "Must NEVER read client-controlled raw_user_meta_data->>'role' in executable SQL",
      );
      expect(
        executableSql.contains("NEW.raw_app_meta_data IS NOT NULL"),
        isTrue,
        reason: 'Must only check server-controlled raw_app_meta_data',
      );
      expect(
        executableSql.contains("v_role := 'student'::public.app_role;"),
        isTrue,
        reason: 'Default self-signup must be student::public.app_role',
      );
    });

    test('handle_new_user ON CONFLICT clause does NOT overwrite role on profile update', () {
      expect(
        migrationSql.contains('role = EXCLUDED.role'),
        isFalse,
        reason: 'ON CONFLICT clause must NOT overwrite profile role on update',
      );
    });
  });

  group('Role Escalation Authorization & Execution Simulation', () {
    late MockPostgresSecurityContext context;

    setUp(() {
      context = MockPostgresSecurityContext();
      // Setup initial profiles
      context.profiles['user-student-1'] = {
        'id': 'user-student-1',
        'email': 'student1@example.com',
        'role': 'student',
      };
      context.profiles['user-faculty-1'] = {
        'id': 'user-faculty-1',
        'email': 'faculty1@example.com',
        'role': 'faculty_mentor',
      };
      context.profiles['user-admin-1'] = {
        'id': 'user-admin-1',
        'email': 'admin1@example.com',
        'role': 'admin',
      };
    });

    test('Unauthenticated calls (NULL caller role) are always denied', () {
      // Caller has no session or role is NULL
      context.currentUserRole = null;

      expect(
        () => context.adminAssignUserRole(
          targetUserId: 'user-student-1',
          newRole: 'admin',
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains(
              'Access denied: Only administrators can assign elevated user roles.',
            ),
          ),
        ),
      );

      // Verify profile role remains unchanged
      expect(context.profiles['user-student-1']!['role'], equals('student'));
    });

    test('Student calls are denied when attempting to assign any role', () {
      // Caller has 'student' role
      context.currentUserRole = 'student';

      expect(
        () => context.adminAssignUserRole(
          targetUserId: 'user-student-1',
          newRole: 'faculty_mentor',
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains(
              'Access denied: Only administrators can assign elevated user roles.',
            ),
          ),
        ),
      );

      // Profile remains untouched
      expect(context.profiles['user-student-1']!['role'], equals('student'));
    });

    test('Faculty and T&P calls are denied (only admin can assign roles)', () {
      context.currentUserRole = 'faculty_mentor';

      expect(
        () => context.adminAssignUserRole(
          targetUserId: 'user-student-1',
          newRole: 'faculty_mentor',
        ),
        throwsA(predicate((e) => e.toString().contains('Access denied'))),
      );

      context.currentUserRole = 'tp_officer';

      expect(
        () => context.adminAssignUserRole(
          targetUserId: 'user-student-1',
          newRole: 'tp_officer',
        ),
        throwsA(predicate((e) => e.toString().contains('Access denied'))),
      );
    });

    test(
      'Admin calls succeed in assigning elevated roles to existing users',
      () {
        // Caller has verified 'admin' role
        context.currentUserRole = 'admin';

        // Promote student to faculty_mentor
        context.adminAssignUserRole(
          targetUserId: 'user-student-1',
          newRole: 'faculty_mentor',
        );
        expect(
          context.profiles['user-student-1']!['role'],
          equals('faculty_mentor'),
        );

        // Promote faculty to tp_officer
        context.adminAssignUserRole(
          targetUserId: 'user-student-1',
          newRole: 'tp_officer',
        );
        expect(
          context.profiles['user-student-1']!['role'],
          equals('tp_officer'),
        );
      },
    );

    test('Invalid roles are rejected with validation error', () {
      context.currentUserRole = 'admin';

      // Rejection of invalid role strings
      expect(
        () => context.adminAssignUserRole(
          targetUserId: 'user-student-1',
          newRole: 'superadmin',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => context.adminAssignUserRole(
          targetUserId: 'user-student-1',
          newRole: 'hacker',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => context.adminAssignUserRole(
          targetUserId: 'user-student-1',
          newRole: null,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () =>
            context.adminAssignUserRole(targetUserId: null, newRole: 'student'),
        throwsA(isA<ArgumentError>()),
      );

      // Role remains untouched
      expect(context.profiles['user-student-1']!['role'], equals('student'));
    });

    test(
      'Attempts by non-admin to self-assign elevated roles via RPC are blocked',
      () {
        // Student targets their own user ID
        context.currentUserRole = 'student';

        expect(
          () => context.adminAssignUserRole(
            targetUserId: 'user-student-1',
            newRole: 'admin',
          ),
          throwsA(predicate((e) => e.toString().contains('Access denied'))),
        );

        expect(context.profiles['user-student-1']!['role'], equals('student'));
      },
    );

    test('Attempts by self-signup to pass role in user metadata are ignored and default to student', () {
      // 1. Client-side sanitization strips role, app_role, roles, is_admin
      final maliciousMetadata = {
        'full_name': 'Sneaky Attacker',
        'role': 'admin',
        'app_role': 'admin',
        'roles': ['admin', 'superuser'],
        'is_admin': true,
        'isAdmin': true,
        'enrollment_no': 'ATTACK01',
      };

      final sanitized = AuthService.sanitizeSignupMetadata(maliciousMetadata);
      expect(sanitized!['role'], isNull);
      expect(sanitized['app_role'], isNull);
      expect(sanitized['roles'], isNull);
      expect(sanitized['is_admin'], isNull);
      expect(sanitized['isAdmin'], isNull);

      // 2. Even if an attacker directly called Supabase Auth with malicious raw_user_meta_data:
      context.handleNewUser(
        userId: 'user-attacker-1',
        email: 'attacker@example.com',
        rawUserMetaData: maliciousMetadata,
        rawAppMetaData: null, // No server-side app_metadata
      );

      // Verify that backend trigger strictly defaulted to 'student'
      final attackerProfile = context.profiles['user-attacker-1'];
      expect(attackerProfile, isNotNull);
      expect(attackerProfile!['role'], equals('student'));
    });

    test('Trusted server-controlled app metadata correctly provisions elevated roles', () {
      // Administrative server provisioning sets raw_app_meta_data
      context.handleNewUser(
        userId: 'user-new-faculty',
        email: 'newfaculty@college.edu',
        rawUserMetaData: {'full_name': 'Prof. Sharma'},
        rawAppMetaData: {'role': 'faculty_mentor'},
      );

      expect(
        context.profiles['user-new-faculty']!['role'],
        equals('faculty_mentor'),
      );

      context.handleNewUser(
        userId: 'user-new-tp',
        email: 'tp@college.edu',
        rawUserMetaData: {'full_name': 'T&P Officer'},
        rawAppMetaData: {'role': 'tp_officer'},
      );

      expect(context.profiles['user-new-tp']!['role'], equals('tp_officer'));
    });

    test(
      'Subsequent user profile updates never escalate role via ON CONFLICT',
      () {
        // Existing student user
        expect(context.profiles['user-student-1']!['role'], equals('student'));

        // User triggers auth update with attempted role in metadata
        context.handleNewUser(
          userId: 'user-student-1',
          email: 'student1@example.com',
          rawUserMetaData: {'role': 'admin', 'full_name': 'Updated Name'},
          rawAppMetaData: null,
        );

        // Role must still be 'student'
        expect(context.profiles['user-student-1']!['role'], equals('student'));
      },
    );
  });
}
