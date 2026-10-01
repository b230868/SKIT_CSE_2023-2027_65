import '../features/internship/data/internship_service.dart';
import '../models/student_models.dart';

class StudentService {
  final InternshipService _internships = InternshipService();

  Future<List<Application>> myApplications() async {
    final internships = await _internships.fetchMine();
    return internships.map(Application.new).toList();
  }
}
