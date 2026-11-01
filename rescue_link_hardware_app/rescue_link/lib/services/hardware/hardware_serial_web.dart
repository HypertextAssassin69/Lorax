// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:html' as html;
import 'hardware_serial_service.dart';

@JS('rescueLinkConnectSerial')
external void _connectSerial();

@JS('rescueLinkDisconnectSerial')
external void _disconnectSerial();

HardwareSerialService getHardwareSerialService() => WebHardwareSerialService();

class WebHardwareSerialService implements HardwareSerialService {
  final _telemetryController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  bool _connected = false;

  WebHardwareSerialService() {
    html.window.on['hardware_serial_data'].listen((event) {
      final customEvent = event as html.CustomEvent;
      final jsonStr = customEvent.detail?.toString();
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          _telemetryController.add(data);
        } catch (_) {}
      }
    });

    html.window.on['hardware_serial_status'].listen((event) {
      final customEvent = event as html.CustomEvent;
      final status = customEvent.detail;
      _connected = status == true;
      _connectionController.add(_connected);
    });
  }

  @override
  Stream<Map<String, dynamic>> get telemetryStream => _telemetryController.stream;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connectSerial();
  }

  @override
  Future<void> disconnect() async {
    _disconnectSerial();
  }
}
