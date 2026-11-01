class MeshtasticConstants {
  // BLE Service & Characteristics UUIDs
  static const String serviceUuid = '6ba1b218-15a8-461f-9fa8-5dcae273eafd';
  static const String toRadioUuid = 'f75c76d2-129e-11ed-861d-0242ac120002';
  static const String fromRadioUuid = '2c55e69e-4993-11ed-b878-0242ac120002';
  static const String fromNumUuid = 'ed9da18c-a800-4f66-a670-aa7547e34453';

  // Hardware defaults from blueprint
  static const String defaultBlePrefix = 'Meshtastic_';
  static const String defaultNodeIdHex = '0xa3999448';
  static const String defaultPasskey = '123456';
  static const int broadcastAddr = 0xFFFFFFFF;

  // PortNum application constants
  static const int portUnknown = 0;
  static const int portTextMessageApp = 1;
  static const int portRemoteHardwareApp = 2;
  static const int portPositionApp = 3;
  static const int portNodeInfoApp = 4;
  static const int portRoutingApp = 5;
  static const int portAdminApp = 6;
  static const int portTelemetryApp = 67;
  static const int portExternalNotificationApp = 72; // Standard Meshtastic SAR Buzzer / External Alert
  static const int portAlertApp = 73;

  const MeshtasticConstants._();
}
