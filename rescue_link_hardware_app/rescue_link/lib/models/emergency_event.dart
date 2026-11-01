import 'package:equatable/equatable.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/models/location_data.dart';

class EmergencyEvent extends Equatable {
  final String id;
  final String packetId;
  final EmergencyType type;
  final String deviceId;
  final String? riderName;
  final LocationData? location;
  final DateTime timestamp;
  final int? batteryLevel;
  final int? rssi;
  final double? snr;
  final int hopCount;
  final PacketState deliveryStatus;
  final List<String> route;
  final bool acknowledged;

  const EmergencyEvent({
    required this.id,
    required this.packetId,
    required this.type,
    required this.deviceId,
    this.riderName,
    this.location,
    required this.timestamp,
    this.batteryLevel,
    this.rssi,
    this.snr,
    this.hopCount = 0,
    required this.deliveryStatus,
    required this.route,
    required this.acknowledged,
  });

  bool get isActive => !acknowledged;

  EmergencyEvent copyWith({
    String? id,
    String? packetId,
    EmergencyType? type,
    String? deviceId,
    String? riderName,
    LocationData? location,
    DateTime? timestamp,
    int? batteryLevel,
    int? rssi,
    double? snr,
    int? hopCount,
    PacketState? deliveryStatus,
    List<String>? route,
    bool? acknowledged,
  }) {
    return EmergencyEvent(
      id: id ?? this.id,
      packetId: packetId ?? this.packetId,
      type: type ?? this.type,
      deviceId: deviceId ?? this.deviceId,
      riderName: riderName ?? this.riderName,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      rssi: rssi ?? this.rssi,
      snr: snr ?? this.snr,
      hopCount: hopCount ?? this.hopCount,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      route: route ?? this.route,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  factory EmergencyEvent.fromJson(Map<String, dynamic> json) {
    return EmergencyEvent(
      id: json['id'] as String,
      packetId: (json['packetId'] as String?) ?? json['id'] as String,
      type: EmergencyType.values.firstWhere((e) => e.name == json['type']),
      deviceId: json['deviceId'] as String,
      riderName: json['riderName'] as String?,
      location: json['location'] != null
          ? LocationData.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
      batteryLevel: json['batteryLevel'] as int?,
      rssi: json['rssi'] as int?,
      snr: (json['snr'] as num?)?.toDouble(),
      hopCount: json['hopCount'] as int? ?? 0,
      deliveryStatus: PacketState.values.firstWhere((e) => e.name == json['deliveryStatus']),
      route: (json['route'] as List<dynamic>).map((e) => e as String).toList(),
      acknowledged: json['acknowledged'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packetId': packetId,
      'type': type.name,
      'deviceId': deviceId,
      'riderName': riderName,
      'location': location?.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'batteryLevel': batteryLevel,
      'rssi': rssi,
      'snr': snr,
      'hopCount': hopCount,
      'deliveryStatus': deliveryStatus.name,
      'route': route,
      'acknowledged': acknowledged,
    };
  }

  @override
  List<Object?> get props => [
        id,
        packetId,
        type,
        deviceId,
        riderName,
        location,
        timestamp,
        batteryLevel,
        rssi,
        snr,
        hopCount,
        deliveryStatus,
        route,
        acknowledged,
      ];
}
