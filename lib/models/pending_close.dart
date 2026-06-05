/// A driver's stop close (COMPLETED / FAILED) captured locally so it survives
/// no-signal zones and app restarts, then syncs when connectivity returns.
///
/// One pending close per stop at a time — the stop id IS the entry id, so a
/// re-close simply replaces the queued entry (natural dedup).
class PendingClose {
  /// Equals [stopId] — a stop can only be closed once at a time.
  final String id;
  final String stopId;

  /// Order tracking id, needed to presign evidence uploads.
  final String trackingId;

  /// 'COMPLETED' | 'FAILED'.
  final String status;
  final String? failureReason;
  final String? notes;
  final Map<String, dynamic>? customFields;

  /// Device GPS captured at close time (works offline — the chip needs no
  /// network). Sent in the PATCH for the delivery-visit audit trail.
  final String? gpsLatitude;
  final String? gpsLongitude;

  /// Local photo files pending upload to R2.
  final List<String> photoPaths;

  /// path -> uploaded R2 public url. Lets a retry skip already-uploaded
  /// photos instead of re-uploading them (and creating orphan objects).
  final Map<String, String> uploadedByPath;

  final int createdAtMs;
  final int retryCount;

  const PendingClose({
    required this.id,
    required this.stopId,
    required this.trackingId,
    required this.status,
    required this.createdAtMs,
    this.failureReason,
    this.notes,
    this.customFields,
    this.gpsLatitude,
    this.gpsLongitude,
    this.photoPaths = const [],
    this.uploadedByPath = const {},
    this.retryCount = 0,
  });

  PendingClose copyWith({
    Map<String, String>? uploadedByPath,
    int? retryCount,
  }) {
    return PendingClose(
      id: id,
      stopId: stopId,
      trackingId: trackingId,
      status: status,
      createdAtMs: createdAtMs,
      failureReason: failureReason,
      notes: notes,
      customFields: customFields,
      gpsLatitude: gpsLatitude,
      gpsLongitude: gpsLongitude,
      photoPaths: photoPaths,
      uploadedByPath: uploadedByPath ?? this.uploadedByPath,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'stopId': stopId,
    'trackingId': trackingId,
    'status': status,
    'failureReason': failureReason,
    'notes': notes,
    'customFields': customFields,
    'gpsLatitude': gpsLatitude,
    'gpsLongitude': gpsLongitude,
    'photoPaths': photoPaths,
    'uploadedByPath': uploadedByPath,
    'createdAtMs': createdAtMs,
    'retryCount': retryCount,
  };

  factory PendingClose.fromJson(Map<String, dynamic> j) {
    return PendingClose(
      id: j['id'] as String,
      stopId: j['stopId'] as String,
      trackingId: j['trackingId'] as String,
      status: j['status'] as String,
      createdAtMs: (j['createdAtMs'] as num).toInt(),
      failureReason: j['failureReason'] as String?,
      notes: j['notes'] as String?,
      customFields: j['customFields'] != null
          ? Map<String, dynamic>.from(j['customFields'] as Map)
          : null,
      gpsLatitude: j['gpsLatitude'] as String?,
      gpsLongitude: j['gpsLongitude'] as String?,
      photoPaths: j['photoPaths'] != null
          ? List<String>.from(j['photoPaths'] as List)
          : const [],
      uploadedByPath: j['uploadedByPath'] != null
          ? Map<String, String>.from(j['uploadedByPath'] as Map)
          : const {},
      retryCount: (j['retryCount'] as num?)?.toInt() ?? 0,
    );
  }
}
