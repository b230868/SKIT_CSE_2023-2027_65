import '../models/company_assignment_model.dart';

abstract class CompanyAssignmentRepository {
  /// Fetches all supervisors (role: 'industry' / 'industry_supervisor')
  /// along with their current verified company assignment from `industry_users`.
  Future<List<CompanyAssignmentUser>> getIndustrySupervisors();

  /// Fetches all verified companies from `public.industries`.
  Future<List<VerifiedCompany>> getVerifiedCompanies();

  /// Assigns a supervisor to a verified company in `public.industry_users`.
  /// Validates both IDs and handles duplicate mappings safely.
  Future<void> assignSupervisorToCompany({
    required String supervisorUserId,
    required String industryId,
  });

  /// Unassigns/revokes a supervisor's company assignment.
  Future<void> revokeSupervisorAssignment({required String supervisorUserId});
}
