class CompanyAssignmentUser {
  final String id;
  final String fullName;
  final String email;
  final String? requestedCompanyName;
  final String? assignedIndustryId;
  final String? assignedIndustryName;

  const CompanyAssignmentUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.requestedCompanyName,
    this.assignedIndustryId,
    this.assignedIndustryName,
  });

  bool get isAssigned =>
      assignedIndustryId != null && assignedIndustryId!.isNotEmpty;
}

class VerifiedCompany {
  final String id;
  final String name;

  const VerifiedCompany({required this.id, required this.name});
}
