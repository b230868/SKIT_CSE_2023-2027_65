import '../models/company_assignment_model.dart';
import 'company_assignment_repository.dart';

class MockCompanyAssignmentRepository implements CompanyAssignmentRepository {
  final List<VerifiedCompany> companies;
  final List<CompanyAssignmentUser> supervisors;

  MockCompanyAssignmentRepository({
    List<VerifiedCompany>? companies,
    List<CompanyAssignmentUser>? supervisors,
  }) : companies =
           companies ??
           [
             const VerifiedCompany(id: 'comp-111', name: 'TechNova Solutions'),
             const VerifiedCompany(id: 'comp-222', name: 'DataCorp India'),
             const VerifiedCompany(id: 'comp-333', name: 'InnoTech Systems'),
           ],
       supervisors =
           supervisors ??
           [
             const CompanyAssignmentUser(
               id: 'sup-1',
               fullName: 'Amit Saxena',
               email: 'amit@technova.com',
               requestedCompanyName: 'TechNova Solutions',
               assignedIndustryId: 'comp-111',
               assignedIndustryName: 'TechNova Solutions',
             ),
             const CompanyAssignmentUser(
               id: 'sup-2',
               fullName: 'Priya Sharma',
               email: 'priya@datacorp.com',
               requestedCompanyName: 'DataCorp India',
               assignedIndustryId: 'comp-222',
               assignedIndustryName: 'DataCorp India',
             ),
             const CompanyAssignmentUser(
               id: 'sup-unassigned',
               fullName: 'Karan Mehra (New Sign-up)',
               email: 'karan@newcorp.com',
               requestedCompanyName:
                   'TechNova Solutions', // unverified self-entered name
               assignedIndustryId: null, // RESTRICTED / UNASSIGNED
               assignedIndustryName: null,
             ),
           ];

  @override
  Future<List<VerifiedCompany>> getVerifiedCompanies() async {
    return List.from(companies);
  }

  @override
  Future<List<CompanyAssignmentUser>> getIndustrySupervisors() async {
    return List.from(supervisors);
  }

  @override
  Future<void> assignSupervisorToCompany({
    required String supervisorUserId,
    required String industryId,
  }) async {
    if (supervisorUserId.trim().isEmpty) {
      throw ArgumentError('Invalid supervisor user ID.');
    }
    final comp = companies.cast<VerifiedCompany?>().firstWhere(
      (c) => c?.id == industryId,
      orElse: () => null,
    );
    if (comp == null) {
      throw ArgumentError('Specified verified company does not exist.');
    }

    final idx = supervisors.indexWhere((s) => s.id == supervisorUserId);
    if (idx < 0) {
      throw ArgumentError('Specified supervisor user does not exist.');
    }

    final existing = supervisors[idx];
    supervisors[idx] = CompanyAssignmentUser(
      id: existing.id,
      fullName: existing.fullName,
      email: existing.email,
      requestedCompanyName: existing.requestedCompanyName,
      assignedIndustryId: comp.id,
      assignedIndustryName: comp.name,
    );
  }

  @override
  Future<void> revokeSupervisorAssignment({
    required String supervisorUserId,
  }) async {
    final idx = supervisors.indexWhere((s) => s.id == supervisorUserId);
    if (idx >= 0) {
      final existing = supervisors[idx];
      supervisors[idx] = CompanyAssignmentUser(
        id: existing.id,
        fullName: existing.fullName,
        email: existing.email,
        requestedCompanyName: existing.requestedCompanyName,
        assignedIndustryId: null,
        assignedIndustryName: null,
      );
    }
  }
}
