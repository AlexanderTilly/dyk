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

  /// The venue door, if the advertiser gave one. Deliberately not
  /// targetLat/targetLng: those say where the ad is SHOWN, and walking
  /// someone to the centre of a display radius puts them on the wrong
  /// street. No door means no "take me there" button.
  final double? destLat;
  final double? destLng;
  final String? destLabel;

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
    this.destLat,
    this.destLng,
    this.destLabel,
  });

  /// Whether this ad can be navigated to.
  bool get hasDestination => destLat != null && destLng != null;

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
        destLat: (json['dest_lat'] as num?)?.toDouble(),
        destLng: (json['dest_lng'] as num?)?.toDouble(),
        destLabel: json['dest_label'] as String?,
      );
}
