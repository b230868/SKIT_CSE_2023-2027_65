class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String role; // student | faculty | tnp | industry
  final String? enrollmentNo;
  final String? branch;
  final String? phone;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.enrollmentNo,
    this.branch,
    this.phone,
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
    );
  }

  String get firstName {
    final name = fullName.trim();
    if (name.isEmpty) return 'there';
    return name.split(' ').first;
  }

  String get initial => fullName.trim().isEmpty ? '?' : fullName.trim()[0].toUpperCase();

  String get roleLabel {
    switch (role) {
      case 'faculty':
        return 'Faculty';
      case 'tnp':
        return 'Training & Placement';
      case 'industry':
        return 'Industry';
      default:
        return 'Student';
    }
  }
}
