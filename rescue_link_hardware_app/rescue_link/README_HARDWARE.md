# RescueLink — Search & Rescue (SAR) LoRa Mesh Network

Production Flutter application configured for live Seeed Studio XIAO ESP32-C6 Meshtastic nodes.

---

## 🛰️ Hardware Specifications
- **Microcontroller**: Seeed Studio XIAO ESP32-C6 (Custom Meshtastic LoRa firmware)
- **LoRa Transceiver**: IndieSemiC SX1262 (868 MHz Mesh)
- **GPS Receiver**: u-blox NEO-6M (Pin D7)
- **Acoustic Siren & LED**: 3V SMD Piezo Buzzer & Indicator LED (Pin D0 — triggered via `EXTERNAL_NOTIFICATION_APP`)
- **Tactile Emergency Button**: Push Button Active LOW (Pin D6 — broadcasts immediate SOS)
- **Motion Sensor**: MPU6050 6-Axis IMU (I2C SDA D4, SCL D5)

---

## 📶 Bluetooth Low Energy (BLE) Credentials
- **Discovered Names**: Starts with `Meshtastic_` (e.g. `Meshtastic_af88`, `Meshtastic_9448`, `Meshtastic_aee8`)
- **Fixed Headless Pairing PIN / Passkey**: `123456`
- **Meshtastic Primary Service UUID**: `6ba1b218-15a8-461f-9fa8-5dcae273eafd`
- **GATT Characteristics**:
  - `ToRadio` (Write Without Response): `f75c76d2-129e-11ed-861d-0242ac120002`
  - `FromRadio` (Read / Notify): `2c55e69e-4993-11ed-b878-0242ac120002`
  - `FromNum` (Notify): `ed9da18c-a800-4f66-a670-aa7547e34453`

---

## 🚀 Quick Start Instructions

### Option 1: Run with Flutter Web
1. Ensure [Flutter SDK](https://flutter.dev) is installed and available on PATH.
2. Open terminal in this folder and install dependencies:
   ```bash
   flutter pub get
   ```
3. Run directly in Google Chrome or Microsoft Edge:
   ```bash
   flutter run -d chrome
   ```
4. Click **`PAIR NODE (BLE)`** in the web dashboard.
5. In the browser popup, select your node (`Meshtastic_af88`), and enter PIN: `123456`.

### Option 2: Pre-compiled Standalone Web Server
The pre-compiled release build is already included in `build/web/`.
You can serve it with Python immediately without compiling:
```bash
python serve.py
```
Open **`http://localhost:8080`** in Google Chrome or Microsoft Edge.

### Option 3: Run as Native Windows / Android / iOS
To run natively on Android or iOS:
```bash
flutter run
```
All Bluetooth and Location permissions are already configured in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.

---

## 🧪 Verification & Tests
Run unit and integration tests:
```bash
flutter test
```
All 14 production tests for codec, hardware node manager, and BLE services pass with 0 errors.
