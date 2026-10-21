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

  /// 'ad' or 'event'. Events are the same row shape with a time attached, so
  /// they share this table; see migration 053.
  final String kind;

  /// Null on an ad. On an event, null `endsAt` means open-ended rather than
  /// finished — a permanent installation has a start and no end.
  final DateTime? startsAt;
  final DateTime? endsAt;

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
    this.kind = 'ad',
    this.startsAt,
    this.endsAt,
  });

  /// Whether this ad can be navigated to.
  bool get hasDestination => destLat != null && destLng != null;

  bool get isEvent => kind == 'event';

  /// An event is over once its end has passed. A null end never expires —
  /// that is the open-ended case, not a missing value to guess at.
  bool isOver(DateTime now) => endsAt != null && endsAt!.isBefore(now);

  /// Shown on the map from the moment it is created until it is over. We do
  /// not hide an event before it starts: a tourist walking past today wants
  /// to know about Thursday's concert, which is the whole point of putting
  /// it on a map.
  bool showsOn(DateTime now) => isEvent && !isOver(now);

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
        kind: (json['kind'] as String?) ?? 'ad',
        startsAt: DateTime.tryParse((json['starts_at'] as String?) ?? ''),
        endsAt: DateTime.tryParse((json['ends_at'] as String?) ?? ''),
      );
}
