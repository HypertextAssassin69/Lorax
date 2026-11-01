import 'dart:ui';
import 'package:equatable/equatable.dart';
import 'package:rescue_link/core/enums/enums.dart';

class NetworkNode extends Equatable {
  final String id;
  final DeviceType type;
  final String label;
  final DeviceStatus status;
  final int? batteryLevel;
  final int? rssi;
  final double? snr;
  final int hopCount;
  final DateTime? lastSeen;
  final List<String> connections;
  final Offset? position;

  const NetworkNode({
    required this.id,
    required this.type,
    required this.label,
    required this.status,
    this.batteryLevel,
    this.rssi,
    this.snr,
    required this.hopCount,
    this.lastSeen,
    required this.connections,
    this.position,
  });

  NetworkNode copyWith({
    String? id,
    DeviceType? type,
    String? label,
    DeviceStatus? status,
    int? batteryLevel,
    int? rssi,
    double? snr,
    int? hopCount,
    DateTime? lastSeen,
    List<String>? connections,
    Offset? position,
  }) {
    return NetworkNode(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      status: status ?? this.status,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      rssi: rssi ?? this.rssi,
      snr: snr ?? this.snr,
      hopCount: hopCount ?? this.hopCount,
      lastSeen: lastSeen ?? this.lastSeen,
      connections: connections ?? this.connections,
      position: position ?? this.position,
    );
  }

  factory NetworkNode.fromJson(Map<String, dynamic> json) {
    return NetworkNode(
      id: json['id'] as String,
      type: DeviceType.values.firstWhere((e) => e.name == json['type']),
      label: json['label'] as String,
      status: DeviceStatus.values.firstWhere((e) => e.name == json['status']),
      batteryLevel: json['batteryLevel'] as int?,
      rssi: json['rssi'] as int?,
      snr: (json['snr'] as num?)?.toDouble(),
      hopCount: json['hopCount'] as int,
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen'] as String) : null,
      connections: (json['connections'] as List<dynamic>).map((e) => e as String).toList(),
      position: json['position'] != null
          ? Offset(
              (json['position']['dx'] as num).toDouble(),
              (json['position']['dy'] as num).toDouble(),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'label': label,
      'status': status.name,
      'batteryLevel': batteryLevel,
      'rssi': rssi,
      'snr': snr,
      'hopCount': hopCount,
      'lastSeen': lastSeen?.toIso8601String(),
      'connections': connections,
      'position': position != null
          ? {'dx': position!.dx, 'dy': position!.dy}
          : null,
    };
  }

  @override
  List<Object?> get props => [
        id,
        type,
        label,
        status,
        batteryLevel,
        rssi,
        snr,
        hopCount,
        lastSeen,
        connections,
        position,
      ];
}
