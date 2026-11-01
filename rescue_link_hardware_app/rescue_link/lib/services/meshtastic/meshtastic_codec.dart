import 'dart:convert';
import 'dart:typed_data';
import 'package:rescue_link/services/meshtastic/meshtastic_constants.dart';

class MeshtasticPosition {
  final double latitude;
  final double longitude;
  final int altitude;
  final int timestamp;

  const MeshtasticPosition({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.timestamp,
  });

  @override
  String toString() => 'MeshtasticPosition(lat: $latitude, lng: $longitude, alt: $altitude)';
}

class MeshtasticTelemetry {
  final int? batteryLevel;
  final double? voltage;
  final double? accelX;
  final double? accelY;
  final double? accelZ;
  final bool isCrashImpact;
  final bool isMotionlessManDown;

  const MeshtasticTelemetry({
    this.batteryLevel,
    this.voltage,
    this.accelX,
    this.accelY,
    this.accelZ,
    this.isCrashImpact = false,
    this.isMotionlessManDown = false,
  });
}

class MeshtasticData {
  final int portnum;
  final Uint8List payload;
  final String? text;
  final MeshtasticPosition? position;
  final MeshtasticTelemetry? telemetry;
  final bool isSosMessage;

  const MeshtasticData({
    required this.portnum,
    required this.payload,
    this.text,
    this.position,
    this.telemetry,
    this.isSosMessage = false,
  });
}

class MeshtasticMeshPacket {
  final int from;
  final int to;
  final int id;
  final int rxTime;
  final int rxRssi;
  final double rxSnr;
  final int hopLimit;
  final MeshtasticData? decoded;

  const MeshtasticMeshPacket({
    required this.from,
    required this.to,
    required this.id,
    required this.rxTime,
    required this.rxRssi,
    required this.rxSnr,
    required this.hopLimit,
    this.decoded,
  });
}

class MeshtasticFromRadio {
  final int id;
  final MeshtasticMeshPacket? packet;

  const MeshtasticFromRadio({
    required this.id,
    this.packet,
  });
}

/// Lightweight, zero-dependency Protocol Buffers codec for Meshtastic BLE GATT packets
class MeshtasticCodec {
  // ==========================================
  // Protobuf Wire Decoder Helpers
  // ==========================================

  static int decodeVarint(Uint8List bytes, List<int> offsetRef) {
    int result = 0;
    int shift = 0;
    int offset = offsetRef[0];

    while (offset < bytes.length) {
      final b = bytes[offset++];
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    offsetRef[0] = offset;
    return result;
  }

  static double decodeFloat32(Uint8List bytes, List<int> offsetRef) {
    final offset = offsetRef[0];
    if (offset + 4 > bytes.length) return 0.0;
    final view = ByteData.sublistView(bytes, offset, offset + 4);
    offsetRef[0] = offset + 4;
    return view.getFloat32(0, Endian.little);
  }

  // ==========================================
  // Decoders
  // ==========================================

  /// Decode Position Protobuf (PortNum.POSITION_APP)
  static MeshtasticPosition decodePosition(Uint8List bytes) {
    int latI = 0;
    int lngI = 0;
    int alt = 0;
    int time = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final offset = [0];
    while (offset[0] < bytes.length) {
      final key = decodeVarint(bytes, offset);
      final fieldNum = key >> 3;
      final wireType = key & 0x07;

      switch (fieldNum) {
        case 1: // latitude_i (sfixed32 / sfixed)
          if (wireType == 5) {
            final view = ByteData.sublistView(bytes, offset[0], offset[0] + 4);
            latI = view.getInt32(0, Endian.little);
            offset[0] += 4;
          } else if (wireType == 0) {
            latI = decodeVarint(bytes, offset);
          }
          break;
        case 2: // longitude_i (sfixed32 / sfixed)
          if (wireType == 5) {
            final view = ByteData.sublistView(bytes, offset[0], offset[0] + 4);
            lngI = view.getInt32(0, Endian.little);
            offset[0] += 4;
          } else if (wireType == 0) {
            lngI = decodeVarint(bytes, offset);
          }
          break;
        case 3: // altitude (int32)
          alt = decodeVarint(bytes, offset);
          break;
        case 4: // time (fixed32)
          if (wireType == 5) {
            final view = ByteData.sublistView(bytes, offset[0], offset[0] + 4);
            time = view.getUint32(0, Endian.little);
            offset[0] += 4;
          } else {
            time = decodeVarint(bytes, offset);
          }
          break;
        default:
          _skipField(bytes, offset, wireType);
      }
    }

    return MeshtasticPosition(
      latitude: latI / 1e7,
      longitude: lngI / 1e7,
      altitude: alt,
      timestamp: time,
    );
  }

  /// Decode Telemetry Protobuf (PortNum.TELEMETRY_APP)
  static MeshtasticTelemetry decodeTelemetry(Uint8List bytes) {
    int? batt;
    double? volt;
    double? ax, ay, az;

    final offset = [0];
    while (offset[0] < bytes.length) {
      final key = decodeVarint(bytes, offset);
      final fieldNum = key >> 3;
      final wireType = key & 0x07;

      if (fieldNum == 2 && wireType == 2) {
        // DeviceMetrics sub-message
        final len = decodeVarint(bytes, offset);
        final end = offset[0] + len;
        while (offset[0] < end && offset[0] < bytes.length) {
          final subKey = decodeVarint(bytes, offset);
          final subField = subKey >> 3;
          final subWire = subKey & 0x07;
          if (subField == 1) {
            batt = decodeVarint(bytes, offset);
          } else if (subField == 2 && subWire == 5) {
            volt = decodeFloat32(bytes, offset);
          } else {
            _skipField(bytes, offset, subWire);
          }
        }
      } else if (fieldNum == 3 && wireType == 2) {
        // Motion / IMU sub-message
        final len = decodeVarint(bytes, offset);
        final end = offset[0] + len;
        while (offset[0] < end && offset[0] < bytes.length) {
          final subKey = decodeVarint(bytes, offset);
          final subField = subKey >> 3;
          final subWire = subKey & 0x07;
          if (subField == 1 && subWire == 5) {
            ax = decodeFloat32(bytes, offset);
          } else if (subField == 2 && subWire == 5) {
            ay = decodeFloat32(bytes, offset);
          } else if (subField == 3 && subWire == 5) {
            az = decodeFloat32(bytes, offset);
          } else {
            _skipField(bytes, offset, subWire);
          }
        }
      } else {
        _skipField(bytes, offset, wireType);
      }
    }

    // Check for crash impact (> 2.5G)
    bool isCrash = false;
    if (ax != null && ay != null && az != null) {
      final totalG = (ax * ax + ay * ay + az * az);
      if (totalG > 6.25) { // 2.5^2
        isCrash = true;
      }
    }

    return MeshtasticTelemetry(
      batteryLevel: batt ?? 88,
      voltage: volt,
      accelX: ax,
      accelY: ay,
      accelZ: az,
      isCrashImpact: isCrash,
    );
  }

  /// Decode Data message inside MeshPacket
  static MeshtasticData decodeData(Uint8List bytes) {
    int portnum = MeshtasticConstants.portUnknown;
    Uint8List payload = Uint8List(0);

    final offset = [0];
    while (offset[0] < bytes.length) {
      final key = decodeVarint(bytes, offset);
      final fieldNum = key >> 3;
      final wireType = key & 0x07;

      switch (fieldNum) {
        case 1: // portnum (PortNum enum)
          portnum = decodeVarint(bytes, offset);
          break;
        case 2: // payload (bytes)
          final len = decodeVarint(bytes, offset);
          payload = Uint8List.sublistView(bytes, offset[0], offset[0] + len);
          offset[0] += len;
          break;
        default:
          _skipField(bytes, offset, wireType);
      }
    }

    String? text;
    bool isSos = false;
    MeshtasticPosition? pos;
    MeshtasticTelemetry? tel;

    if (portnum == MeshtasticConstants.portTextMessageApp || portnum == MeshtasticConstants.portAlertApp) {
      try {
        text = utf8.decode(payload, allowMalformed: true);
        final upper = text.toUpperCase();
        if (upper.contains('SOS') || upper.contains('EMERGENCY') || upper.contains('CRASH')) {
          isSos = true;
        }
      } catch (_) {}
    } else if (portnum == MeshtasticConstants.portPositionApp) {
      try {
        pos = decodePosition(payload);
      } catch (_) {}
    } else if (portnum == MeshtasticConstants.portTelemetryApp) {
      try {
        tel = decodeTelemetry(payload);
      } catch (_) {}
    }

    return MeshtasticData(
      portnum: portnum,
      payload: payload,
      text: text,
      position: pos,
      telemetry: tel,
      isSosMessage: isSos,
    );
  }

  /// Decode MeshPacket Protobuf
  static MeshtasticMeshPacket decodeMeshPacket(Uint8List bytes) {
    int from = 0;
    int to = MeshtasticConstants.broadcastAddr;
    int id = 0;
    int rxTime = 0;
    int rxRssi = -75;
    double rxSnr = 9.0;
    int hopLimit = 3;
    MeshtasticData? decoded;

    final offset = [0];
    while (offset[0] < bytes.length) {
      final key = decodeVarint(bytes, offset);
      final fieldNum = key >> 3;
      final wireType = key & 0x07;

      switch (fieldNum) {
        case 1: // from (fixed32)
          if (wireType == 5) {
            final view = ByteData.sublistView(bytes, offset[0], offset[0] + 4);
            from = view.getUint32(0, Endian.little);
            offset[0] += 4;
          } else {
            from = decodeVarint(bytes, offset);
          }
          break;
        case 2: // to (fixed32)
          if (wireType == 5) {
            final view = ByteData.sublistView(bytes, offset[0], offset[0] + 4);
            to = view.getUint32(0, Endian.little);
            offset[0] += 4;
          } else {
            to = decodeVarint(bytes, offset);
          }
          break;
        case 4: // decoded (Data message)
          final len = decodeVarint(bytes, offset);
          final dataBytes = Uint8List.sublistView(bytes, offset[0], offset[0] + len);
          decoded = decodeData(dataBytes);
          offset[0] += len;
          break;
        case 6: // id (fixed32)
          if (wireType == 5) {
            final view = ByteData.sublistView(bytes, offset[0], offset[0] + 4);
            id = view.getUint32(0, Endian.little);
            offset[0] += 4;
          } else {
            id = decodeVarint(bytes, offset);
          }
          break;
        case 7: // rx_time (fixed32)
          if (wireType == 5) {
            final view = ByteData.sublistView(bytes, offset[0], offset[0] + 4);
            rxTime = view.getUint32(0, Endian.little);
            offset[0] += 4;
          } else {
            rxTime = decodeVarint(bytes, offset);
          }
          break;
        case 8: // rx_snr (float)
          if (wireType == 5) {
            rxSnr = decodeFloat32(bytes, offset);
          } else {
            _skipField(bytes, offset, wireType);
          }
          break;
        case 9: // hop_limit
          hopLimit = decodeVarint(bytes, offset);
          break;
        case 11: // rx_rssi (sint32)
          rxRssi = decodeVarint(bytes, offset);
          break;
        default:
          _skipField(bytes, offset, wireType);
      }
    }

    return MeshtasticMeshPacket(
      from: from,
      to: to,
      id: id,
      rxTime: rxTime,
      rxRssi: rxRssi,
      rxSnr: rxSnr,
      hopLimit: hopLimit,
      decoded: decoded,
    );
  }

  /// Decode FromRadio wrapper
  static MeshtasticFromRadio decodeFromRadio(Uint8List bytes) {
    int id = 0;
    MeshtasticMeshPacket? packet;

    final offset = [0];
    while (offset[0] < bytes.length) {
      final key = decodeVarint(bytes, offset);
      final fieldNum = key >> 3;
      final wireType = key & 0x07;

      switch (fieldNum) {
        case 1: // id
          id = decodeVarint(bytes, offset);
          break;
        case 2: // packet (MeshPacket)
          final len = decodeVarint(bytes, offset);
          final pBytes = Uint8List.sublistView(bytes, offset[0], offset[0] + len);
          packet = decodeMeshPacket(pBytes);
          offset[0] += len;
          break;
        default:
          _skipField(bytes, offset, wireType);
      }
    }

    return MeshtasticFromRadio(id: id, packet: packet);
  }

  // ==========================================
  // Encoders (ToRadio)
  // ==========================================

  /// Encode `want_config_id: 1` handshake ToRadio packet
  static Uint8List encodeHandshakeToRadio({int configId = 1}) {
    final builder = BytesBuilder();
    // Field 3: want_config_id (uint32)
    // Tag: (3 << 3) | 0 = 24
    builder.addByte(24);
    _writeVarint(builder, configId);
    return builder.toBytes();
  }

  /// Encode Remote SAR Siren / Piezo Buzzer Trigger Packet (GPIO 0 on ESP32-C6)
  /// PortNum == EXTERNAL_NOTIFICATION_APP (72)
  static Uint8List encodeSirenTriggerToRadio({int targetNode = MeshtasticConstants.broadcastAddr}) {
    // 1. Data payload: Alert command "SIREN_ON"
    final payloadBytes = utf8.encode('SIREN_ON');
    final dataBuilder = BytesBuilder();
    // Field 1: portnum (EXTERNAL_NOTIFICATION_APP = 72) -> (1 << 3) | 0 = 8
    dataBuilder.addByte(8);
    _writeVarint(dataBuilder, MeshtasticConstants.portExternalNotificationApp);
    // Field 2: payload (bytes) -> (2 << 3) | 2 = 18
    dataBuilder.addByte(18);
    _writeVarint(dataBuilder, payloadBytes.length);
    dataBuilder.add(payloadBytes);
    final dataBytes = dataBuilder.toBytes();

    // 2. MeshPacket
    final packetBuilder = BytesBuilder();
    // Field 2: to (fixed32) -> (2 << 3) | 5 = 21
    packetBuilder.addByte(21);
    final toData = ByteData(4)..setUint32(0, targetNode, Endian.little);
    packetBuilder.add(toData.buffer.asUint8List());

    // Field 4: decoded (Data message) -> (4 << 3) | 2 = 34
    packetBuilder.addByte(34);
    _writeVarint(packetBuilder, dataBytes.length);
    packetBuilder.add(dataBytes);

    // Field 9: hop_limit -> (9 << 3) | 0 = 72
    packetBuilder.addByte(72);
    _writeVarint(packetBuilder, 3);
    final packetBytes = packetBuilder.toBytes();

    // 3. ToRadio wrapping packet (Field 2: packet) -> (2 << 3) | 2 = 18
    final toRadioBuilder = BytesBuilder();
    toRadioBuilder.addByte(18);
    _writeVarint(toRadioBuilder, packetBytes.length);
    toRadioBuilder.add(packetBytes);

    return toRadioBuilder.toBytes();
  }

  /// Encode Text Message / SOS Broadcast Packet over LoRa Mesh via ToRadio
  /// PortNum == TEXT_MESSAGE_APP (1)
  static Uint8List encodeTextMessageToRadio(String text, {int targetNode = MeshtasticConstants.broadcastAddr}) {
    // 1. Data payload
    final payloadBytes = utf8.encode(text);
    final dataBuilder = BytesBuilder();
    // Field 1: portnum (TEXT_MESSAGE_APP = 1) -> (1 << 3) | 0 = 8
    dataBuilder.addByte(8);
    _writeVarint(dataBuilder, MeshtasticConstants.portTextMessageApp);
    // Field 2: payload (bytes) -> (2 << 3) | 2 = 18
    dataBuilder.addByte(18);
    _writeVarint(dataBuilder, payloadBytes.length);
    dataBuilder.add(payloadBytes);
    final dataBytes = dataBuilder.toBytes();

    // 2. MeshPacket
    final packetBuilder = BytesBuilder();
    // Field 2: to (fixed32) -> (2 << 3) | 5 = 21
    packetBuilder.addByte(21);
    final toData = ByteData(4)..setUint32(0, targetNode, Endian.little);
    packetBuilder.add(toData.buffer.asUint8List());

    // Field 4: decoded (Data message) -> (4 << 3) | 2 = 34
    packetBuilder.addByte(34);
    _writeVarint(packetBuilder, dataBytes.length);
    packetBuilder.add(dataBytes);

    // Field 9: hop_limit -> (9 << 3) | 0 = 72
    packetBuilder.addByte(72);
    _writeVarint(packetBuilder, 3);

    // Field 10: want_ack -> (10 << 3) | 0 = 80
    packetBuilder.addByte(80);
    _writeVarint(packetBuilder, 1);
    final packetBytes = packetBuilder.toBytes();

    // 3. ToRadio wrapping packet (Field 2: packet) -> (2 << 3) | 2 = 18
    final toRadioBuilder = BytesBuilder();
    toRadioBuilder.addByte(18);
    _writeVarint(toRadioBuilder, packetBytes.length);
    toRadioBuilder.add(packetBytes);

    return toRadioBuilder.toBytes();
  }

  static void _writeVarint(BytesBuilder builder, int value) {
    while (value >= 0x80) {
      builder.addByte((value & 0x7F) | 0x80);
      value >>= 7;
    }
    builder.addByte(value & 0x7F);
  }

  static void _skipField(Uint8List bytes, List<int> offsetRef, int wireType) {
    switch (wireType) {
      case 0:
        decodeVarint(bytes, offsetRef);
        break;
      case 1:
        offsetRef[0] += 8;
        break;
      case 2:
        final len = decodeVarint(bytes, offsetRef);
        offsetRef[0] += len;
        break;
      case 5:
        offsetRef[0] += 4;
        break;
    }
  }

  // ==========================================
  // Framing & Stream Reassembly Buffer
  // ==========================================

  /// Frame payload with Meshtastic Serial/BLE sync bytes [0x94, 0xC3, MSB, LSB]
  static Uint8List framePacket(Uint8List payload) {
    final builder = BytesBuilder();
    builder.addByte(0x94);
    builder.addByte(0xC3);
    builder.addByte((payload.length >> 8) & 0xFF);
    builder.addByte(payload.length & 0xFF);
    builder.add(payload);
    return builder.toBytes();
  }

  /// Strip Meshtastic [0x94, 0xC3, MSB, LSB] framing header if present
  static Uint8List stripFraming(Uint8List bytes) {
    if (bytes.length >= 4 && bytes[0] == 0x94 && bytes[1] == 0xC3) {
      final len = (bytes[2] << 8) | bytes[3];
      if (bytes.length >= 4 + len) {
        return Uint8List.sublistView(bytes, 4, 4 + len);
      }
      return Uint8List.sublistView(bytes, 4);
    }
    return bytes;
  }
}

/// Buffer that reassembles chunked BLE notifications and split Serial streams
class PacketReassemblyBuffer {
  final BytesBuilder _buffer = BytesBuilder();

  /// Ingest raw stream chunk and yield all fully assembled packets
  List<Uint8List> ingest(Uint8List incoming) {
    _buffer.add(incoming);
    final raw = _buffer.toBytes();
    final packets = <Uint8List>[];
    int cursor = 0;

    while (cursor < raw.length) {
      if (cursor + 4 <= raw.length && raw[cursor] == 0x94 && raw[cursor + 1] == 0xC3) {
        final length = (raw[cursor + 2] << 8) | raw[cursor + 3];
        if (length > 1024) {
          // Corrupted length, slide forward
          cursor++;
          continue;
        }
        if (cursor + 4 + length <= raw.length) {
          final packetBytes = Uint8List.sublistView(raw, cursor + 4, cursor + 4 + length);
          packets.add(packetBytes);
          cursor += 4 + length;
          continue;
        } else {
          // Partial packet, wait for next incoming chunk
          break;
        }
      } else {
        // Unframed raw protobuf packet chunk
        if (cursor == 0 && (raw[0] != 0x94 || (raw.length > 1 && raw[1] != 0xC3))) {
          packets.add(Uint8List.fromList(raw));
          cursor = raw.length;
          break;
        }
        cursor++;
      }
    }

    _buffer.clear();
    if (cursor < raw.length) {
      _buffer.add(Uint8List.sublistView(raw, cursor));
    }
    return packets;
  }

  void clear() => _buffer.clear();
}
