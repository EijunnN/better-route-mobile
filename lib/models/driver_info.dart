/// Driver information from /api/mobile/driver/my-route
class DriverInfo {
  final String id;
  final String name;

  const DriverInfo({
    required this.id,
    required this.name,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}
