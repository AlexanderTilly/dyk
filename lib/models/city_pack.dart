class CityPack {
  final String id;
  final String name;
  final String city;
  final String country;
  final String description;
  final int priceSek;

  const CityPack({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.description,
    required this.priceSek,
  });

  factory CityPack.fromJson(Map<String, dynamic> json) => CityPack(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        country: json['country'] as String,
        description: (json['description'] as String?) ?? '',
        priceSek: (json['price_sek'] as int?) ?? 0,
      );
}
