export type TransportType = 'NONE' | 'BLE' | 'SERIAL';

export type ConnectionState = 'DISCONNECTED' | 'CONNECTING' | 'CONFIGURING' | 'CONNECTED' | 'ERROR';

export interface HardwareDiagnostics {
  sx1262Spi: boolean;
  neo6mGpsUart: boolean;
  mpu6050I2c: boolean;
  sosButtonD6: boolean;
  piezoBeaconD0: boolean;
  firmwareVersion: string;
  rebootCount: number;
}

export interface NodePosition {
  latitude: number;
  longitude: number;
  altitude?: number;
  satsInView?: number;
  groundSpeed?: number;
  time?: number;
}

export interface NodeMetrics {
  batteryLevel?: number; // 0 - 100%
  voltage?: number;      // e.g. 3.7V - 4.2V
  channelUtilization?: number; // %
  airUtilTx?: number;    // %
  uptimeSeconds?: number;
}

export interface MeshNode {
  num: number;
  hexId: string;
  shortName: string;
  longName: string;
  hwModel: string;
  macaddr?: string;
  lastHeard: number; // epoch ms
  hopsAway: number;
  snr: number;       // dB
  rssi?: number;     // dBm
  position?: NodePosition;
  metrics?: NodeMetrics;
  isLocal: boolean;
  isEmergency: boolean;
  emergencyTimestamp?: number;
  emergencyNote?: string;
  fallDetected?: boolean;
}

export interface MeshChatMessage {
  id: string;
  from: number;
  to: number; // 0xffffffff for broadcast
  text: string;
  timestamp: number;
  rxSnr?: number;
  rxRssi?: number;
  hopLimit?: number;
  hopStart?: number;
  isDirect: boolean;
  isAlert: boolean;
  ackStatus: 'SENDING' | 'ROUTING' | 'ACKED' | 'FAILED' | 'RECEIVED';
  ackBy?: number;
  packetId?: number;
}

export interface DistressAlert {
  id: string;
  senderNum: number;
  senderHex: string;
  senderName: string;
  alertType: 'HARDWARE_BUTTON' | 'FALL_DETECTED' | 'MANUAL_SOS' | 'BEACON_ACTIVE';
  message: string;
  timestamp: number;
  position?: NodePosition;
  acknowledged: boolean;
  acknowledgedAt?: number;
}

export interface RawPacketLog {
  id: string;
  direction: 'RX' | 'TX';
  timestamp: number;
  portnum: string;
  portnumId: number;
  from: number;
  to: number;
  packetId: number;
  rxSnr?: number;
  rxRssi?: number;
  hopLimit?: number;
  hopStart?: number;
  payloadLength: number;
  payloadHex: string;
  summary: string;
  rawJson?: string;
}

export interface TracerouteHop {
  nodeNum: number;
  nodeHex: string;
  nodeName: string;
  snr: number;
}

export interface TracerouteResult {
  id: string;
  targetNum: number;
  targetHex: string;
  timestamp: number;
  routeTowards: TracerouteHop[];
  routeBack: TracerouteHop[];
  complete: boolean;
}

export interface LocalNodeInfo {
  myNodeNum: number;
  hexId: string;
  shortName: string;
  longName: string;
  firmwareVersion: string;
  rebootCount: number;
  batteryLevel?: number;
  voltage?: number;
  channelUtilization?: number;
  airUtilTx?: number;
  uptimeSeconds?: number;
  position?: NodePosition;
  snr?: number;
  rssi?: number;
  hardware: HardwareDiagnostics;
}
