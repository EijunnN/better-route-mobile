/// Vehicle information from the backend
class Vehicle {
  final String id;
  final String name;
  final String? plate;
  final String? brand;
  final String? model;
  final int? maxOrders;
  final VehicleOrigin? origin;

  const Vehicle({
    required this.id,
    required this.name,
    this.plate,
    this.brand,
    this.model,
    this.maxOrders,
    this.origin,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      name: json['name'] as String,
      plate: json['plate'] as String?,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      maxOrders: json['maxOrders'] as int?,
      origin: json['origin'] != null
          ? VehicleOrigin.fromJson(json['origin'] as Map<String, dynamic>)
          : null,
    );
  }

  String get displayName {
    if (plate != null && plate!.isNotEmpty) {
      return '$name ($plate)';
    }
    return name;
  }

  String get vehicleDescription {
    final parts = <String>[];
    if (brand != null) parts.add(brand!);
    if (model != null) parts.add(model!);
    return parts.isNotEmpty ? parts.join(' ') : 'Vehiculo';
  }
}

/// Vehicle origin location
class VehicleOrigin {
  final String? address;
  final double? latitude;
  final double? longitude;

  const VehicleOrigin({
    this.address,
    this.latitude,
    this.longitude,
  });

  /// Parse coordinate that can be either String or num
  static double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  factory VehicleOrigin.fromJson(Map<String, dynamic> json) {
    return VehicleOrigin(
      address: json['address'] as String?,
      latitude: _parseCoordinate(json['latitude']),
      longitude: _parseCoordinate(json['longitude']),
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;
}
