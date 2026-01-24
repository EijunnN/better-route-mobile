/// Driver information from /api/mobile/driver/my-route
class DriverInfo {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photo;
  final String? identification;
  final String status;
  final DriverLicense? license;

  const DriverInfo({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photo,
    this.identification,
    required this.status,
    this.license,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      photo: json['photo'] as String?,
      identification: json['identification'] as String?,
      status: json['status'] as String? ?? 'AVAILABLE',
      license: json['license'] != null
          ? DriverLicense.fromJson(json['license'] as Map<String, dynamic>)
          : null,
    );
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

/// Driver license information
class DriverLicense {
  final String? number;
  final DateTime? expiry;
  final List<String>? categories;

  const DriverLicense({
    this.number,
    this.expiry,
    this.categories,
  });

  /// Parse categories that can be either a String or List<String>
  static List<String>? _parseCategories(dynamic value) {
    if (value == null) return null;
    if (value is List) return List<String>.from(value);
    if (value is String) return value.isNotEmpty ? [value] : null;
    return null;
  }

  factory DriverLicense.fromJson(Map<String, dynamic> json) {
    return DriverLicense(
      number: json['number'] as String?,
      expiry: json['expiry'] != null
          ? DateTime.tryParse(json['expiry'] as String)
          : null,
      categories: _parseCategories(json['categories']),
    );
  }
}
