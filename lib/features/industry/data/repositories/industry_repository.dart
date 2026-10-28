import '../../../internship/models/internship.dart';
import '../models/industry_attendance_model.dart';
import '../models/industry_dashboard_data.dart';
import '../models/industry_internship_model.dart';

abstract class IndustryRepository {
  Future<List<IndustryInternshipModel>> getIndustryInternships();

  Future<IndustryDashboardData> getDashboardData();

  // Attendance management
  Future<List<IndustryAttendanceRecord>> getAttendanceRecords(
    String internshipId,
  );

  Future<void> markAttendance({
    required String internshipId,
    required String studentId,
    required DateTime date,
    required String status,
    String? remarks,
  });

  // Document management: Offer Letters
  Future<void> updateOfferLetter({
    required String internshipId,
    required String status,
    String? fileUrl,
  });

  // Document management: Certificates
  Future<void> updateCertificate({
    required String internshipId,
    required String status,
    String? fileUrl,
  });

  // Student-Uploaded Document Verification
  Future<List<InternshipDocument>> getStudentDocuments(String internshipId);

  Future<void> verifyStudentDocument({
    required String documentId,
    required String status,
    String? rejectionReason,
    String? remarks,
  });
}
