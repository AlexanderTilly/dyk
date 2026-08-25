/// A crowd-sourced pickpocket activity report. Auto-expires after 3 hours
/// (enforced server-side); the app only ever receives non-expired rows.
class PickpocketReport {
  final String id;
  final double lat;
  final double lng;
  final String? description;
  final DateTime createdAt;
  final DateTime expiresAt;

  PickpocketReport({
    required this.id,
    required this.lat,
    required this.lng,
    this.description,
    required this.createdAt,
    required this.expiresAt,
  });

  factory PickpocketReport.fromJson(Map<String, dynamic> json) =>
      PickpocketReport(
        id: json['id'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}
