import '../features/internship/data/internship_service.dart';
import '../models/student_models.dart';

abstract interface class StudentDataSource {
  Future<List<Application>> myApplications();
}

class StudentService implements StudentDataSource {
  final InternshipService _internships = InternshipService();

  @override
  Future<List<Application>> myApplications() async {
    final internships = await _internships.fetchMine();
    return internships.map(Application.new).toList();
  }
}
