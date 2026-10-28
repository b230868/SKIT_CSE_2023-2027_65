import '../features/internship/models/internship.dart';

class Application {
  final Internship internship;

  const Application(this.internship);

  String get id => internship.id;
  String get status => internship.status;
  DateTime get appliedAt => internship.createdAt;

  factory Application.fromMap(Map<String, dynamic> row) {
    final internshipData = row['internships'] is Map<String, dynamic>
        ? row['internships'] as Map<String, dynamic>
        : row;
    return Application(Internship.fromMap(internshipData));
  }
}
