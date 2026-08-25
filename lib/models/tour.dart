class Tour {
  final String id;
  final String citypackId;
  final String type; // history_walk | food_drink | custom
  final String title;
  final String? subtitle;
  final String? description;
  final String? heroImage;
  final int priceCents;
  final bool isPublished;
  final int? distanceMeters;
  final int? estMinutes;
  final Map<String, dynamic>? routeGeojson;
  final String transportMode; // walking | cycling | driving | boat
  final String startMode; // fixed | hop_on
  final String? creatorName;
  final String? creatorHandle;
  final String? creatorAvatar;
  final String? creatorIntro;
  final String? ctaText;
  final String? ctaUrl;
  final List<String> checklist;
  final bool isTrending;
  final bool isPick;
  final List<Map<String, dynamic>> routeSteps; // precomputed turn-by-turn
  final int sortOrder;

  const Tour({
    required this.id,
    required this.citypackId,
    required this.type,
    required this.title,
    this.subtitle,
    this.description,
    this.heroImage,
    this.priceCents = 0,
    this.isPublished = false,
    this.distanceMeters,
    this.estMinutes,
    this.routeGeojson,
    this.transportMode = 'walking',
    this.startMode = 'fixed',
    this.creatorName,
    this.creatorHandle,
    this.creatorAvatar,
    this.creatorIntro,
    this.ctaText,
    this.ctaUrl,
    this.isCreatorFlag = false,
    this.checklist = const [],
    this.isTrending = false,
    this.isPick = false,
    this.routeSteps = const [],
    this.sortOrder = 0,
  });

  String get modeIcon => switch (transportMode) {
        'cycling' => '🚴',
        'driving' => '🚗',
        'boat' => '⛵',
        _ => '🚶',
      };

  bool get isFree => priceCents == 0;
  final bool isCreatorFlag;
  bool get isCreatorTour => isCreatorFlag || (creatorName ?? '').isNotEmpty;

  factory Tour.fromJson(Map<String, dynamic> json) => Tour(
        id: json['id'] as String,
        citypackId: json['citypack_id'] as String,
        type: (json['type'] as String?) ?? 'history_walk',
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        description: json['description'] as String?,
        heroImage: json['hero_image'] as String?,
        priceCents: (json['price_cents'] as int?) ?? 0,
        isPublished: (json['is_published'] as bool?) ?? false,
        distanceMeters: json['distance_meters'] as int?,
        estMinutes: json['est_minutes'] as int?,
        routeGeojson: json['route_geojson'] as Map<String, dynamic>?,
        transportMode: (json['transport_mode'] as String?) ?? 'walking',
        startMode: (json['start_mode'] as String?) ?? 'fixed',
        creatorName: json['creator_name'] as String?,
        creatorHandle: json['creator_handle'] as String?,
        creatorAvatar: json['creator_avatar'] as String?,
        creatorIntro: json['creator_intro'] as String?,
        ctaText: json['cta_text'] as String?,
        ctaUrl: json['cta_url'] as String?,
        isCreatorFlag: (json['is_creator'] as bool?) ?? false,
        checklist: ((json['checklist'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        routeSteps: ((json['route_steps'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
        sortOrder: (json['sort_order'] as int?) ?? 0,
        isTrending: (json['is_trending'] as bool?) ?? false,
        isPick: (json['is_pick'] as bool?) ?? false,
      );
}
