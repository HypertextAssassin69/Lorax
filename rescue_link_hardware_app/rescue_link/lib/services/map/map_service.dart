import 'package:flutter/material.dart';

enum MapMarkerKind { bike, relay, bluetooth, emergency }

class MapMarkerData {
  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final MapMarkerKind kind;

  const MapMarkerData({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.kind,
  });
}

/// Abstraction so the UI is not tied to flutter_map / OSM.
/// An offline implementation can be swapped in later.
abstract class MapService {
  Widget buildMap({
    required List<MapMarkerData> markers,
    required double centerLatitude,
    required double centerLongitude,
    double zoom = 15,
    void Function(MapMarkerData marker)? onMarkerTap,
  });
}
