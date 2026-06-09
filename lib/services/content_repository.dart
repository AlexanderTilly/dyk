import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/hotspot.dart';

class ContentRepository {
  static const _assetPath = 'assets/data/hotspots.json';

  Future<List<Hotspot>> loadHotspots() async {
    final jsonString = await rootBundle.loadString(_assetPath);
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => Hotspot.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
