import 'package:equatable/equatable.dart';
import 'package:rescue_link/core/enums/enums.dart';

class Packet extends Equatable {
  final String packetId;
  final String deviceId;
  final PacketType type;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final int? batteryLevel;
  final int? rssi;
  final double? snr;
  final int hopCount;
  final int ttl;
  final PacketPriority priority;
  final PacketState state;
  final String source;
  final String destination;
  final List<String> route;
  final Map<String, dynamic>? payload;
  final SafetyStatus? safetyStatus;

  const Packet({
    required this.packetId,
    required this.deviceId,
    required this.type,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.batteryLevel,
    this.rssi,
    this.snr,
    required this.hopCount,
    required this.ttl,
    required this.priority,
    required this.state,
    required this.source,
    required this.destination,
    required this.route,
    this.payload,
    this.safetyStatus,
  });

  Packet copyWith({
    String? packetId,
    String? deviceId,
    PacketType? type,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    int? batteryLevel,
    int? rssi,
    double? snr,
    int? hopCount,
    int? ttl,
    PacketPriority? priority,
    PacketState? state,
    String? source,
    String? destination,
    List<String>? route,
    Map<String, dynamic>? payload,
    SafetyStatus? safetyStatus,
  }) {
    return Packet(
      packetId: packetId ?? this.packetId,
      deviceId: deviceId ?? this.deviceId,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      rssi: rssi ?? this.rssi,
      snr: snr ?? this.snr,
      hopCount: hopCount ?? this.hopCount,
      ttl: ttl ?? this.ttl,
      priority: priority ?? this.priority,
      state: state ?? this.state,
      source: source ?? this.source,
      destination: destination ?? this.destination,
      route: route ?? this.route,
      payload: payload ?? this.payload,
      safetyStatus: safetyStatus ?? this.safetyStatus,
    );
  }

  factory Packet.fromJson(Map<String, dynamic> json) {
    return Packet(
      packetId: json['packetId'] as String,
      deviceId: json['deviceId'] as String,
      type: PacketType.values.firstWhere((e) => e.name == json['type']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      batteryLevel: json['batteryLevel'] as int?,
      rssi: json['rssi'] as int?,
      snr: (json['snr'] as num?)?.toDouble(),
      hopCount: json['hopCount'] as int,
      ttl: json['ttl'] as int,
      priority: PacketPriority.values.firstWhere((e) => e.name == json['priority']),
      state: PacketState.values.firstWhere((e) => e.name == json['state']),
      source: json['source'] as String,
      destination: json['destination'] as String,
      route: (json['route'] as List<dynamic>).map((e) => e as String).toList(),
      payload: json['payload'] as Map<String, dynamic>?,
      safetyStatus: json['safetyStatus'] != null
          ? SafetyStatus.values.firstWhere((e) => e.name == json['safetyStatus'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packetId': packetId,
      'deviceId': deviceId,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'batteryLevel': batteryLevel,
      'rssi': rssi,
      'snr': snr,
      'hopCount': hopCount,
      'ttl': ttl,
      'priority': priority.name,
      'state': state.name,
      'source': source,
      'destination': destination,
      'route': route,
      'payload': payload,
      'safetyStatus': safetyStatus?.name,
    };
  }

  @override
  List<Object?> get props => [
        packetId,
        deviceId,
        type,
        timestamp,
        latitude,
        longitude,
        batteryLevel,
        rssi,
        snr,
        hopCount,
        ttl,
        priority,
        state,
        source,
        destination,
        route,
        payload,
        safetyStatus,
      ];
}
