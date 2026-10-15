import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/industry_dashboard_data.dart';

void main() {
  group('IndustryDashboardData Unit Tests', () {
    test('calculates correct completion, submission, and evaluation rates', () {
      const data = IndustryDashboardData(
        industryName: 'Google Cloud Labs',
        totalInterns: 20,
        activeInterns: 12,
        completedInternships: 8,
        pendingItrs: 4,
        submittedItrs: 16,
        pendingEvaluations: 6,
        completedEvaluations: 10,
      );

      expect(data.completionRate, equals(40.0)); // 8 / 20 * 100
      expect(data.itrSubmissionRate, equals(80.0)); // 16 / 20 * 100
      expect(data.evaluationRate, equals(62.5)); // 10 / 16 * 100
    });

    test('handles zero interns without divide-by-zero errors', () {
      final empty = IndustryDashboardData.empty('Empty Org');

      expect(empty.industryName, equals('Empty Org'));
      expect(empty.totalInterns, equals(0));
      expect(empty.completionRate, equals(0.0));
      expect(empty.itrSubmissionRate, equals(0.0));
      expect(empty.evaluationRate, equals(0.0));
    });

    test('serializes toMap and deserializes fromMap correctly', () {
      const original = IndustryDashboardData(
        industryName: 'Siemens Healthineers',
        totalInterns: 15,
        activeInterns: 10,
        completedInternships: 5,
        pendingItrs: 2,
        submittedItrs: 13,
        pendingEvaluations: 3,
        completedEvaluations: 10,
      );

      final map = original.toMap();
      final reconstructed = IndustryDashboardData.fromMap(map);

      expect(reconstructed.industryName, equals(original.industryName));
      expect(reconstructed.totalInterns, equals(original.totalInterns));
      expect(reconstructed.activeInterns, equals(original.activeInterns));
      expect(
        reconstructed.completedInternships,
        equals(original.completedInternships),
      );
      expect(reconstructed.pendingItrs, equals(original.pendingItrs));
      expect(reconstructed.submittedItrs, equals(original.submittedItrs));
      expect(
        reconstructed.pendingEvaluations,
        equals(original.pendingEvaluations),
      );
      expect(
        reconstructed.completedEvaluations,
        equals(original.completedEvaluations),
      );
    });
  });
}
