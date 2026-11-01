class AppConstants {
  static const String appName = 'RescueLink';
  static const String appSubtitle = 'Off-Grid Rider Safety';
  static const String appVersion = '1.0.0';

  static const int defaultTtl = 5;
  static const int maxHops = 10;

  static const int batteryNormalThreshold = 60;
  static const int batteryModerateThreshold = 20;
  static const int batteryLowThreshold = 10;

  static const int packetTimeoutSeconds = 30;
  static const int telemetryIntervalSeconds = 10;

  const AppConstants._();
}
