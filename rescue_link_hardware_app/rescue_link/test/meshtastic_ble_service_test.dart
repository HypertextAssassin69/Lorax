import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_link/services/meshtastic/meshtastic_codec.dart';
import 'package:rescue_link/services/meshtastic_ble_service.dart';

void main() {
  group('Meshtastic BLE Specifications & Data Models', () {
    test('GpsPositionData model correctly formats coordinate telemetry', () {
      final gps = GpsPositionData(
        latitude: 31.7640,
        longitude: 76.9860,
        altitude: 450.5,
        satellites: 8,
        timestamp: DateTime(2026, 10, 23, 12, 0),
      );

      expect(gps.latitude, 31.7640);
      expect(gps.longitude, 76.9860);
      expect(gps.altitude, 450.5);
      expect(gps.satellites, 8);
      expect(gps.toString(), contains('31.764'));
    });

    test('SosAlertData model correctly flags tactile emergency distress', () {
      final sos = SosAlertData(
        nodeId: 'Meshtastic_af88',
        message: 'EMERGENCY SOS: Tactile Button Pressed',
        timestamp: DateTime(2026, 10, 23, 12, 0),
        isEmergency: true,
        latitude: 31.7640,
        longitude: 76.9860,
      );

      expect(sos.isEmergency, isTrue);
      expect(sos.nodeId, 'Meshtastic_af88');
      expect(sos.latitude, 31.7640);
      expect(sos.longitude, 76.9860);
    });

    test('MeshtasticConstants match hardware & BLE specs', () {
      expect(MeshtasticConstants.serviceUuid, '6ba1b218-15a8-461f-9fa8-5dcae273eafd');
      expect(MeshtasticConstants.toRadioUuid, 'f75c76d2-129e-11ed-861d-0242ac120002');
      expect(MeshtasticConstants.fromRadioUuid, '2c55e69e-4993-11ed-b878-0242ac120002');
      expect(MeshtasticConstants.fromNumUuid, 'ed9da18c-a800-4f66-a670-aa7547e34453');
      expect(MeshtasticConstants.defaultPasskey, '123456');
      expect(MeshtasticConstants.portPositionApp, 3);
      expect(MeshtasticConstants.portExternalNotificationApp, 72);
    });

    test('Handshake payload encodes want_config_id: 1 [0x18, 0x01]', () {
      final handshake = MeshtasticCodec.encodeHandshakeToRadio(configId: 1);
      expect(handshake, Uint8List.fromList([0x18, 0x01]));
    });

    test('Siren trigger packet encodes PortNum 72 EXTERNAL_NOTIFICATION_APP', () {
      final siren = MeshtasticCodec.encodeSirenTriggerToRadio();
      expect(siren.isNotEmpty, isTrue);

      final fromRadio = MeshtasticCodec.decodeFromRadio(siren);
      expect(fromRadio.packet, isNotNull);
      expect(fromRadio.packet!.decoded, isNotNull);
      expect(
        fromRadio.packet!.decoded!.portnum,
        MeshtasticConstants.portExternalNotificationApp,
      );
    });
  });
}
