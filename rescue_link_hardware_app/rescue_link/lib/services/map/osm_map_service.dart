import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/services/map/map_service.dart';

class OsmMapService implements MapService {
  const OsmMapService();

  @override
  Widget buildMap({
    required List<MapMarkerData> markers,
    required double centerLatitude,
    required double centerLongitude,
    double zoom = 15,
    void Function(MapMarkerData marker)? onMarkerTap,
  }) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(centerLatitude, centerLongitude),
        initialZoom: zoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rescuelink.rescue_link',
        ),
        MarkerLayer(
          markers: markers
              .map(
                (marker) => Marker(
                  point: LatLng(marker.latitude, marker.longitude),
                  width: marker.kind == MapMarkerKind.emergency ? 48 : 40,
                  height: marker.kind == MapMarkerKind.emergency ? 48 : 40,
                  child: GestureDetector(
                    onTap: onMarkerTap == null ? null : () => onMarkerTap(marker),
                    child: _MarkerIcon(marker: marker),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MarkerIcon extends StatelessWidget {
  final MapMarkerData marker;

  const _MarkerIcon({required this.marker});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (marker.kind) {
      MapMarkerKind.bike => (Colors.blue, Icons.directions_bike),
      MapMarkerKind.relay => (Colors.orange, Icons.cell_tower),
      MapMarkerKind.bluetooth => (Colors.green, Icons.router),
      MapMarkerKind.emergency => (AppTheme.criticalColor, Icons.warning),
    };

    return Tooltip(
      message: marker.label,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
