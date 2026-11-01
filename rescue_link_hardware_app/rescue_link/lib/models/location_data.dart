import 'package:equatable/equatable.dart';
import 'package:rescue_link/core/enums/enums.dart';

class LocationData extends Equatable {
  final double latitude;
  final double longitude;
  final double altitude;
  final DateTime timestamp;
  final double accuracy;
  final int satellites;
  final GpsFixStatus fixStatus;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.timestamp,
    required this.accuracy,
    required this.satellites,
    required this.fixStatus,
  });

  String get displayString => '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  LocationData copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    DateTime? timestamp,
    double? accuracy,
    int? satellites,
    GpsFixStatus? fixStatus,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      satellites: satellites ?? this.satellites,
      fixStatus: fixStatus ?? this.fixStatus,
    );
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      accuracy: (json['accuracy'] as num).toDouble(),
      satellites: json['satellites'] as int,
      fixStatus: GpsFixStatus.values.firstWhere(
        (e) => e.name == json['fixStatus'],
        orElse: () => GpsFixStatus.noFix,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
      'satellites': satellites,
      'fixStatus': fixStatus.name,
    };
  }

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        altitude,
        timestamp,
        accuracy,
        satellites,
        fixStatus,
      ];
}
