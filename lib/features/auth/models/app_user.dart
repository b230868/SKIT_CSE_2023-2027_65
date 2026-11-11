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

  String get roleLabel {
    switch (role.toLowerCase().trim()) {
      case 'faculty':
      case 'faculty_mentor':
      case 'facultymentor':
        return 'Faculty';
      case 'tnp':
      case 'tp_officer':
      case 'tpofficer':
        return 'Training & Placement';
      case 'industry':
      case 'industry_supervisor':
        return 'Industry';
      default:
        return 'Student';
    }
  }

  bool get isFaculty {
    final r = role.toLowerCase().trim();
    return r == 'faculty' || r == 'faculty_mentor' || r == 'facultymentor';
  }

  bool get isTpOfficer {
    final r = role.toLowerCase().trim();
    return r == 'tnp' || r == 'tp_officer' || r == 'tpofficer';
  }
}
