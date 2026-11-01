import 'dart:async';
import 'package:rescue_link/models/packet.dart';
import 'package:rescue_link/models/bluetooth_status.dart';

abstract class BluetoothService {
  Stream<Packet> get packetStream;
  Stream<BluetoothStatus> get statusStream;
  bool get isConnected;
  BluetoothStatus get currentStatus;
  
  Future<void> connect();
  Future<void> disconnect();
  Future<bool> sendPacket(Packet packet);
  void dispose();
}
