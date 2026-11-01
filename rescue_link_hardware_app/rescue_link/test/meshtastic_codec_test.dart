import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_link/services/meshtastic/meshtastic_codec.dart';
import 'package:rescue_link/services/meshtastic/meshtastic_constants.dart';

void main() {
  group('MeshtasticCodec Unit Tests', () {
    test('encodeHandshakeToRadio produces valid ToRadio bytes', () {
      final bytes = MeshtasticCodec.encodeHandshakeToRadio(configId: 1);
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], equals(24)); // Field 3 Tag
      expect(bytes[1], equals(1));  // configId
    });

    test('encodeSirenTriggerToRadio produces valid EXTERNAL_NOTIFICATION_APP packet', () {
      final bytes = MeshtasticCodec.encodeSirenTriggerToRadio();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], equals(18)); // ToRadio Field 2 Tag
    });

    test('decodePosition correctly parses coordinates divided by 1e7', () {
      // Build a synthetic Position protobuf
      // lat = 317640000 (31.764), lng = 769860000 (76.986)
      final builder = BytesBuilder();
      
      // Field 1: latI (wire type 5, 32-bit fixed) -> Tag (1 << 3) | 5 = 13
      builder.addByte(13);
      final latData = ByteData(4)..setInt32(0, 317640000, Endian.little);
      builder.add(latData.buffer.asUint8List());

      // Field 2: lngI (wire type 5, 32-bit fixed) -> Tag (2 << 3) | 5 = 21
      builder.addByte(21);
      final lngData = ByteData(4)..setInt32(0, 769860000, Endian.little);
      builder.add(lngData.buffer.asUint8List());

      final pos = MeshtasticCodec.decodePosition(builder.toBytes());
      expect(pos.latitude, closeTo(31.764, 0.0001));
      expect(pos.longitude, closeTo(76.986, 0.0001));
    });

    test('decodeData flags SOS text messages', () {
      final textBytes = utf8.encode('SOS! Rider fell in ravine');
      final builder = BytesBuilder();

      // Field 1: portnum (TEXT_MESSAGE_APP = 1) -> (1 << 3) | 0 = 8
      builder.addByte(8);
      builder.addByte(MeshtasticConstants.portTextMessageApp);

      // Field 2: payload -> (2 << 3) | 2 = 18
      builder.addByte(18);
      builder.addByte(textBytes.length);
      builder.add(textBytes);

      final data = MeshtasticCodec.decodeData(builder.toBytes());
      expect(data.isSosMessage, isTrue);
      expect(data.text, contains('SOS'));
    });

    test('framePacket and stripFraming handle [0x94, 0xC3] sync framing correctly', () {
      final raw = Uint8List.fromList([0x18, 0x01]);
      final framed = MeshtasticCodec.framePacket(raw);
      expect(framed[0], 0x94);
      expect(framed[1], 0xC3);
      expect(framed[2], 0);
      expect(framed[3], 2);
      expect(framed.sublist(4), raw);

      final stripped = MeshtasticCodec.stripFraming(framed);
      expect(stripped, raw);
    });

    test('PacketReassemblyBuffer reassembles chunked packets', () {
      final buffer = PacketReassemblyBuffer();
      final packet1 = MeshtasticCodec.framePacket(Uint8List.fromList([1, 2, 3, 4]));
      
      // Split into two chunks
      final chunk1 = Uint8List.sublistView(packet1, 0, 4);
      final chunk2 = Uint8List.sublistView(packet1, 4);

      final p1 = buffer.ingest(chunk1);
      expect(p1.isEmpty, isTrue); // partial

      final p2 = buffer.ingest(chunk2);
      expect(p2.length, 1);
      expect(p2[0], Uint8List.fromList([1, 2, 3, 4]));
    });
  });
}
