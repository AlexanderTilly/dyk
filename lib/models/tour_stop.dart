class TourStop {
  final String id;
  final String tourId;
  final int orderIndex;
  final String? hotspotId;
  final String? title;
  final String? blurb;
  final double? lat;
  final double? lng;
  final String? image;
  final String? audioPath;
  final String? offerText;
  final String? redeemCode;
  final int arrivalRadiusMeters;
  final int dwellMinutes; // suggested stay; 0 = quick stop
  final String? ctaText; // e.g. "Book your table" — belongs to the stop
  final String? ctaUrl;

  const TourStop({
    required this.id,
    required this.tourId,
    required this.orderIndex,
    this.hotspotId,
    this.title,
    this.blurb,
    this.lat,
    this.lng,
    this.image,
    this.audioPath,
    this.offerText,
    this.redeemCode,
    this.arrivalRadiusMeters = 40,
    this.dwellMinutes = 0,
    this.ctaText,
    this.ctaUrl,
  });

  /// A custom venue stop (tapas) carries its own content; a hotspot-linked
  /// stop defers to the hotspot.
  bool get isCustom => hotspotId == null;

  factory TourStop.fromJson(Map<String, dynamic> json) => TourStop(
        id: json['id'] as String,
        tourId: json['tour_id'] as String,
        orderIndex: (json['order_index'] as int?) ?? 0,
        hotspotId: json['hotspot_id'] as String?,
        title: json['title'] as String?,
        blurb: json['blurb'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        image: json['image'] as String?,
        audioPath: json['audio_path'] as String?,
        offerText: json['offer_text'] as String?,
        redeemCode: json['redeem_code'] as String?,
        arrivalRadiusMeters: (json['arrival_radius_meters'] as int?) ?? 40,
        dwellMinutes: (json['dwell_minutes'] as int?) ?? 0,
        ctaText: json['cta_text'] as String?,
        ctaUrl: json['cta_url'] as String?,
      );
}
