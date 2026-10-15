import '../features/internship/models/internship.dart';

class Application {
  final Internship internship;

  const Application(this.internship);

  String get id => internship.id;
  String get status => internship.status;
  DateTime get appliedAt => internship.createdAt;
}
