class InternalAd {
  final String id;
  final String title;
  final String? subtitle;
  final String? iconUrl;
  final String? imageUrl;
  final double targetLat;
  final double targetLng;
  final double radiusKm;
  final String? linkUrl;

  const InternalAd({
    required this.id,
    required this.title,
    this.subtitle,
    this.iconUrl,
    this.imageUrl,
    required this.targetLat,
    required this.targetLng,
    required this.radiusKm,
    this.linkUrl,
  });

  factory InternalAd.fromJson(Map<String, dynamic> json) => InternalAd(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        iconUrl: json['icon_url'] as String?,
        imageUrl: json['image_url'] as String?,
        targetLat: (json['target_lat'] as num).toDouble(),
        targetLng: (json['target_lng'] as num).toDouble(),
        radiusKm: (json['radius_km'] as num).toDouble(),
        linkUrl: json['link_url'] as String?,
      );
}
