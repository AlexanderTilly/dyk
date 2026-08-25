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
  // Optional caption per image, aligned by index with [images].
  final List<String?> imageCaptions;
  final String year;
  final String category; // history | otium | funfact | headline
  final String? subcategory; // building | work_of_art | ... (drives pin icon)
  final bool isFree;
  final List<String> facts;
  final List<String> videos;

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
    this.imageCaptions = const [],
    required this.year,
    this.category = 'history',
    this.subcategory,
    this.isFree = false,
    this.facts = const [],
    this.videos = const [],
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
      year: json['year']?.toString() ?? '',
      category: (json['category'] as String?) ?? 'history',
      subcategory: json['subcategory'] as String?,
      isFree: (json['is_free'] as bool?) ?? false,
    );
  }

  Hotspot copyWith({
    List<String>? images,
    List<String?>? imageCaptions,
    String? audioFile,
    List<String>? facts,
    List<String>? videos,
  }) =>
      Hotspot(
        id: id,
        name: name,
        subtitle: subtitle,
        description: description,
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        audioFile: audioFile ?? this.audioFile,
        images: images ?? this.images,
        imageCaptions: imageCaptions ?? this.imageCaptions,
        year: year,
        category: category,
        subcategory: subcategory,
        isFree: isFree,
        facts: facts ?? this.facts,
        videos: videos ?? this.videos,
      );

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
