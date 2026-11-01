import 'dart:async';
import 'package:rescue_link/models/emergency_event.dart';

class NotificationService {
  final StreamController<EmergencyEvent> _emergencyController = StreamController<EmergencyEvent>.broadcast();

  Stream<EmergencyEvent> get emergencyNotifications => _emergencyController.stream;

  void showEmergencyAlert(EmergencyEvent event) {
    _emergencyController.add(event);
  }

  void clearNotifications() {
    // Intended for clearing local queues or system notifications
  }

  void dispose() {
    _emergencyController.close();
  }
}
