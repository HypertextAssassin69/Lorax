import { create, fromBinary, toBinary } from '@bufbuild/protobuf';
import { Mesh, Portnums, Telemetry } from '@meshtastic/protobufs';
import { BleClient } from '@capacitor-community/bluetooth-le';
import { Capacitor } from '@capacitor/core';
import { useMeshStore } from '../store/useMeshStore';
import {
  MeshChatMessage,
  DistressAlert,
  RawPacketLog,
  TracerouteHop,
  TracerouteResult,
  NodePosition,
} from '../types/meshtastic';

// Meshtastic Official BLE GATT UUIDs
export const MESHTASTIC_BLE_SERVICE_UUID = '6ba1b218-15a8-461f-9fa8-5dcae273eafd';
export const TO_RADIO_UUID_PRIMARY = 'f75c76d2-129e-4dad-a1dd-7866124401e7';
export const TO_RADIO_UUID_FALLBACK = 'f75c76d2-129e-11ed-861d-0242ac120002';
export const FROM_RADIO_UUID = '2c55e69e-4993-11ed-b878-0242ac120002';
export const FROM_NUM_UUID = 'ed9da18c-a800-4f66-a670-aa7547e34453';

// Hardware Vendor/Product IDs for Seeed XIAO ESP32-C6 Native USB CDC
export const XIAO_ESP32C6_USB_VID = 0x303a;
export const XIAO_ESP32C6_USB_PID = 0x1001;

// Meshtastic Serial Protocol Magic Header: [0x94, 0xC3]
const SERIAL_FRAME_START_1 = 0x94;
const SERIAL_FRAME_START_2 = 0xc3;
const MAX_SERIAL_PACKET_LEN = 512;

class MeshtasticTransportService {
  // BLE Handles
  private bleDevice: BluetoothDevice | null = null;
  private nativeBleDeviceId: string | null = null;
  private toRadioChar: BluetoothRemoteGATTCharacteristic | null = null;
  private fromRadioChar: BluetoothRemoteGATTCharacteristic | null = null;
  private fromNumChar: BluetoothRemoteGATTCharacteristic | null = null;
  private isDrainingBle = false;

  // Serial Handles
  private serialPort: SerialPort | null = null;
  private serialReader: ReadableStreamDefaultReader<Uint8Array> | null = null;
  private serialWriter: WritableStreamDefaultWriter<Uint8Array> | null = null;
  private serialReadAbortController: AbortController | null = null;
  private serialRxBuffer: Uint8Array = new Uint8Array(0);

  // Active state
  private currentConfigId = 0;
  private keepaliveTimer: number | null = null;
  private gpsSyncInterval: any = null;

  // ==========================================
  // 1. BLUETOOTH LOW ENERGY (BLE) IMPLEMENTATION
  // ==========================================

  public async connectBle(): Promise<boolean> {
    const store = useMeshStore.getState();

    // 1a. Native Android / iOS via Capacitor
    if (Capacitor.isNativePlatform()) {
      try {
        store.setConnectionState('CONNECTING', 'BLE');
        await this.disconnect();
        await BleClient.initialize();
        const device = await BleClient.requestDevice({
          services: [MESHTASTIC_BLE_SERVICE_UUID],
          optionalServices: [MESHTASTIC_BLE_SERVICE_UUID],
        });
        this.nativeBleDeviceId = device.deviceId;
        await BleClient.connect(this.nativeBleDeviceId, () => this.handleBleDisconnect());

        // Subscribe to notifications on FromNum
        await BleClient.startNotifications(
          this.nativeBleDeviceId,
          MESHTASTIC_BLE_SERVICE_UUID,
          FROM_NUM_UUID,
          () => {
            this.drainFromRadio();
          }
        );

        store.setConnectionState('CONFIGURING', 'BLE');
        this.currentConfigId = Math.floor(Math.random() * 0x7fffffff) + 1;
        await this.sendWantConfigId(this.currentConfigId);
        await this.drainFromRadio();
        this.startKeepalive();
        return true;
      } catch (err: any) {
        console.error('[Meshtastic Native BLE] Connection error:', err);
        store.setConnectionState('ERROR', 'BLE', err?.message || 'Bluetooth connection failed');
        await this.disconnect();
        return false;
      }
    }

    // 1b. Web Bluetooth (Browser / HTTPS)
    // Check Secure Context (required by Web Bluetooth on mobile browsers)
    if (typeof window !== 'undefined' && !window.isSecureContext) {
      const httpsUrl = window.location.href.replace('http:', 'https:');
      const err = `HTTPS required for Android BLE — open ${httpsUrl}`;
      store.setConnectionState('ERROR', 'BLE', err);
      return false;
    }

    if (!navigator.bluetooth) {
      const err = 'Bluetooth not available. On Chrome Mobile, ensure you are on HTTPS with Location & Bluetooth enabled.';
      store.setConnectionState('ERROR', 'BLE', err);
      return false;
    }

    try {
      store.setConnectionState('CONNECTING', 'BLE');
      await this.disconnect();

      // Request device with Meshtastic Service UUID
      const device = await navigator.bluetooth.requestDevice({
        filters: [
          { services: [MESHTASTIC_BLE_SERVICE_UUID] },
          { namePrefix: 'Meshtastic' },
          { namePrefix: 'Rescue' },
          { namePrefix: 'SAR' },
        ],
        optionalServices: [MESHTASTIC_BLE_SERVICE_UUID],
      });

      this.bleDevice = device;
      device.addEventListener('gattserverdisconnected', this.handleBleDisconnect.bind(this));

      if (!device.gatt) {
        throw new Error('GATT Server unavailable on requested Bluetooth device.');
      }

      // Connect to GATT Server
      const gattServer = await device.gatt.connect();

      // Get Meshtastic Primary Service
      const service = await gattServer.getPrimaryService(MESHTASTIC_BLE_SERVICE_UUID);

      // Locate Characteristics
      const chars = await service.getCharacteristics();
      for (const c of chars) {
        const uuidLower = c.uuid.toLowerCase();
        if (uuidLower === TO_RADIO_UUID_PRIMARY.toLowerCase() || uuidLower === TO_RADIO_UUID_FALLBACK.toLowerCase()) {
          this.toRadioChar = c;
        } else if (uuidLower === FROM_RADIO_UUID.toLowerCase()) {
          this.fromRadioChar = c;
        } else if (uuidLower === FROM_NUM_UUID.toLowerCase()) {
          this.fromNumChar = c;
        }
      }

      if (!this.toRadioChar || !this.fromRadioChar || !this.fromNumChar) {
        throw new Error('Failed to resolve all required Meshtastic GATT characteristics (ToRadio, FromRadio, FromNum).');
      }

      // Step b: Subscribe to notifications on FromNum
      await this.fromNumChar.startNotifications();
      this.fromNumChar.addEventListener('characteristicvaluechanged', () => {
        // Step e: Whenever FromNum fires a notification, trigger drainFromRadio()
        this.drainFromRadio();
      });

      store.setConnectionState('CONFIGURING', 'BLE');

      // Step c: Generate a random 32-bit configId and write ToRadio(wantConfigId)
      this.currentConfigId = Math.floor(Math.random() * 0x7fffffff) + 1;
      await this.sendWantConfigId(this.currentConfigId);

      // Step d: Immediately execute drainFromRadio() loop
      await this.drainFromRadio();

      this.startKeepalive();
      return true;
    } catch (err: any) {
      console.error('[Meshtastic BLE] Connection error:', err);
      store.setConnectionState('ERROR', 'BLE', err?.message || 'Bluetooth connection failed');
      await this.disconnect();
      return false;
    }
  }

  private async drainFromRadio(): Promise<void> {
    if (this.isDrainingBle) {
      return;
    }

    // Native Capacitor BLE
    if (Capacitor.isNativePlatform() && this.nativeBleDeviceId) {
      this.isDrainingBle = true;
      try {
        while (this.nativeBleDeviceId) {
          const dataView = await BleClient.read(
            this.nativeBleDeviceId,
            MESHTASTIC_BLE_SERVICE_UUID,
            FROM_RADIO_UUID
          );
          if (!dataView || dataView.byteLength === 0) {
            break;
          }
          const rawBytes = new Uint8Array(
            dataView.buffer.slice(dataView.byteOffset, dataView.byteOffset + dataView.byteLength)
          );
          this.processIncomingProtobuf(rawBytes);
        }
      } catch (e) {
        // queue clear or end of pending packets
      } finally {
        this.isDrainingBle = false;
      }
      return;
    }

    if (!this.fromRadioChar) {
      return;
    }

    this.isDrainingBle = true;
    try {
      while (this.fromRadioChar) {
        const dataView = await this.fromRadioChar.readValue();
        if (!dataView || dataView.byteLength === 0) {
          // No more pending packets in radio queue
          break;
        }

        const rawBytes = new Uint8Array(
          dataView.buffer.slice(dataView.byteOffset, dataView.byteOffset + dataView.byteLength)
        );

        this.processIncomingProtobuf(rawBytes);
      }
    } catch (e) {
      console.warn('[Meshtastic BLE] drainFromRadio read error (queue possibly clear):', e);
    } finally {
      this.isDrainingBle = false;
    }
  }

  private handleBleDisconnect(): void {
    console.warn('[Meshtastic BLE] Device disconnected unexpectedly.');
    this.stopKeepalive();
    this.stopPhoneGpsAutoSync();
    useMeshStore.getState().setConnectionState('DISCONNECTED', 'NONE', 'Hardware node disconnected');
  }

  // ==========================================
  // 2. USB CDC SERIAL IMPLEMENTATION (COM7 / OTG)
  // ==========================================

  public async connectSerial(customPort?: SerialPort): Promise<boolean> {
    const store = useMeshStore.getState();
    if (!navigator.serial) {
      const err = 'Web Serial API is not supported in this browser. Use Chrome, Edge, or Opera.';
      store.setConnectionState('ERROR', 'SERIAL', err);
      return false;
    }

    try {
      store.setConnectionState('CONNECTING', 'SERIAL');
      await this.disconnect();

      let port: SerialPort;
      if (customPort) {
        port = customPort;
      } else {
        // Request port with filter for Seeed XIAO ESP32-C6 native USB CDC
        port = await navigator.serial.requestPort({
          filters: [
            { usbVendorId: XIAO_ESP32C6_USB_VID, usbProductId: XIAO_ESP32C6_USB_PID },
            { usbVendorId: 0x303a }, // Espressif vendor filter
          ],
        });
      }

      this.serialPort = port;

      // Open port at 115200 baud
      await port.open({
        baudRate: 115200,
        dataBits: 8,
        stopBits: 1,
        parity: 'none',
        bufferSize: 4096,
      });

      if (!port.readable || !port.writable) {
        throw new Error('Serial port stream endpoints unavailable.');
      }

      this.serialReader = port.readable.getReader();
      this.serialWriter = port.writable.getWriter();
      this.serialRxBuffer = new Uint8Array(0);

      store.setConnectionState('CONFIGURING', 'SERIAL');

      // Start serial background reading loop
      this.serialReadAbortController = new AbortController();
      this.runSerialReaderLoop(this.serialReadAbortController.signal);

      // Send initial ToRadio(wantConfigId) handshake immediately upon port open
      this.currentConfigId = Math.floor(Math.random() * 0x7fffffff) + 1;
      await this.sendWantConfigId(this.currentConfigId);

      this.startKeepalive();
      return true;
    } catch (err: any) {
      console.error('[Meshtastic Serial] Connection error:', err);
      store.setConnectionState('ERROR', 'SERIAL', err?.message || 'USB Serial connection failed');
      await this.disconnect();
      return false;
    }
  }

  private async runSerialReaderLoop(signal: AbortSignal): Promise<void> {
    while (!signal.aborted && this.serialReader) {
      try {
        const { value, done } = await this.serialReader.read();
        if (done) {
          console.warn('[Meshtastic Serial] Reader stream finished.');
          break;
        }

        if (value && value.length > 0) {
          this.appendAndParseSerialBytes(value);
        }
      } catch (err: any) {
        if (!signal.aborted) {
          console.error('[Meshtastic Serial] Reader stream error:', err);
        }
        break;
      }
    }

    if (!signal.aborted) {
      this.handleSerialDisconnect();
    }
  }

  /**
   * Exact Meshtastic Serial Stream Framing Parser:
   * Looks for [0x94, 0xC3, (len >> 8) & 0xFF, len & 0xFF] followed by `len` bytes.
   */
  private appendAndParseSerialBytes(incoming: Uint8Array): void {
    // Append incoming bytes to existing buffer
    const nextBuf = new Uint8Array(this.serialRxBuffer.length + incoming.length);
    nextBuf.set(this.serialRxBuffer, 0);
    nextBuf.set(incoming, this.serialRxBuffer.length);
    this.serialRxBuffer = nextBuf;

    while (this.serialRxBuffer.length >= 4) {
      // Find frame header 0x94 0xC3
      let frameStartIndex = -1;
      for (let i = 0; i <= this.serialRxBuffer.length - 4; i++) {
        if (this.serialRxBuffer[i] === SERIAL_FRAME_START_1 && this.serialRxBuffer[i + 1] === SERIAL_FRAME_START_2) {
          frameStartIndex = i;
          break;
        }
      }

      if (frameStartIndex === -1) {
        // No header found. Retain the very last byte in case 0x94 is on the boundary.
        const lastByte = this.serialRxBuffer[this.serialRxBuffer.length - 1];
        if (lastByte === SERIAL_FRAME_START_1) {
          this.serialRxBuffer = new Uint8Array([SERIAL_FRAME_START_1]);
        } else {
          this.serialRxBuffer = new Uint8Array(0);
        }
        return;
      }

      // Discard junk bytes before the frame start index
      if (frameStartIndex > 0) {
        this.serialRxBuffer = this.serialRxBuffer.slice(frameStartIndex);
      }

      if (this.serialRxBuffer.length < 4) {
        return;
      }

      // Read 16-bit big-endian packet length
      const length = (this.serialRxBuffer[2] << 8) | this.serialRxBuffer[3];

      // Validate length sanity
      if (length > MAX_SERIAL_PACKET_LEN || length === 0) {
        console.warn(`[Meshtastic Serial] Corrupted frame length: ${length} bytes. Advancing.`);
        this.serialRxBuffer = this.serialRxBuffer.slice(2);
        continue;
      }

      const totalFrameBytes = 4 + length;
      if (this.serialRxBuffer.length < totalFrameBytes) {
        // Wait for remaining frame payload bytes to arrive
        return;
      }

      // Extract raw protobuf packet bytes
      const protobufBytes = this.serialRxBuffer.slice(4, totalFrameBytes);
      this.serialRxBuffer = this.serialRxBuffer.slice(totalFrameBytes);

      // Process decoded protobuf
      this.processIncomingProtobuf(protobufBytes);
    }
  }

  private handleSerialDisconnect(): void {
    console.warn('[Meshtastic Serial] Serial port disconnected.');
    this.stopKeepalive();
    this.stopPhoneGpsAutoSync();
    useMeshStore.getState().setConnectionState('DISCONNECTED', 'NONE', 'USB Serial node disconnected');
  }

  // ==========================================
  // 3. INCOMING PROTOBUF DISPATCH & STATE SYNC
  // ==========================================

  private processIncomingProtobuf(bytes: Uint8Array): void {
    try {
      const fromRadio = fromBinary(Mesh.FromRadioSchema, bytes);
      const store = useMeshStore.getState();

      const variant = fromRadio.payloadVariant;
      if (!variant) return;

      const logId = `pkt-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`;
      const payloadHex = Array.from(bytes)
        .map((b) => b.toString(16).padStart(2, '0'))
        .join(' ');

      switch (variant.case) {
        case 'myInfo': {
          const myInfo = variant.value;
          const myNodeNum = myInfo.myNodeNum >>> 0;
          const hexId = `!${myNodeNum.toString(16).padStart(8, '0')}`;

          store.setLocalNodeInfo({
            myNodeNum,
            hexId,
            rebootCount: myInfo.rebootCount,
            firmwareVersion: myInfo.pioEnv ? `${myInfo.pioEnv}` : 'XIAO-C6 Meshtastic',
          });

          store.upsertNode({
            num: myNodeNum,
            hexId,
            isLocal: true,
            hwModel: 'Seeed XIAO ESP32C6',
            lastHeard: Date.now(),
          });

          store.addRawPacketLog({
            id: logId,
            direction: 'RX',
            timestamp: Date.now(),
            portnum: 'MY_INFO',
            portnumId: 0,
            from: myNodeNum,
            to: myNodeNum,
            packetId: fromRadio.id,
            payloadLength: bytes.length,
            payloadHex,
            summary: `Local Node Identified: ${hexId} (reboots: ${myInfo.rebootCount})`,
            rawJson: JSON.stringify(myInfo, null, 2),
          });
          break;
        }

        case 'metadata': {
          const meta = variant.value;
          store.setLocalNodeInfo({
            firmwareVersion: meta.firmwareVersion || 'Rescue Node C6',
          });

          store.addRawPacketLog({
            id: logId,
            direction: 'RX',
            timestamp: Date.now(),
            portnum: 'METADATA',
            portnumId: 0,
            from: 0,
            to: 0,
            packetId: fromRadio.id,
            payloadLength: bytes.length,
            payloadHex,
            summary: `Device Metadata: ${meta.firmwareVersion} (HW: ${meta.hwModel})`,
          });
          break;
        }

        case 'nodeInfo': {
          const nodeInfo = variant.value;
          const num = nodeInfo.num >>> 0;
          const hexId = `!${num.toString(16).padStart(8, '0')}`;
          const isLocal = store.localNode?.myNodeNum === num;

          const shortName = nodeInfo.user?.shortName || hexId.slice(-4).toUpperCase();
          const longName = nodeInfo.user?.longName || `Node ${hexId}`;
          const hwModelName = nodeInfo.user?.hwModel !== undefined
            ? Mesh.HardwareModel[nodeInfo.user.hwModel] || 'Seeed XIAO ESP32C6'
            : 'Seeed XIAO ESP32C6';

          let pos: NodePosition | undefined;
          if (nodeInfo.position) {
            const p = nodeInfo.position;
            const lat = (p.latitudeI ?? 0) * 1e-7;
            const lng = (p.longitudeI ?? 0) * 1e-7;
            if (lat !== 0 || lng !== 0) {
              pos = {
                latitude: lat,
                longitude: lng,
                altitude: p.altitude,
                satsInView: p.satsInView,
                groundSpeed: p.groundSpeed,
                time: p.time,
              };
            }
          }

          store.upsertNode({
            num,
            hexId,
            shortName,
            longName,
            hwModel: hwModelName,
            snr: nodeInfo.snr ?? 0,
            lastHeard: nodeInfo.lastHeard ? nodeInfo.lastHeard * 1000 : Date.now(),
            hopsAway: nodeInfo.hopsAway ?? 0,
            isLocal,
            ...(pos ? { position: pos } : {}),
            ...(nodeInfo.deviceMetrics
              ? {
                  metrics: {
                    batteryLevel: nodeInfo.deviceMetrics.batteryLevel,
                    voltage: nodeInfo.deviceMetrics.voltage,
                    channelUtilization: nodeInfo.deviceMetrics.channelUtilization,
                    airUtilTx: nodeInfo.deviceMetrics.airUtilTx,
                    uptimeSeconds: nodeInfo.deviceMetrics.uptimeSeconds,
                  },
                }
              : {}),
          });

          if (isLocal) {
            store.setLocalNodeInfo({
              shortName,
              longName,
              ...(pos ? { position: pos } : {}),
              ...(nodeInfo.deviceMetrics
                ? {
                    batteryLevel: nodeInfo.deviceMetrics.batteryLevel,
                    voltage: nodeInfo.deviceMetrics.voltage,
                    channelUtilization: nodeInfo.deviceMetrics.channelUtilization,
                    airUtilTx: nodeInfo.deviceMetrics.airUtilTx,
                    uptimeSeconds: nodeInfo.deviceMetrics.uptimeSeconds,
                  }
                : {}),
            });
          }

          store.addRawPacketLog({
            id: logId,
            direction: 'RX',
            timestamp: Date.now(),
            portnum: 'NODE_INFO',
            portnumId: 4,
            from: num,
            to: 0,
            packetId: fromRadio.id,
            payloadLength: bytes.length,
            payloadHex,
            summary: `NodeDB Entry: ${shortName} (${hexId}) - SNR: ${nodeInfo.snr}dB`,
          });
          break;
        }

        case 'configCompleteId': {
          store.setConnectionState('CONNECTED');
          console.log('[Meshtastic] Hardware config sync complete. Config ID:', variant.value);

          // Automatically push phone GPS coordinates to the ESP32 node upon connection
          this.startPhoneGpsAutoSync();

          store.addRawPacketLog({
            id: logId,
            direction: 'RX',
            timestamp: Date.now(),
            portnum: 'CONFIG_COMPLETE',
            portnumId: 0,
            from: 0,
            to: 0,
            packetId: fromRadio.id,
            payloadLength: bytes.length,
            payloadHex,
            summary: `Hardware Config Synced (ID: ${variant.value})`,
          });
          break;
        }

        case 'logRecord': {
          const log = variant.value;
          const msg = log.message || '';
          if (msg.toLowerCase().includes('mpu') || msg.toLowerCase().includes('motion') || msg.toLowerCase().includes('accel')) {
            if (store.localNode) {
              store.setLocalNodeInfo({
                hardware: {
                  ...store.localNode.hardware,
                  mpu6050I2c: true,
                },
              });
            }
          }

          store.addRawPacketLog({
            id: logId,
            direction: 'RX',
            timestamp: Date.now(),
            portnum: 'LOG_RECORD',
            portnumId: 0,
            from: 0,
            to: 0,
            packetId: fromRadio.id,
            payloadLength: bytes.length,
            payloadHex,
            summary: `Node Log: ${msg}`,
          });
          break;
        }

        case 'packet': {
          this.handleMeshPacket(variant.value, bytes, payloadHex, logId);
          break;
        }

        default: {
          const caseName = variant.case ? String(variant.case).toUpperCase() : 'UNKNOWN';
          store.addRawPacketLog({
            id: logId,
            direction: 'RX',
            timestamp: Date.now(),
            portnum: caseName,
            portnumId: 0,
            from: 0,
            to: 0,
            packetId: fromRadio.id,
            payloadLength: bytes.length,
            payloadHex,
            summary: `FromRadio Frame: ${caseName}`,
          });
          break;
        }
      }
    } catch (err) {
      console.error('[Meshtastic] Error decoding FromRadio protobuf:', err);
    }
  }

  /**
   * Handle decrypted / decoded MeshPacket frames
   */
  private handleMeshPacket(
    packet: any,
    rawBytes: Uint8Array,
    payloadHex: string,
    logId: string
  ): void {
    const store = useMeshStore.getState();
    const fromNum = packet.from >>> 0;
    const toNum = packet.to >>> 0;
    const packetId = packet.id >>> 0;
    const fromHex = `!${fromNum.toString(16).padStart(8, '0')}`;
    const rxSnr = packet.rxSnr;
    const rxRssi = packet.rxRssi;
    const hopLimit = packet.hopLimit;
    const hopStart = packet.hopStart;

    // Refresh lastHeard and RF stats for sender node
    store.upsertNode({
      num: fromNum,
      hexId: fromHex,
      lastHeard: Date.now(),
      snr: rxSnr ?? 0,
      rssi: rxRssi,
      hopsAway: hopStart && hopLimit !== undefined ? Math.max(0, hopStart - hopLimit) : 0,
    });

    if (packet.payloadVariant?.case !== 'decoded') {
      // Encrypted or non-decoded packet
      store.addRawPacketLog({
        id: logId,
        direction: 'RX',
        timestamp: Date.now(),
        portnum: 'ENCRYPTED_OR_OPAQUE',
        portnumId: 0,
        from: fromNum,
        to: toNum,
        packetId,
        rxSnr,
        rxRssi,
        hopLimit,
        hopStart,
        payloadLength: rawBytes.length,
        payloadHex,
        summary: `Encrypted Frame from ${fromHex}`,
      });
      return;
    }

    const data = packet.payloadVariant.value;
    const portnum = data.portnum as number;
    const portnumName = Portnums.PortNum[portnum] || `PORT_${portnum}`;
    const payload = data.payload as Uint8Array;

    store.addRawPacketLog({
      id: logId,
      direction: 'RX',
      timestamp: Date.now(),
      portnum: portnumName,
      portnumId: portnum,
      from: fromNum,
      to: toNum,
      packetId,
      rxSnr,
      rxRssi,
      hopLimit,
      hopStart,
      payloadLength: payload.length,
      payloadHex: Array.from(payload).map((b) => b.toString(16).padStart(2, '0')).join(' '),
      summary: `Decoded ${portnumName} packet (${payload.length} B) from ${fromHex}`,
    });

    switch (portnum) {
      // 1. TEXT_MESSAGE_APP
      case Portnums.PortNum.TEXT_MESSAGE_APP:
      case Portnums.PortNum.TEXT_MESSAGE_COMPRESSED_APP: {
        const text = new TextDecoder().decode(payload);
        const isEmergency =
          packet.priority === Mesh.MeshPacket_Priority.ALERT ||
          text.toUpperCase().includes('SOS') ||
          text.toUpperCase().includes('CRASH') ||
          text.toUpperCase().includes('EMERGENCY') ||
          text.toUpperCase().includes('MAYDAY');

        const chatMsg: MeshChatMessage = {
          id: `msg-${packetId}`,
          from: fromNum,
          to: toNum,
          text,
          timestamp: Date.now(),
          rxSnr,
          rxRssi,
          hopLimit,
          hopStart,
          isDirect: toNum !== 0xffffffff,
          isAlert: isEmergency,
          ackStatus: 'RECEIVED',
          packetId,
        };

        store.addChatMessage(chatMsg);

        if (isEmergency) {
          const senderNode = store.nodes[fromNum];
          store.upsertNode({
            num: fromNum,
            isEmergency: true,
            emergencyTimestamp: Date.now(),
            emergencyNote: text,
          });

          store.addDistressAlert({
            id: `sos-${packetId}`,
            senderNum: fromNum,
            senderHex: fromHex,
            senderName: senderNode?.shortName || fromHex,
            alertType: text.toUpperCase().includes('CRASH') ? 'FALL_DETECTED' : 'MANUAL_SOS',
            message: text,
            timestamp: Date.now(),
            position: senderNode?.position,
            acknowledged: false,
          });
        }
        break;
      }

      // 2. POSITION_APP (NEO-6M GPS)
      case Portnums.PortNum.POSITION_APP: {
        try {
          const posProto = fromBinary(Mesh.PositionSchema, payload);
          const lat = (posProto.latitudeI ?? 0) * 1e-7;
          const lng = (posProto.longitudeI ?? 0) * 1e-7;

          if (lat !== 0 || lng !== 0) {
            const pos: NodePosition = {
              latitude: lat,
              longitude: lng,
              altitude: posProto.altitude,
              satsInView: posProto.satsInView,
              groundSpeed: posProto.groundSpeed,
              time: posProto.time,
            };

            store.upsertNode({
              num: fromNum,
              position: pos,
              lastHeard: Date.now(),
            });

            if (fromNum === store.localNode?.myNodeNum) {
              store.setLocalNodeInfo({
                position: pos,
                hardware: {
                  ...store.localNode.hardware,
                  neo6mGpsUart: true,
                },
              });
            }
          }
        } catch (e) {
          console.error('[Meshtastic] Error decoding Position packet:', e);
        }
        break;
      }

      // 3. TELEMETRY_APP (DeviceMetrics, Environment, Power)
      case Portnums.PortNum.TELEMETRY_APP: {
        try {
          const telem = fromBinary(Telemetry.TelemetrySchema, payload);
          if (telem.variant?.case === 'deviceMetrics') {
            const dm = telem.variant.value;
            store.upsertNode({
              num: fromNum,
              metrics: {
                batteryLevel: dm.batteryLevel,
                voltage: dm.voltage,
                channelUtilization: dm.channelUtilization,
                airUtilTx: dm.airUtilTx,
                uptimeSeconds: dm.uptimeSeconds,
              },
            });

            if (fromNum === store.localNode?.myNodeNum) {
              store.setLocalNodeInfo({
                batteryLevel: dm.batteryLevel,
                voltage: dm.voltage,
                channelUtilization: dm.channelUtilization,
                airUtilTx: dm.airUtilTx,
                uptimeSeconds: dm.uptimeSeconds,
              });
            }
          }
        } catch (e) {
          console.error('[Meshtastic] Error decoding Telemetry packet:', e);
        }
        break;
      }

      // 4. DETECTION_SENSOR_APP & ALERT_APP (GPIO16 SOS Button & MPU6050 Fall Alert)
      case Portnums.PortNum.DETECTION_SENSOR_APP:
      case Portnums.PortNum.ALERT_APP: {
        const textNote = payload.length > 0 ? new TextDecoder().decode(payload) : 'Tactical Sensor Trigger';
        const isFall = textNote.toLowerCase().includes('fall') || textNote.toLowerCase().includes('motion');
        const alertType = isFall ? 'FALL_DETECTED' : 'HARDWARE_BUTTON';

        const senderNode = store.nodes[fromNum];
        store.upsertNode({
          num: fromNum,
          isEmergency: true,
          emergencyTimestamp: Date.now(),
          emergencyNote: textNote,
          fallDetected: isFall,
        });

        if (fromNum === store.localNode?.myNodeNum) {
          store.setLocalNodeInfo({
            hardware: {
              ...store.localNode.hardware,
              mpu6050I2c: isFall ? true : store.localNode.hardware.mpu6050I2c,
              sosButtonD6: !isFall ? true : store.localNode.hardware.sosButtonD6,
            },
          });
        }

        store.addDistressAlert({
          id: `sos-sensor-${packetId}`,
          senderNum: fromNum,
          senderHex: fromHex,
          senderName: senderNode?.shortName || fromHex,
          alertType,
          message: textNote,
          timestamp: Date.now(),
          position: senderNode?.position,
          acknowledged: false,
        });
        break;
      }

      // 5. TRACEROUTE_APP
      case Portnums.PortNum.TRACEROUTE_APP: {
        try {
          const routeProto = fromBinary(Mesh.RouteDiscoverySchema, payload);
          const routeTowards: TracerouteHop[] = (routeProto.route || []).map((nodeNum, idx) => {
            const hHex = `!${(nodeNum >>> 0).toString(16).padStart(8, '0')}`;
            const n = store.nodes[nodeNum >>> 0];
            return {
              nodeNum: nodeNum >>> 0,
              nodeHex: hHex,
              nodeName: n?.shortName || hHex,
              snr: routeProto.snrTowards?.[idx] ?? 0,
            };
          });

          const routeBack: TracerouteHop[] = (routeProto.routeBack || []).map((nodeNum, idx) => {
            const hHex = `!${(nodeNum >>> 0).toString(16).padStart(8, '0')}`;
            const n = store.nodes[nodeNum >>> 0];
            return {
              nodeNum: nodeNum >>> 0,
              nodeHex: hHex,
              nodeName: n?.shortName || hHex,
              snr: routeProto.snrBack?.[idx] ?? 0,
            };
          });

          store.addTracerouteResult({
            id: `tr-${Date.now()}`,
            targetNum: fromNum,
            targetHex: fromHex,
            timestamp: Date.now(),
            routeTowards,
            routeBack,
            complete: true,
          });
        } catch (e) {
          console.error('[Meshtastic] Error decoding Traceroute packet:', e);
        }
        break;
      }

      // 6. ROUTING_APP (ACK / NAK resolution)
      case Portnums.PortNum.ROUTING_APP: {
        try {
          const routingProto = fromBinary(Mesh.RoutingSchema, payload);
          if (data.requestId) {
            const reqId = data.requestId >>> 0;
            if (routingProto.variant?.case === 'errorReason') {
              store.updateMessageAck(reqId, 'FAILED', fromNum);
            } else {
              store.updateMessageAck(reqId, 'ACKED', fromNum);
            }
          }
        } catch (e) {
          console.error('[Meshtastic] Error decoding Routing packet:', e);
        }
        break;
      }

      default:
        break;
    }
  }

  // ==========================================
  // 4. TRANSMISSION (ToRadio) DISPATCH
  // ==========================================

  private async sendToRadioRaw(protobufBytes: Uint8Array): Promise<boolean> {
    const store = useMeshStore.getState();

    // BLE Path
    if (store.transportType === 'BLE') {
      if (Capacitor.isNativePlatform() && this.nativeBleDeviceId) {
        try {
          const dv = new DataView(
            protobufBytes.buffer,
            protobufBytes.byteOffset,
            protobufBytes.byteLength
          );
          await BleClient.write(
            this.nativeBleDeviceId,
            MESHTASTIC_BLE_SERVICE_UUID,
            TO_RADIO_UUID_PRIMARY,
            dv
          );
          return true;
        } catch (err) {
          console.error('[Meshtastic Native BLE] writeToRadio failed:', err);
          return false;
        }
      }

      if (this.toRadioChar) {
        try {
          const bufferSource = protobufBytes.buffer.slice(
            protobufBytes.byteOffset,
            protobufBytes.byteOffset + protobufBytes.byteLength
          ) as ArrayBuffer;

          if (this.toRadioChar.properties.writeWithoutResponse) {
            await this.toRadioChar.writeValueWithoutResponse(bufferSource);
          } else {
            await this.toRadioChar.writeValue(bufferSource);
          }
          return true;
        } catch (err) {
          console.error('[Meshtastic BLE] writeToRadio failed:', err);
          return false;
        }
      }
    }

    // Serial Path: Prefix with [0x94, 0xC3, (len >> 8) & 0xFF, len & 0xFF]
    if (store.transportType === 'SERIAL' && this.serialWriter) {
      try {
        const len = protobufBytes.length;
        const framed = new Uint8Array(4 + len);
        framed[0] = SERIAL_FRAME_START_1;
        framed[1] = SERIAL_FRAME_START_2;
        framed[2] = (len >> 8) & 0xff;
        framed[3] = len & 0xff;
        framed.set(protobufBytes, 4);

        await this.serialWriter.write(framed);
        return true;
      } catch (err) {
        console.error('[Meshtastic Serial] writeToRadio failed:', err);
        return false;
      }
    }

    console.warn('[Meshtastic] Cannot send ToRadio: No active hardware connection.');
    return false;
  }

  /**
   * Handshake: Request configuration & NodeDB from connected radio
   */
  public async sendWantConfigId(configId: number): Promise<boolean> {
    const toRadio = create(Mesh.ToRadioSchema, {
      payloadVariant: {
        case: 'wantConfigId',
        value: configId,
      },
    });

    const bytes = toBinary(Mesh.ToRadioSchema, toRadio);
    const success = await this.sendToRadioRaw(bytes);

    if (success) {
      const store = useMeshStore.getState();
      store.addRawPacketLog({
        id: `tx-handshake-${Date.now()}`,
        direction: 'TX',
        timestamp: Date.now(),
        portnum: 'WANT_CONFIG_ID',
        portnumId: 0,
        from: 0,
        to: 0,
        packetId: 0,
        payloadLength: bytes.length,
        payloadHex: Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join(' '),
        summary: `Handshake sent: wantConfigId(${configId})`,
      });
    }

    return success;
  }

  /**
   * Send live text message over LoRa mesh
   */
  public async sendTextMessage(
    text: string,
    destinationNode = 0xffffffff,
    wantAck = false
  ): Promise<number | null> {
    const store = useMeshStore.getState();
    const packetId = Math.floor(Math.random() * 0x7fffffff) + 1;
    const localNum = store.localNode?.myNodeNum ?? 0;

    const dataPayload = create(Mesh.DataSchema, {
      portnum: Portnums.PortNum.TEXT_MESSAGE_APP,
      payload: new TextEncoder().encode(text),
      wantResponse: wantAck,
    });

    const meshPacket = create(Mesh.MeshPacketSchema, {
      from: localNum,
      to: destinationNode,
      id: packetId,
      wantAck,
      priority: Mesh.MeshPacket_Priority.DEFAULT,
      payloadVariant: {
        case: 'decoded',
        value: dataPayload,
      },
    });

    const toRadio = create(Mesh.ToRadioSchema, {
      payloadVariant: {
        case: 'packet',
        value: meshPacket,
      },
    });

    const bytes = toBinary(Mesh.ToRadioSchema, toRadio);
    const success = await this.sendToRadioRaw(bytes);

    if (success) {
      // Add to store as outgoing message
      const chatMsg: MeshChatMessage = {
        id: `tx-msg-${packetId}`,
        from: localNum,
        to: destinationNode,
        text,
        timestamp: Date.now(),
        isDirect: destinationNode !== 0xffffffff,
        isAlert: false,
        ackStatus: wantAck ? 'SENDING' : 'RECEIVED',
        packetId,
      };

      store.addChatMessage(chatMsg);

      store.addRawPacketLog({
        id: `tx-pkt-${packetId}`,
        direction: 'TX',
        timestamp: Date.now(),
        portnum: 'TEXT_MESSAGE_APP',
        portnumId: Portnums.PortNum.TEXT_MESSAGE_APP,
        from: localNum,
        to: destinationNode,
        packetId,
        payloadLength: bytes.length,
        payloadHex: Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join(' '),
        summary: `TX Text Message to ${destinationNode === 0xffffffff ? 'BROADCAST' : `!${destinationNode.toString(16)}`}: "${text}"`,
      });

      return packetId;
    }

    return null;
  }

  /**
   * Broadcast Emergency SOS over LoRa mesh with live coordinates and activate acoustic siren
   */
  public async triggerEmergencySos(customNote?: string): Promise<number | null> {
    const store = useMeshStore.getState();
    const packetId = Math.floor(Math.random() * 0x7fffffff) + 1;
    const localNum = store.localNode?.myNodeNum ?? 0;

    // Determine best coordinates (local node NEO-6M or browser geolocation)
    let lat = store.localNode?.position?.latitude ?? 0;
    let lng = store.localNode?.position?.longitude ?? 0;

    if (lat === 0 && lng === 0 && 'geolocation' in navigator) {
      try {
        const geo = await new Promise<GeolocationPosition>((resolve, reject) => {
          navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 3000 });
        });
        lat = geo.coords.latitude;
        lng = geo.coords.longitude;
      } catch (e) {
        // Geolocation denied or unavailable
      }
    }

    const note = customNote || 'TACTICAL SOS ACTIVATED';
    const coordsStr = lat !== 0 || lng !== 0 ? ` @ ${lat.toFixed(6)}, ${lng.toFixed(6)}` : '';
    const sosText = `[EMERGENCY SOS] ${note}${coordsStr}`;

    const dataPayload = create(Mesh.DataSchema, {
      portnum: Portnums.PortNum.ALERT_APP,
      payload: new TextEncoder().encode(sosText),
      wantResponse: true,
    });

    const meshPacket = create(Mesh.MeshPacketSchema, {
      from: localNum,
      to: 0xffffffff, // Broadcast to all SAR units
      id: packetId,
      wantAck: true,
      priority: Mesh.MeshPacket_Priority.ALERT,
      payloadVariant: {
        case: 'decoded',
        value: dataPayload,
      },
    });

    const toRadio = create(Mesh.ToRadioSchema, {
      payloadVariant: {
        case: 'packet',
        value: meshPacket,
      },
    });

    const bytes = toBinary(Mesh.ToRadioSchema, toRadio);
    const success = await this.sendToRadioRaw(bytes);

    if (success) {
      const localHex = store.localNode?.hexId || '!00000000';
      const localName = store.localNode?.shortName || 'RESCUE-LOCAL';

      store.addDistressAlert({
        id: `sos-local-${packetId}`,
        senderNum: localNum,
        senderHex: localHex,
        senderName: localName,
        alertType: 'MANUAL_SOS',
        message: sosText,
        timestamp: Date.now(),
        position: lat !== 0 || lng !== 0 ? { latitude: lat, longitude: lng } : undefined,
        acknowledged: false,
      });

      store.addChatMessage({
        id: `tx-sos-${packetId}`,
        from: localNum,
        to: 0xffffffff,
        text: sosText,
        timestamp: Date.now(),
        isDirect: false,
        isAlert: true,
        ackStatus: 'SENDING',
        packetId,
      });

      store.addRawPacketLog({
        id: `tx-sos-log-${packetId}`,
        direction: 'TX',
        timestamp: Date.now(),
        portnum: 'ALERT_APP',
        portnumId: Portnums.PortNum.ALERT_APP,
        from: localNum,
        to: 0xffffffff,
        packetId,
        payloadLength: bytes.length,
        payloadHex: Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join(' '),
        summary: `BROADCAST PRIORITY ALERT SOS: ${sosText}`,
      });

      // Also trigger physical acoustic piezo siren and strobe LED on GPIO0
      await this.triggerAcousticBeacon();

      return packetId;
    }

    return null;
  }

  /**
   * Broadcast updated GPS position over mesh
   */
  public async broadcastPosition(lat: number, lng: number, alt = 0): Promise<boolean> {
    const store = useMeshStore.getState();
    const packetId = Math.floor(Math.random() * 0x7fffffff) + 1;
    const localNum = store.localNode?.myNodeNum ?? 0;

    const posProto = create(Mesh.PositionSchema, {
      latitudeI: Math.round(lat * 1e7),
      longitudeI: Math.round(lng * 1e7),
      altitude: Math.round(alt),
      time: Math.floor(Date.now() / 1000),
    });

    const dataPayload = create(Mesh.DataSchema, {
      portnum: Portnums.PortNum.POSITION_APP,
      payload: toBinary(Mesh.PositionSchema, posProto),
    });

    const meshPacket = create(Mesh.MeshPacketSchema, {
      from: localNum,
      to: localNum || 0xffffffff,
      id: packetId,
      priority: Mesh.MeshPacket_Priority.DEFAULT,
      payloadVariant: {
        case: 'decoded',
        value: dataPayload,
      },
    });

    const toRadio = create(Mesh.ToRadioSchema, {
      payloadVariant: {
        case: 'packet',
        value: meshPacket,
      },
    });

    const bytes = toBinary(Mesh.ToRadioSchema, toRadio);
    const success = await this.sendToRadioRaw(bytes);

    if (success) {
      store.setLocalNodeInfo({
        position: {
          latitude: lat,
          longitude: lng,
          altitude: alt,
          time: Math.floor(Date.now() / 1000),
        },
      });

      store.addRawPacketLog({
        id: `tx-pos-${packetId}`,
        direction: 'TX',
        timestamp: Date.now(),
        portnum: 'POSITION_APP',
        portnumId: Portnums.PortNum.POSITION_APP,
        from: localNum,
        to: 0xffffffff,
        packetId,
        payloadLength: bytes.length,
        payloadHex: Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join(' '),
        summary: `TX Position: ${lat.toFixed(6)}, ${lng.toFixed(6)} (${alt}m)`,
      });
    }

    return success;
  }

  /**
   * Send traceroute request to measured hop-by-hop link SNR
   */
  public async sendTraceroute(targetNodeNum: number): Promise<boolean> {
    const store = useMeshStore.getState();
    const packetId = Math.floor(Math.random() * 0x7fffffff) + 1;
    const localNum = store.localNode?.myNodeNum ?? 0;

    const routeDiscovery = create(Mesh.RouteDiscoverySchema, {
      route: [],
    });

    const dataPayload = create(Mesh.DataSchema, {
      portnum: Portnums.PortNum.TRACEROUTE_APP,
      payload: toBinary(Mesh.RouteDiscoverySchema, routeDiscovery),
      wantResponse: true,
      dest: targetNodeNum,
    });

    const meshPacket = create(Mesh.MeshPacketSchema, {
      from: localNum,
      to: targetNodeNum,
      id: packetId,
      wantAck: true,
      priority: Mesh.MeshPacket_Priority.RELIABLE,
      payloadVariant: {
        case: 'decoded',
        value: dataPayload,
      },
    });

    const toRadio = create(Mesh.ToRadioSchema, {
      payloadVariant: {
        case: 'packet',
        value: meshPacket,
      },
    });

    const bytes = toBinary(Mesh.ToRadioSchema, toRadio);
    const success = await this.sendToRadioRaw(bytes);

    if (success) {
      store.addRawPacketLog({
        id: `tx-trace-${packetId}`,
        direction: 'TX',
        timestamp: Date.now(),
        portnum: 'TRACEROUTE_APP',
        portnumId: Portnums.PortNum.TRACEROUTE_APP,
        from: localNum,
        to: targetNodeNum,
        packetId,
        payloadLength: bytes.length,
        payloadHex: Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join(' '),
        summary: `Traceroute initiated towards !${targetNodeNum.toString(16)}`,
      });
    }

    return success;
  }

  /**
   * Activates Acoustic Siren Piezo Buzzer & LED on GPIO0 / D0
   */
  public async triggerAcousticBeacon(targetNode = 0xffffffff): Promise<boolean> {
    const store = useMeshStore.getState();
    const packetId = Math.floor(Math.random() * 0x7fffffff) + 1;
    const localNum = store.localNode?.myNodeNum ?? 0;

    // Use ALERT_APP payload to trigger beacon
    const dataPayload = create(Mesh.DataSchema, {
      portnum: Portnums.PortNum.ALERT_APP,
      payload: new TextEncoder().encode('SIREN_BEACON_ACTIVE:1'),
      wantResponse: false,
    });

    const meshPacket = create(Mesh.MeshPacketSchema, {
      from: localNum,
      to: targetNode,
      id: packetId,
      priority: Mesh.MeshPacket_Priority.ALERT,
      payloadVariant: {
        case: 'decoded',
        value: dataPayload,
      },
    });

    const toRadio = create(Mesh.ToRadioSchema, {
      payloadVariant: {
        case: 'packet',
        value: meshPacket,
      },
    });

    const bytes = toBinary(Mesh.ToRadioSchema, toRadio);
    const success = await this.sendToRadioRaw(bytes);

    if (success && store.localNode) {
      store.setLocalNodeInfo({
        hardware: {
          ...store.localNode.hardware,
          piezoBeaconD0: true,
        },
      });
    }

    return success;
  }

  // ==========================================
  // 5. LIFECYCLE & DISCONNECTION
  // ==========================================

  private startKeepalive(): void {
    this.stopKeepalive();
    // Heartbeat every 45s
    this.keepaliveTimer = window.setInterval(async () => {
      const store = useMeshStore.getState();
      if (store.connectionState === 'CONNECTED') {
        const toRadio = create(Mesh.ToRadioSchema, {
          payloadVariant: {
            case: 'heartbeat',
            value: create(Mesh.HeartbeatSchema, {}),
          },
        });
        const bytes = toBinary(Mesh.ToRadioSchema, toRadio);
        await this.sendToRadioRaw(bytes);
      }
    }, 45000);
  }

  private stopKeepalive(): void {
    if (this.keepaliveTimer) {
      clearInterval(this.keepaliveTimer);
      this.keepaliveTimer = null;
    }
  }

  /**
   * Automatically pushes current browser/phone GPS coordinates to the Rescue Node
   */
  public syncPhoneLocationToNode(): void {
    if (typeof navigator === 'undefined' || !navigator.geolocation) {
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const { latitude, longitude, altitude } = pos.coords;
        console.log(`[Meshtastic] Auto-syncing phone GPS to Rescue Node: ${latitude.toFixed(6)}, ${longitude.toFixed(6)}`);
        this.broadcastPosition(latitude, longitude, altitude ?? 0).catch(err => {
          console.warn('[Meshtastic] Auto GPS sync broadcast failed:', err);
        });
      },
      (err) => {
        console.warn('[Meshtastic] Browser geolocation unavailable for auto-sync:', err.message);
      },
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 30000 }
    );
  }

  public startPhoneGpsAutoSync(): void {
    this.stopPhoneGpsAutoSync();
    // Immediate initial sync upon connection
    this.syncPhoneLocationToNode();
    // Auto-sync periodically every 45s while connected
    this.gpsSyncInterval = setInterval(() => {
      this.syncPhoneLocationToNode();
    }, 45000);
  }

  public stopPhoneGpsAutoSync(): void {
    if (this.gpsSyncInterval) {
      clearInterval(this.gpsSyncInterval);
      this.gpsSyncInterval = null;
    }
  }

  public async disconnect(): Promise<void> {
    this.stopKeepalive();
    this.stopPhoneGpsAutoSync();

    // Disconnect BLE
    if (this.nativeBleDeviceId) {
      try {
        await BleClient.disconnect(this.nativeBleDeviceId);
      } catch (e) {}
      this.nativeBleDeviceId = null;
    }

    if (this.bleDevice?.gatt?.connected) {
      try {
        if (this.fromNumChar) {
          await this.fromNumChar.stopNotifications().catch(() => {});
        }
        this.bleDevice.gatt.disconnect();
      } catch (e) {
        console.warn('Error disconnecting BLE GATT:', e);
      }
    }
    this.bleDevice = null;
    this.toRadioChar = null;
    this.fromRadioChar = null;
    this.fromNumChar = null;

    // Disconnect Serial
    if (this.serialReadAbortController) {
      this.serialReadAbortController.abort();
      this.serialReadAbortController = null;
    }

    if (this.serialReader) {
      try {
        await this.serialReader.cancel().catch(() => {});
        this.serialReader.releaseLock();
      } catch (e) {}
      this.serialReader = null;
    }

    if (this.serialWriter) {
      try {
        await this.serialWriter.close().catch(() => {});
        this.serialWriter.releaseLock();
      } catch (e) {}
      this.serialWriter = null;
    }

    if (this.serialPort) {
      try {
        await this.serialPort.close().catch(() => {});
      } catch (e) {}
      this.serialPort = null;
    }

    this.serialRxBuffer = new Uint8Array(0);
    useMeshStore.getState().setConnectionState('DISCONNECTED', 'NONE');
  }
}

export const meshtasticTransport = new MeshtasticTransportService();
