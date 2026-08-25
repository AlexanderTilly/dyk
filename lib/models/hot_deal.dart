class HotDeal {
  final String id;
  final String businessName;
  final String offerText;
  final String? redeemCode;
  final String? description;
  final String? headerImage;
  final String category;
  final String redeemMode; // 'scan' | 'show'
  final List<String> images;
  final double lat;
  final double lng;
  final int radiusMeters;
  // Targeting
  final int minStepsToday;
  final String targetOnTour; // 'any' | 'exclude' | 'only'
  final List<int> activeDays; // 0 = Sunday … 6 = Saturday; empty = every day
  final int activeHourFrom;
  final int activeHourTo;
  final String targetArrival; // 'any' | 'new'
  final String? targetInterest;

  const HotDeal({
    required this.id,
    required this.businessName,
    required this.offerText,
    this.redeemCode,
    this.description,
    this.headerImage,
    this.category = 'restaurant',
    this.redeemMode = 'show',
    this.images = const [],
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    this.minStepsToday = 0,
    this.targetOnTour = 'exclude',
    this.activeDays = const [],
    this.activeHourFrom = 0,
    this.activeHourTo = 24,
    this.targetArrival = 'any',
    this.targetInterest,
  });

  factory HotDeal.fromJson(Map<String, dynamic> json) {
    final media = (json['deal_media'] as List?) ?? const [];
    final sorted = media
        .cast<Map<String, dynamic>>()
        .where((m) => m['media_type'] == 'image')
        .toList()
      ..sort((a, b) =>
          ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));
    return HotDeal(
      id: json['id'] as String,
      businessName: json['business_name'] as String,
      offerText: json['offer_text'] as String,
      redeemCode: json['redeem_code'] as String?,
      description: json['description'] as String?,
      headerImage: json['header_image'] as String?,
      category: (json['category'] as String?) ?? 'restaurant',
      redeemMode: (json['redeem_mode'] as String?) ?? 'show',
      images: sorted.map((m) => m['storage_path'] as String).toList(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusMeters: json['radius_meters'] as int,
      minStepsToday: (json['min_steps_today'] as num?)?.toInt() ?? 0,
      targetOnTour: (json['target_on_tour'] as String?) ?? 'exclude',
      activeDays: ((json['active_days'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      activeHourFrom: (json['active_hour_from'] as num?)?.toInt() ?? 0,
      activeHourTo: (json['active_hour_to'] as num?)?.toInt() ?? 24,
      targetArrival: (json['target_arrival'] as String?) ?? 'any',
      targetInterest: json['target_interest'] as String?,
    );
  }
}
