import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rescue_link/models/emergency_event.dart';
import 'package:rescue_link/providers/bluetooth_provider.dart';

final emergencyEventsProvider = StreamProvider<List<EmergencyEvent>>((ref) {
  return ref.watch(emergencyRepositoryProvider).eventsStream;
});

final activeEmergenciesProvider = Provider<List<EmergencyEvent>>((ref) {
  final events = ref.watch(emergencyEventsProvider).valueOrNull ?? [];
  return events.where((e) => e.isActive).toList();
});

final activeEmergencyProvider = Provider<EmergencyEvent?>((ref) {
  final active = ref.watch(activeEmergenciesProvider);
  if (active.isEmpty) return null;
  return active.first;
});
