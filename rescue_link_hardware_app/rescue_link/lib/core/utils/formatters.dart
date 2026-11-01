import 'package:intl/intl.dart';
import 'package:rescue_link/core/enums/enums.dart';

class Formatters {
  static String formatCoordinate(double value, {bool isLatitude = true}) {
    final suffix = isLatitude ? (value >= 0 ? 'N' : 'S') : (value >= 0 ? 'E' : 'W');
    return '${value.abs().toStringAsFixed(4)}° $suffix';
  }

  static String formatBattery(int percent) {
    return '$percent%';
  }

  static String formatTimestamp(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  static String formatTime(DateTime dt) {
    return DateFormat('HH:mm:ss').format(dt);
  }

  static String formatDate(DateTime dt) {
    return DateFormat('MMM dd, yyyy').format(dt);
  }

  static String formatEmergencyType(EmergencyType type) {
    return type.displayName;
  }

  static String formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} seconds ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  static String formatRssi(int rssi) {
    return '$rssi dBm';
  }

  static String formatSnr(double snr) {
    return '${snr.toStringAsFixed(1)} dB';
  }

  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  const Formatters._();
}
