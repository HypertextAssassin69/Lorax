import 'package:equatable/equatable.dart';
import 'package:rescue_link/core/enums/enums.dart';
import 'package:rescue_link/models/location_data.dart';

class Device extends Equatable {
  final String id;
  final DeviceType type;
  final String? riderName;
  final int batteryLevel;
  final DeviceStatus status;
  final bool isBluetoothConnected;
  final SafetyStatus safetyStatus;
  final LocationData? location;
  final int? rssi;
  final double? snr;
  final int hopCount;
  final DateTime lastSeen;
  final String firmwareVersion;

  const Device({
    required this.id,
    required this.type,
    this.riderName,
    required this.batteryLevel,
    required this.status,
    this.isBluetoothConnected = true,
    this.safetyStatus = SafetyStatus.unknown,
    this.location,
    this.rssi,
    this.snr,
    required this.hopCount,
    required this.lastSeen,
    required this.firmwareVersion,
  });

  BatteryLevel get batteryState => BatteryLevel.fromPercentage(batteryLevel);

  Device copyWith({
    String? id,
    DeviceType? type,
    String? riderName,
    int? batteryLevel,
    DeviceStatus? status,
    bool? isBluetoothConnected,
    SafetyStatus? safetyStatus,
    LocationData? location,
    int? rssi,
    double? snr,
    int? hopCount,
    DateTime? lastSeen,
    String? firmwareVersion,
  }) {
    return Device(
      id: id ?? this.id,
      type: type ?? this.type,
      riderName: riderName ?? this.riderName,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      status: status ?? this.status,
      isBluetoothConnected: isBluetoothConnected ?? this.isBluetoothConnected,
      safetyStatus: safetyStatus ?? this.safetyStatus,
      location: location ?? this.location,
      rssi: rssi ?? this.rssi,
      snr: snr ?? this.snr,
      hopCount: hopCount ?? this.hopCount,
      lastSeen: lastSeen ?? this.lastSeen,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    final status = DeviceStatus.values.firstWhere((e) => e.name == json['status']);
    return Device(
      id: json['id'] as String,
      type: DeviceType.values.firstWhere((e) => e.name == json['type']),
      riderName: json['riderName'] as String?,
      batteryLevel: json['batteryLevel'] as int,
      status: status,
      isBluetoothConnected: json['isBluetoothConnected'] as bool? ?? true,
      safetyStatus: json['safetyStatus'] != null
          ? SafetyStatus.values.firstWhere((e) => e.name == json['safetyStatus'])
          : status == DeviceStatus.offline
              ? SafetyStatus.offline
              : SafetyStatus.safe,
      location: json['location'] != null
          ? LocationData.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      rssi: json['rssi'] as int?,
      snr: (json['snr'] as num?)?.toDouble(),
      hopCount: json['hopCount'] as int,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      firmwareVersion: json['firmwareVersion'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'riderName': riderName,
      'batteryLevel': batteryLevel,
      'status': status.name,
      'isBluetoothConnected': isBluetoothConnected,
      'safetyStatus': safetyStatus.name,
      'location': location?.toJson(),
      'rssi': rssi,
      'snr': snr,
      'hopCount': hopCount,
      'lastSeen': lastSeen.toIso8601String(),
      'firmwareVersion': firmwareVersion,
    };
  }

  @override
  List<Object?> get props => [
        id,
        type,
        riderName,
        batteryLevel,
        status,
        isBluetoothConnected,
        safetyStatus,
        location,
        rssi,
        snr,
        hopCount,
        lastSeen,
        firmwareVersion,
      ];
}
