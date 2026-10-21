import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/mock_company_assignment_repository.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/company_assignment_screen.dart';

void main() {
  group('Company Assignment Workflow Unit & Widget Tests', () {
    late MockCompanyAssignmentRepository repo;

    setUp(() {
      repo = MockCompanyAssignmentRepository();
    });

    test(
      'Initial supervisor state distinguishes verified assigned vs unassigned',
      () async {
        final sups = await repo.getIndustrySupervisors();

        final assigned = sups.firstWhere((s) => s.id == 'sup-1');
        expect(assigned.isAssigned, isTrue);
        expect(assigned.assignedIndustryName, equals('TechNova Solutions'));

        final unassigned = sups.firstWhere((s) => s.id == 'sup-unassigned');
        expect(unassigned.isAssigned, isFalse);
        expect(unassigned.assignedIndustryId, isNull);
        expect(unassigned.requestedCompanyName, equals('TechNova Solutions'));
      },
    );

    test(
      'Admin successfully assigns verified company to unassigned supervisor',
      () async {
        await repo.assignSupervisorToCompany(
          supervisorUserId: 'sup-unassigned',
          industryId: 'comp-111',
        );

        final sups = await repo.getIndustrySupervisors();
        final updated = sups.firstWhere((s) => s.id == 'sup-unassigned');

        expect(updated.isAssigned, isTrue);
        expect(updated.assignedIndustryId, equals('comp-111'));
        expect(updated.assignedIndustryName, equals('TechNova Solutions'));
      },
    );

    test(
      'Assigning with non-existent company ID throws ArgumentError',
      () async {
        expect(
          () => repo.assignSupervisorToCompany(
            supervisorUserId: 'sup-unassigned',
            industryId: 'non-existent-comp',
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('Revoking supervisor assignment resets access to restricted/unassigned state', () async {
      await repo.revokeSupervisorAssignment(supervisorUserId: 'sup-1');

      final sups = await repo.getIndustrySupervisors();
      final revoked = sups.firstWhere((s) => s.id == 'sup-1');

      expect(revoked.isAssigned, isFalse);
      expect(revoked.assignedIndustryId, isNull);
      expect(revoked.assignedIndustryName, isNull);
    });

    testWidgets(
      'CompanyAssignmentScreen renders supervisor cards and pending badges',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: CompanyAssignmentScreen(repository: repo)),
        );
        await tester.pumpAndSettle();

        // Check title and contents
        expect(find.text('Industry Company Assignment'), findsOneWidget);
        expect(find.text('Amit Saxena'), findsOneWidget);
        expect(find.text('Karan Mehra (New Sign-up)'), findsOneWidget);

        // Status badges
        expect(find.text('VERIFIED ASSIGNED'), findsNWidgets(2));
        expect(find.text('PENDING ASSIGNMENT'), findsOneWidget);

        // Buttons
        expect(find.text('Assign Company'), findsOneWidget);
        expect(find.text('Reassign'), findsNWidgets(2));
      },
    );

    testWidgets(
      'Admin can trigger assignment dialog and assign verified company via UI',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: CompanyAssignmentScreen(repository: repo)),
        );
        await tester.pumpAndSettle();

        // Tap 'Assign Company' on the unassigned user
        await tester.tap(find.widgetWithText(FilledButton, 'Assign Company'));
        await tester.pumpAndSettle();

        // Dialog opens
        expect(find.text('Assign Verified Company'), findsOneWidget);
        expect(
          find.text('Supervisor: Karan Mehra (New Sign-up)'),
          findsOneWidget,
        );
        expect(find.text('Confirm Assignment'), findsOneWidget);

        // Tap Confirm Assignment
        await tester.tap(find.text('Confirm Assignment'));
        await tester.pumpAndSettle();

        // Verified assigned badges should now be 3
        expect(find.text('VERIFIED ASSIGNED'), findsNWidgets(3));
        expect(find.text('PENDING ASSIGNMENT'), findsNothing);
      },
    );
  });
}
