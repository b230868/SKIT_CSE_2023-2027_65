import '../../../core/config/role_config.dart';

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String role; // student | faculty | tnp | industry
  final String? enrollmentNo;
  final String? branch;
  final String? phone;
  final String? designation;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.enrollmentNo,
    this.branch,
    this.phone,
    this.designation,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, {required String email}) {
    return AppUser(
      id: map['id'] as String,
      fullName: (map['full_name'] ?? '') as String,
      email: email,
      role: (map['role'] ?? 'student') as String,
      enrollmentNo: map['enrollment_no'] as String?,
      branch: map['branch'] as String?,
      phone: map['phone'] as String?,
      designation: map['designation'] as String?,
    );
  }

  String get firstName {
    final name = fullName.trim();
    if (name.isEmpty) return 'there';
    return name.split(' ').first;
  }

  String get initial =>
      fullName.trim().isEmpty ? '?' : fullName.trim()[0].toUpperCase();

  String get roleLabel => RoleConfig.label(role);

  bool get isFaculty => RoleConfig.normalize(role) == AppRole.facultyMentor;

  bool get isTpOfficer => RoleConfig.normalize(role) == AppRole.tpOfficer;

  bool get isAdmin => RoleConfig.normalize(role) == AppRole.admin;

  bool get isStudent => RoleConfig.normalize(role) == AppRole.student;

  bool get isIndustry => RoleConfig.normalize(role) == AppRole.industrySupervisor;
}
