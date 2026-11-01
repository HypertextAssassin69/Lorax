import 'hardware_serial_stub.dart'
    if (dart.library.html) 'hardware_serial_web.dart';

abstract class HardwareSerialService {
  Stream<Map<String, dynamic>> get telemetryStream;
  Stream<bool> get connectionStream;
  bool get isConnected;
  Future<void> connect();
  Future<void> disconnect();

  factory HardwareSerialService() => getHardwareSerialService();
}
