import 'package:flutter/material.dart';

import '../theme.dart';

enum AppRole {
  student,
  facultyMentor,
  tpOfficer,
  industrySupervisor,
  admin,
}

class RoleConfig {
  static const String studentKey = 'student';
  static const String facultyKey = 'faculty_mentor';
  static const String tpKey = 'tp_officer';
  static const String industryKey = 'industry_supervisor';
  static const String adminKey = 'admin';

  static AppRole normalize(String? rawRole) {
    final r = (rawRole ?? '').toLowerCase().trim();
    if (r.contains('student')) return AppRole.student;
    if (r.contains('faculty')) return AppRole.facultyMentor;
    if (r.contains('tp') || r.contains('tnp')) return AppRole.tpOfficer;
    if (r.contains('industry')) return AppRole.industrySupervisor;
    if (r.contains('admin')) return AppRole.admin;
    return AppRole.student;
  }

  static String key(AppRole role) {
    switch (role) {
      case AppRole.student:
        return studentKey;
      case AppRole.facultyMentor:
        return facultyKey;
      case AppRole.tpOfficer:
        return tpKey;
      case AppRole.industrySupervisor:
        return industryKey;
      case AppRole.admin:
        return adminKey;
    }
  }

  static String label(String? rawRole) {
    switch (normalize(rawRole)) {
      case AppRole.student:
        return 'Student';
      case AppRole.facultyMentor:
        return 'Faculty Mentor';
      case AppRole.tpOfficer:
        return 'Training & Placement';
      case AppRole.industrySupervisor:
        return 'Industry Supervisor';
      case AppRole.admin:
        return 'System Administrator';
    }
  }

  static Color color(String? rawRole) {
    switch (normalize(rawRole)) {
      case AppRole.student:
        return const Color(0xFF3B82F6);
      case AppRole.facultyMentor:
        return const Color(0xFF10B981);
      case AppRole.tpOfficer:
        return const Color(0xFFF59E0B);
      case AppRole.industrySupervisor:
        return const Color(0xFF8B5CF6);
      case AppRole.admin:
        return AppTheme.ink;
    }
  }

  static IconData icon(String? rawRole) {
    switch (normalize(rawRole)) {
      case AppRole.student:
        return Icons.school_outlined;
      case AppRole.facultyMentor:
        return Icons.co_present_outlined;
      case AppRole.tpOfficer:
        return Icons.business_center_outlined;
      case AppRole.industrySupervisor:
        return Icons.apartment_outlined;
      case AppRole.admin:
        return Icons.admin_panel_settings_outlined;
    }
  }

  static bool isStaffOrFaculty(String? rawRole) {
    final role = normalize(rawRole);
    return role == AppRole.facultyMentor ||
        role == AppRole.tpOfficer ||
        role == AppRole.admin;
  }
}
