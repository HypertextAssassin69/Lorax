import 'package:equatable/equatable.dart';
import 'package:rescue_link/core/enums/enums.dart';

class BluetoothStatus extends Equatable {
  final bool isConnected;
  final ConnectionMode mode;
  final int? signalStrength;
  final DateTime? lastHeartbeat;
  final String? bluetoothId;

  const BluetoothStatus({
    required this.isConnected,
    required this.mode,
    this.signalStrength,
    this.lastHeartbeat,
    this.bluetoothId,
  });

  BluetoothStatus copyWith({
    bool? isConnected,
    ConnectionMode? mode,
    int? signalStrength,
    DateTime? lastHeartbeat,
    String? bluetoothId,
  }) {
    return BluetoothStatus(
      isConnected: isConnected ?? this.isConnected,
      mode: mode ?? this.mode,
      signalStrength: signalStrength ?? this.signalStrength,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      bluetoothId: bluetoothId ?? this.bluetoothId,
    );
  }

  factory BluetoothStatus.fromJson(Map<String, dynamic> json) {
    return BluetoothStatus(
      isConnected: json['isConnected'] as bool,
      mode: ConnectionMode.values.firstWhere((e) => e.name == json['mode']),
      signalStrength: json['signalStrength'] as int?,
      lastHeartbeat: json['lastHeartbeat'] != null
          ? DateTime.parse(json['lastHeartbeat'] as String)
          : null,
      bluetoothId: json['bluetoothId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isConnected': isConnected,
      'mode': mode.name,
      'signalStrength': signalStrength,
      'lastHeartbeat': lastHeartbeat?.toIso8601String(),
      'bluetoothId': bluetoothId,
    };
  }

  @override
  List<Object?> get props => [
        isConnected,
        mode,
        signalStrength,
        lastHeartbeat,
        bluetoothId,
      ];
}
