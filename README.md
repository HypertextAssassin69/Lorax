# Lorax 🌲📡
> **A low-cost, off-grid tactical search & rescue tracking system used to track down people in places with zero cellular network or GPS infrastructure.**

[![Live Web App](https://img.shields.io/badge/Web%20App-Live%20on%20GitHub%20Pages-00F0FF?style=for-the-badge&logo=github)](https://hypertextassassin69.github.io/Lorax/)
[![Download Android APK](https://img.shields.io/badge/Download-Android%20APK%20(Latest)-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/HypertextAssassin69/Lorax/releases/download/latest-apk/Lorax-SAR-Tactical-Command.apk)

- 🌐 **Live Web App:** [https://hypertextassassin69.github.io/Lorax/](https://hypertextassassin69.github.io/Lorax/)
- 📱 **Direct Android APK Download:** [Lorax-SAR-Tactical-Command.apk](https://github.com/HypertextAssassin69/Lorax/releases/download/latest-apk/Lorax-SAR-Tactical-Command.apk)
- 📦 **GitHub Releases:** [Latest APK Release Page](https://github.com/HypertextAssassin69/Lorax/releases/tag/latest-apk)

Production-grade Search & Rescue (SAR) Tactical Command Application and embedded firmware running on **Seeed Studio XIAO ESP32-C6** (`env:rescue_node_c6`) with **IndieSemiC SX1262 LoRa** transceiver, **MPU6050 6-Axis Crash & Fall Detection**, and **u-blox NEO-6M GPS**.

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
- **Inertial Sensor:** MPU6050 6-Axis IMU on I2C (`SDA=GPIO22/D4, SCL=GPIO23/D5` -> 50Hz polling with vector magnitude impact trigger $>2.5\text{G}$).
- **Emergency SOS Input:** Waterproof Tactile Push Button on `GPIO16 / D6` (Active LOW) + Onboard Button on `GPIO9`.
- **Acoustic/Visual Beacon:** 3V SMD Piezo Siren & Status Strobe LED in parallel on `GPIO0 / D0`.
- **Power:** 3000mAh 3.7V LiPo (NovaBat 105050) + TP4056 Type-C Charging Module.

---

## 🌐 Live Web Command Center
The application runs directly in any modern browser supporting **Web Bluetooth** or **Web Serial** (Chrome, Edge, Opera on Desktop & Android).

### Running Locally
```bash
npm install
npm run dev
```
Open **`https://localhost:3000`** in your browser.

---

## 🚀 Quick Connect Guide

### 1. Bluetooth Low Energy (BLE 5.0)
1. Turn on your Seeed XIAO ESP32-C6 node.
2. In the top navigation bar, click **`LINK BLE`**.
3. Select your device from the browser Bluetooth prompt (e.g. `Meshtastic_af88` / `Meshtastic_aee8`).
4. Enter default pairing PIN: **`123456`**.

### 2. Native USB CDC Serial (COM Port / OTG)
1. Plug the node into your computer or Android device via USB-C.
2. Click **`LINK USB (COM)`**.
3. Select the Espressif USB JTAG/serial debug unit (VID: `0x303A`, PID: `0x1001`).

---

## 📋 Features & Architecture

### 1. Top Tactical Telemetry Bar
- Real-time connection badge (`BLE 5.0 LINKED`, `USB CDC COM`, `DISCONNECTED`).
- Connected node identity (`ShortName`, `!HexID`, hardware model).
- Real-time telemetry pills: Battery %, voltage, LoRa SNR (`dB`), RSSI (`dBm`), NEO-6M GPS satellite lock count, and active mesh nodes.
- One-click trigger for physical 3V SMD Piezo Siren on `GPIO0`.

### 2. SAR Tactical Map & Situational Awareness
- Interactive map (`leaflet` + `react-leaflet`) with Dark Carto, Topo, and Street tile layers.
- Custom tactical markers showing callsign, battery, SNR, and time since last heard.
- Emergency SOS nodes flash with a high-visibility crimson radar ring and display live distance + bearing from your local node.
- Real-time polyline rendering of multi-hop mesh routes from traceroute packets.

### 3. Emergency SOS Console & Crash Detection
- Native 50Hz MPU6050 high-frequency polling on firmware with vector magnitude calculation:
  $$\text{Total G} = \sqrt{X^2 + Y^2 + Z^2}$$
- Automatically broadcasts high-priority ALERT mesh packets over LoRa and direct BLE dispatch.
- Persistent Flash NVS GPS storage guarantees coordinates are retained across cold boots and indoor environments.

---

## 📄 Documentation & Pinout Guides
- [`Rescue_Node_C6_Hardware_Manual.pdf`](./Rescue_Node_C6_Hardware_Manual.pdf)
- [`Rescue_Node_C6_Pinout.pdf`](./Rescue_Node_C6_Pinout.pdf)
- [`IndieSemiC_SX1262_Pinout_Card.pdf`](./IndieSemiC_SX1262_Pinout_Card.pdf)
- [`Meshtastic_App_Integration_Guide.pdf`](./Meshtastic_App_Integration_Guide.pdf)
- [`Flutter_Teammate_Handoff_Guide.pdf`](./Flutter_Teammate_Handoff_Guide.pdf)

---

## 📜 License
This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.
