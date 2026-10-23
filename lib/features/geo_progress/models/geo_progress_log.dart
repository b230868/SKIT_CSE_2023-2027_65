class GeoProgressLog {
  final String? id;
  final String clientRef;
  final String internshipId;
  final int progressPercent;
  final String taskSummary;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final DateTime capturedAt;
  final double? distanceFromSiteM;
  final bool? withinGeofence;
  final bool isPendingSync;

  int get percent => progressPercent;
  String get note => taskSummary;
  DateTime get createdAt => capturedAt;

  const GeoProgressLog({
    this.id,
    required this.clientRef,
    required this.internshipId,
    required this.progressPercent,
    required this.taskSummary,
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    required this.capturedAt,
    this.distanceFromSiteM,
    this.withinGeofence,
    this.isPendingSync = false,
  });

  int get percent => progressPercent;
  String get note => taskSummary;
  DateTime get createdAt => capturedAt;

  factory GeoProgressLog.fromJson(Map<String, dynamic> j) => GeoProgressLog(
    id: j['id'] as String?,
    clientRef: j['client_ref'] as String,
    internshipId: j['internship_id'] as String,
    progressPercent: (j['progress_percent'] ?? j['percent']) as int,
    taskSummary: (j['task_summary'] ?? j['note']) as String,
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    accuracyM: (j['accuracy_m'] as num?)?.toDouble(),
    capturedAt: DateTime.parse((j['captured_at'] ?? j['created_at']) as String),
    distanceFromSiteM: (j['distance_from_site_m'] as num?)?.toDouble(),
    withinGeofence: j['within_geofence'] as bool?,
    isPendingSync: j['is_pending_sync'] as bool? ?? false,
  );

  /// Uses the existing progress_updates table; student_id is added by the
  /// service from the authenticated session, never from cached input.
  Map<String, dynamic> toInsertJson() => {
    'client_ref': clientRef,
    'internship_id': internshipId,
    'percent': progressPercent,
    'note': taskSummary,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_m': accuracyM,
    'captured_at': capturedAt.toUtc().toIso8601String(),
  };
}
