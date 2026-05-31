/// Stop status enum matching backend
enum StopStatus {
  pending('PENDING'),
  inProgress('IN_PROGRESS'),
  completed('COMPLETED'),
  failed('FAILED');

  final String value;
  const StopStatus(this.value);

  static StopStatus fromString(String? value) {
    return StopStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => StopStatus.pending,
    );
  }

  bool get isPending => this == StopStatus.pending;
  bool get isInProgress => this == StopStatus.inProgress;
  bool get isCompleted => this == StopStatus.completed;
  bool get isFailed => this == StopStatus.failed;
  bool get isDone => isCompleted || isFailed;
}

// NOTE: there is intentionally no `FailureReason` enum. Failure reasons
// are per-company free-text Spanish strings from the delivery policy
// (`GET /api/mobile/driver/delivery-policy` → `policy.failureReasons`).
// `route_stops.failureReason` stores the selected string verbatim.

/// Time window for delivery
class TimeWindow {
  final DateTime? start;
  final DateTime? end;

  const TimeWindow({this.start, this.end});

  factory TimeWindow.fromJson(Map<String, dynamic> json) {
    return TimeWindow(
      start: json['start'] != null
          ? DateTime.tryParse(json['start'] as String)
          : null,
      end: json['end'] != null ? DateTime.tryParse(json['end'] as String) : null,
    );
  }

  bool get hasWindow => start != null || end != null;

  String get displayText {
    if (!hasWindow) return 'Sin ventana horaria';

    String fmt(DateTime dt) {
      final local = dt.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final startStr = start != null ? fmt(start!) : '--:--';
    final endStr = end != null ? fmt(end!) : '--:--';

    return '$startStr - $endStr';
  }
}

/// Order information within a stop
class OrderInfo {
  final String id;
  final String? trackingId;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? notes;
  final double? weight;
  final double? volume;
  final double? value;
  final int? units;
  final Map<String, dynamic> customFields;

  const OrderInfo({
    required this.id,
    this.trackingId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.notes,
    this.weight,
    this.volume,
    this.value,
    this.units,
    this.customFields = const {},
  });

  factory OrderInfo.fromJson(Map<String, dynamic> json) {
    return OrderInfo(
      id: json['id'] as String,
      trackingId: json['trackingId'] as String?,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      customerEmail: json['customerEmail'] as String?,
      notes: json['notes'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toDouble(),
      value: (json['value'] as num?)?.toDouble(),
      units: json['units'] as int?,
      customFields: json['customFields'] != null
          ? Map<String, dynamic>.from(json['customFields'] as Map)
          : const {},
    );
  }

  bool get hasContactInfo =>
      (customerPhone != null && customerPhone!.isNotEmpty) ||
      (customerEmail != null && customerEmail!.isNotEmpty);

  bool get hasCustomFields => customFields.isNotEmpty;
}

/// Route stop model matching backend response
class RouteStop {
  final String id;
  final int sequence;
  final StopStatus status;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime? estimatedArrival;
  final int? estimatedServiceTime;
  final TimeWindow? timeWindow;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  final String? failureReason;
  final List<String>? evidenceUrls;
  final OrderInfo? order;
  /// Values captured by the driver for fields with entity=route_stops.
  /// Backend stores them in `route_stops.custom_fields` (jsonb). Distinct
  /// from `order?.customFields` which lives on `orders.custom_fields` and
  /// is read-only for the driver (filled by the operator at order creation).
  final Map<String, dynamic>? customFields;
  /// 1 = primer intento; 2+ = revisita. Se construye en el backend
  /// considerando tanto el `route_stops.attempt_number` como el conteo
  /// de `delivery_visits` previas del Order, para que un same-day reopen
  /// también cuente como reintento.
  final int attemptNumber;
  /// Visitas previas registradas para el Order (sin contar la del Stop
  /// actual cuando ya es terminal). Útil para mensajes contextuales
  /// ("Este pedido ya tuvo N intentos fallidos").
  final int priorVisitsCount;
  /// `true` cuando el Stop debe presentarse como revisita en la UI.
  final bool isRevisit;

  const RouteStop({
    required this.id,
    required this.sequence,
    required this.status,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.estimatedArrival,
    this.estimatedServiceTime,
    this.timeWindow,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.failureReason,
    this.evidenceUrls,
    this.order,
    this.customFields,
    this.attemptNumber = 1,
    this.priorVisitsCount = 0,
    this.isRevisit = false,
  });

  /// Parse latitude/longitude that can be either String or num
  static double _parseCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      id: json['id'] as String,
      sequence: json['sequence'] as int,
      status: StopStatus.fromString(json['status'] as String?),
      address: json['address'] as String,
      latitude: _parseCoordinate(json['latitude']),
      longitude: _parseCoordinate(json['longitude']),
      estimatedArrival: json['estimatedArrival'] != null
          ? DateTime.tryParse(json['estimatedArrival'] as String)
          : null,
      estimatedServiceTime: json['estimatedServiceTime'] as int?,
      timeWindow: json['timeWindow'] != null
          ? TimeWindow.fromJson(json['timeWindow'] as Map<String, dynamic>)
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      notes: json['notes'] as String?,
      failureReason: json['failureReason'] as String?,
      evidenceUrls: json['evidenceUrls'] != null
          ? List<String>.from(json['evidenceUrls'] as List)
          : null,
      order: json['order'] != null
          ? OrderInfo.fromJson(json['order'] as Map<String, dynamic>)
          : null,
      customFields: json['customFields'] != null
          ? Map<String, dynamic>.from(json['customFields'] as Map)
          : null,
      attemptNumber: (json['attemptNumber'] as num?)?.toInt() ?? 1,
      priorVisitsCount: (json['priorVisitsCount'] as num?)?.toInt() ?? 0,
      isRevisit: json['isRevisit'] as bool? ?? false,
    );
  }

  /// Display name for the stop
  String get displayName {
    return order?.customerName ?? 'Parada #$sequence';
  }

  /// Tracking ID or fallback
  String get trackingDisplay {
    return order?.trackingId ?? 'N/A';
  }

  /// Estimated arrival time formatted
  String get arrivalTimeDisplay {
    if (estimatedArrival == null) return '--:--';
    final local = estimatedArrival!.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// Copy with new status
  RouteStop copyWith({
    String? id,
    int? sequence,
    StopStatus? status,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? estimatedArrival,
    int? estimatedServiceTime,
    TimeWindow? timeWindow,
    DateTime? startedAt,
    DateTime? completedAt,
    String? notes,
    String? failureReason,
    List<String>? evidenceUrls,
    OrderInfo? order,
    Map<String, dynamic>? customFields,
    int? attemptNumber,
    int? priorVisitsCount,
    bool? isRevisit,
  }) {
    return RouteStop(
      id: id ?? this.id,
      sequence: sequence ?? this.sequence,
      status: status ?? this.status,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      estimatedServiceTime: estimatedServiceTime ?? this.estimatedServiceTime,
      timeWindow: timeWindow ?? this.timeWindow,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      failureReason: failureReason ?? this.failureReason,
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
      order: order ?? this.order,
      customFields: customFields ?? this.customFields,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      priorVisitsCount: priorVisitsCount ?? this.priorVisitsCount,
      isRevisit: isRevisit ?? this.isRevisit,
    );
  }
}
