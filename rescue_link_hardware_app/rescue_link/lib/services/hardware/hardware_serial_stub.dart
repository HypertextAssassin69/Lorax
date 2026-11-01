import 'hardware_serial_service.dart';

HardwareSerialService getHardwareSerialService() => _StubHardwareSerialService();

class _StubHardwareSerialService implements HardwareSerialService {
  @override
  Stream<Map<String, dynamic>> get telemetryStream => const Stream.empty();

  @override
  Stream<bool> get connectionStream => const Stream.empty();

  @override
  bool get isConnected => false;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}
}
