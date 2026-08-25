class CityPack {
  final String id;
  final String name;
  final String city;
  final String country;
  final String? countryCode; // ISO 3166-1 alpha-2, e.g. 'ES'
  final String description;
  final int priceCents;
  final double? lat;
  final double? lng;
  final int welcomeRadiusKm;
  final String? headerImage; // resolved public URL (Tours tab hero)

  const CityPack({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    this.countryCode,
    required this.description,
    required this.priceCents,
    this.lat,
    this.lng,
    this.welcomeRadiusKm = 30,
    this.headerImage,
  });

  /// Emoji flag from the ISO code (renders natively on Android/iOS).
  String get flag {
    final cc = countryCode;
    if (cc == null || cc.length != 2) return '';
    return String.fromCharCodes(
        cc.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65));
  }

  factory CityPack.fromJson(Map<String, dynamic> json) => CityPack(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        country: json['country'] as String,
        countryCode: json['country_code'] as String?,
        description: (json['description'] as String?) ?? '',
        priceCents: (json['price_cents'] as int?) ?? 0,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        welcomeRadiusKm: (json['welcome_radius_km'] as int?) ?? 30,
        headerImage: json['header_image'] as String?,
      );
}
