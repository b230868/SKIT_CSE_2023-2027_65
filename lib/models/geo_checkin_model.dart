class GeoCheckIn {
  final String? id;
  final String studentId;
  final String internshipId;
  final double latitude;
  final double longitude;
  final double? locationAccuracy;
  final DateTime? checkInTime;

  const GeoCheckIn({
    this.id,
    required this.studentId,
    required this.internshipId,
    required this.latitude,
    required this.longitude,
    this.locationAccuracy,
    this.checkInTime,
  });

  factory GeoCheckIn.fromMap(Map<String, dynamic> map) {
    return GeoCheckIn(
      id: map['id']?.toString(),
      studentId: map['student_id']?.toString() ?? '',
      internshipId: map['internship_id']?.toString() ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      locationAccuracy:
          (map['location_accuracy'] as num?)?.toDouble(),
      checkInTime: map['check_in_time'] == null
          ? null
          : DateTime.tryParse(map['check_in_time'].toString()),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'student_id': studentId,
        'internship_id': internshipId,
        'latitude': latitude,
        'longitude': longitude,
        if (locationAccuracy != null) 'location_accuracy': locationAccuracy,
        if (checkInTime != null) 'check_in_time': checkInTime!.toIso8601String(),
      };
}
