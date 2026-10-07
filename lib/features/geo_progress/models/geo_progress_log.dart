class GeoProgressLog {
  final String? id;
  final String clientRef;
  final String internshipId;
  final int progressPercent;
  final String taskSummary;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final DateTime capturedAt;
  final double? distanceFromSiteM;
  final bool? withinGeofence;
  final bool isPendingSync;

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

  factory GeoProgressLog.fromJson(Map<String, dynamic> j) => GeoProgressLog(
    id: j['id'] as String?,
    clientRef: j['client_ref'] as String,
    internshipId: j['internship_id'] as String,
    progressPercent: j['progress_percent'] as int,
    taskSummary: j['task_summary'] as String,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    accuracyM: (j['accuracy_m'] as num?)?.toDouble(),
    capturedAt: DateTime.parse(j['captured_at'] as String),
    distanceFromSiteM: (j['distance_from_site_m'] as num?)?.toDouble(),
    withinGeofence: j['within_geofence'] as bool?,
    isPendingSync: j['is_pending_sync'] as bool? ?? false,
  );

  /// Only client-owned fields; server computes geofence + student_id.
  Map<String, dynamic> toInsertJson() => {
    'client_ref': clientRef,
    'internship_id': internshipId,
    'progress_percent': progressPercent,
    'task_summary': taskSummary,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_m': accuracyM,
    'captured_at': capturedAt.toUtc().toIso8601String(),
  };
}
