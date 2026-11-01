# SAR Tactical Command & Tactical Mesh Application

Production-grade Search & Rescue (SAR) Command Application built for official Meshtastic LoRa hardware running on the **Seeed Studio XIAO ESP32-C6** (`env:rescue_node_c6`) with **IndieSemiC SX1262 LoRa** transceiver.

---

## ⚡ Zero Mock Data Guarantee
- **100% Hardware Ground Truth:** No mock generators, fake intervals, or simulated GPS tracks.
- Every metric, node, packet, battery voltage, and SNR reading is decoded live from Meshtastic Protobuf frames (`FromRadio`) received over **BLE 5.0** or **Native USB CDC Serial**.
- If no node is linked, the UI stays in a clean, honest **Awaiting Hardware Link** state.

---

## 🛠️ Hardware Specification (Rescue Node C6)
- **MCU:** Seeed Studio XIAO ESP32-C6 (160MHz 32-bit RISC-V, USB VID `0x303A`, PID `0x1001`).
- **LoRa Radio:** IndieSemiC SX1262 (`865-868 MHz` India/EU ISM band) on SPI (SCK=D8, MISO=D9, MOSI=D10, CS=D3, DIO1=D2, BUSY=D1).
- **GPS:** u-blox NEO-6M on UART RX (`GPIO17 / D7`, 9600 baud passive NMEA streaming -> Meshtastic `PortNum.POSITION_APP`).
- **Inertial Sensor:** MPU6050 6-Axis IMU on I2C (`SDA=GPIO22/D4, SCL=GPIO23/D5` -> Meshtastic `DetectionSensorModule` fall/motion alert).
- **Emergency SOS Input:** Waterproof Tactile Push Button on `GPIO16 / D6` (Active LOW) + Onboard Button on `GPIO9`.
- **Acoustic/Visual Beacon:** 3V SMD Piezo Siren & Status Strobe LED in parallel on `GPIO0 / D0`.
- **Power:** 3000mAh 3.7V LiPo + TP4056 + AP2112K 3.3V LDO.

---

## 🚀 Quick Start Instructions

### 1. Run Development Server
```bash
npm run dev
```
Open **`http://localhost:3000`** in Google Chrome, Microsoft Edge, or Chromium on Desktop or Android.

### 2. Connect Your Hardware Node

#### Option A: Bluetooth Low Energy (BLE 5.0)
1. Turn on your Seeed XIAO ESP32-C6 node.
2. In the top bar or modal, click **`LINK BLE`**.
3. Select your device from the browser Bluetooth prompt (e.g. `Meshtastic_af88`).
4. Enter default headless pairing PIN: **`123456`**.

#### Option B: Native USB CDC Serial (COM Port / OTG)
1. Plug the node into your computer or Android device via USB-C.
2. Click **`LINK USB (COM)`**.
3. Select the Espressif USB JTAG/serial debug unit (VID: `0x303A`, PID: `0x1001`).

---

## 📋 Features & Views

### 1. Top Tactical Telemetry Bar (Always Visible)
- Real-time connection badge (`BLE 5.0 LINKED`, `USB CDC COM7`, `DISCONNECTED`).
- Connected node identity (`ShortName`, `!HexID`, hardware model).
- Real-time telemetry pills: Battery %, voltage, LoRa SNR (`dB`), RSSI (`dBm`), NEO-6M GPS satellite lock count, and active mesh nodes.
- One-click trigger for physical 3V SMD Piezo Siren on `GPIO0`.

### 2. View 1: SAR Tactical Map & Situational Awareness
- Interactive map (`leaflet` + `react-leaflet`) with Dark Carto, Topo, and Street tile layers.
- Custom tactical markers showing callsign, battery, SNR, and time since last heard.
- Emergency SOS nodes flash with a high-visibility crimson radar ring and display live distance + bearing from your local node.
- Real-time polyline rendering of multi-hop mesh routes from traceroute packets.
- "Broadcast Local GPS" action.

### 3. View 2: Emergency SOS & SAR Beacon Console
- **Guarded 2-Second Hold-to-Transmit SOS:** Tactile button with animated progress ring that broadcasts high-priority `ALERT_APP` packets over the SX1262 LoRa mesh with live coordinates.
- **Incoming Distress Feed:** Live stream of incoming `ALERT_APP` and `DETECTION_SENSOR_APP` packets (GPIO16 hardware button / MPU6050 fall triggers) with one-click **"Map"** and **"Send SAR Acknowledge"** actions.
- Direct **"Trigger Piezo Siren on GPIO0"** beacon activator.

### 4. View 3: Mesh Comms & Packet Inspector
- Real-time LoRa mesh chat supporting Broadcast (`0xFFFFFFFF`) and Direct node-to-node addressing.
- Canned SAR tactical presets for fast field SITREP transmission.
- Delivery ACK tracking (`Sending` -> `Routing` -> `ACK Confirmed`).
- **Live Raw Packet Inspector Drawer:** Real-time stream of all decoded `FromRadio` and `ToRadio` Protobuf frames with raw hex payload inspection, JSON structure viewer, direction/port filters, and clipboard copy.

### 5. View 4: Node Directory & XIAO-C6 Hardware Diagnostics
- Sortable table of all mesh nodes (`NodeInfo`) with one-click **Traceroute** and **Direct Comms**.
- **Rescue Node C6 Architecture Panel:** Visual 11-pin hardware pinout mapping (SX1262 SPI, NEO-6M UART RX on GPIO17, MPU6050 I2C on GPIO22/23, SOS Button on GPIO16, Piezo on GPIO0) and power bus status.

---

## 📱 Mobile Deployment (Capacitor Android)
The project is preconfigured with `@capacitor/core` and `@capacitor/cli`:
```bash
npm run build
npx cap add android
npx cap sync
npx cap open android
```
The application runs as a native Android APK with direct USB-OTG and BLE support.
