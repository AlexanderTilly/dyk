class HotDeal {
  final String id;
  final String businessName;
  final String offerText;
  final String? redeemCode;
  final double lat;
  final double lng;
  final int radiusMeters;

  const HotDeal({
    required this.id,
    required this.businessName,
    required this.offerText,
    this.redeemCode,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
  });

  factory HotDeal.fromJson(Map<String, dynamic> json) => HotDeal(
        id: json['id'] as String,
        businessName: json['business_name'] as String,
        offerText: json['offer_text'] as String,
        redeemCode: json['redeem_code'] as String?,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        radiusMeters: json['radius_meters'] as int,
      );
}
