enum DeviceType {
  bikeNode;

  String get displayName {
    switch (this) {
      case DeviceType.bikeNode:
        return 'Bike Node';
    }
  }
}

enum DeviceStatus {
  active,
  offline,
  unknown;

  String get displayName {
    switch (this) {
      case DeviceStatus.active:
        return 'Active';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.unknown:
        return 'Unknown';
    }
  }
}

enum PacketType {
  telemetry,
  sos,
  crash,
  lowBattery,
  diagnostic,
  ack;

  String get displayName {
    switch (this) {
      case PacketType.telemetry:
        return 'Telemetry';
      case PacketType.sos:
        return 'SOS';
      case PacketType.crash:
        return 'Crash';
      case PacketType.lowBattery:
        return 'Low Battery';
      case PacketType.diagnostic:
        return 'Diagnostic';
      case PacketType.ack:
        return 'ACK';
    }
  }
}

enum PacketPriority {
  critical(0),
  high(1),
  normal(2),
  low(3);

  final int value;
  const PacketPriority(this.value);

  String get displayName {
    switch (this) {
      case PacketPriority.critical:
        return 'Critical';
      case PacketPriority.high:
        return 'High';
      case PacketPriority.normal:
        return 'Normal';
      case PacketPriority.low:
        return 'Low';
    }
  }
}

enum PacketState {
  created,
  queued,
  forwarding,
  relayed,
  delivered,
  expired,
  failed;

  String get displayName {
    switch (this) {
      case PacketState.created:
        return 'Created';
      case PacketState.queued:
        return 'Queued';
      case PacketState.forwarding:
        return 'Forwarding';
      case PacketState.relayed:
        return 'Relayed';
      case PacketState.delivered:
        return 'Delivered';
      case PacketState.expired:
        return 'Expired';
      case PacketState.failed:
        return 'Failed';
    }
  }
}

enum EmergencyType {
  manualSos,
  crashDetected,
  lowBattery,
  deviceOffline;

  String get displayName {
    switch (this) {
      case EmergencyType.manualSos:
        return 'Manual SOS';
      case EmergencyType.crashDetected:
        return 'Crash Detected';
      case EmergencyType.lowBattery:
        return 'Low Battery';
      case EmergencyType.deviceOffline:
        return 'Device Offline';
    }
  }
}

enum BatteryLevel {
  normal,
  moderate,
  low,
  critical;

  static BatteryLevel fromPercentage(int percentage) {
    if (percentage >= 60) return BatteryLevel.normal;
    if (percentage >= 20) return BatteryLevel.moderate;
    if (percentage >= 10) return BatteryLevel.low;
    return BatteryLevel.critical;
  }

  String get displayName {
    switch (this) {
      case BatteryLevel.normal:
        return 'Normal';
      case BatteryLevel.moderate:
        return 'Moderate';
      case BatteryLevel.low:
        return 'Low';
      case BatteryLevel.critical:
        return 'Critical';
    }
  }
}

enum GpsFixStatus {
  noFix,
  fix2D,
  fix3D;

  String get displayName {
    switch (this) {
      case GpsFixStatus.noFix:
        return 'No Fix';
      case GpsFixStatus.fix2D:
        return '2D Fix';
      case GpsFixStatus.fix3D:
        return '3D Fix';
    }
  }
}

enum ConnectionMode {
  bluetooth,
  wifi;

  String get displayName {
    switch (this) {
      case ConnectionMode.bluetooth:
        return 'Bluetooth';
      case ConnectionMode.wifi:
        return 'Wi-Fi';
    }
  }
}

enum SafetyStatus {
  safe,
  sosActive,
  crashDetected,
  offline,
  unknown;

  String get displayName {
    switch (this) {
      case SafetyStatus.safe:
        return 'Safe';
      case SafetyStatus.sosActive:
        return 'SOS Active';
      case SafetyStatus.crashDetected:
        return 'Crash Detected';
      case SafetyStatus.offline:
        return 'Offline';
      case SafetyStatus.unknown:
        return 'Unknown';
    }
  }
}
