import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/student_monitoring_repository_factory.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/supabase_student_monitoring_repository.dart';

void main() {
  group('SupabaseStudentMonitoringRepository & Factory', () {
    test('SupabaseStudentMonitoringRepository does not throw UnimplementedError and returns list', () async {
      final repository = SupabaseStudentMonitoringRepository();
      final students = await repository.getStudents();

      expect(students, isNotNull);
      expect(students, isA<List>());
    });

    test(
      'StudentMonitoringRepositoryFactory creates repository instance safely',
      () {
        final repository = StudentMonitoringRepositoryFactory.create();
        expect(repository, isNotNull);
      },
    );
  });
}
