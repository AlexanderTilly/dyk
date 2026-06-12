class Hotspot {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final double lat;
  final double lng;
  final int radiusMeters;
  final String audioFile;
  final List<String> images;
  final int year;
  final String category; // history | funfact | headline
  final bool isFree;

  const Hotspot({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.audioFile,
    required this.images,
    required this.year,
    this.category = 'history',
    this.isFree = false,
  });

  factory Hotspot.fromJson(Map<String, dynamic> json) {
    return Hotspot(
      id: json['id'] as String,
      name: json['name'] as String,
      subtitle: (json['subtitle'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusMeters: json['radius_meters'] as int,
      audioFile: (json['audio_file'] as String?) ?? '',
      images: json['images'] != null ? List<String>.from(json['images'] as List) : const [],
      year: (json['year'] as int?) ?? 0,
      category: (json['category'] as String?) ?? 'history',
      isFree: (json['is_free'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'description': description,
        'lat': lat,
        'lng': lng,
        'radius_meters': radiusMeters,
        'audio_file': audioFile,
        'images': images,
        'year': year,
        'category': category,
        'is_free': isFree,
      };
}
