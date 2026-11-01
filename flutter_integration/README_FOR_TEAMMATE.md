# Meshtastic LoRa Integration for Flutter App

Hey! Here is everything you need to connect our Flutter app to our custom Search & Rescue LoRa hardware nodes.

---

## 1. Hardware Specs of our Nodes
* **Microcontroller:** Seeed Studio XIAO ESP32-C6 (160MHz RISC-V)
* **LoRa Radio:** IndieSemiC SX1262 (868 MHz long-range mesh)
* **Sensors:** u-blox NEO-6M GPS (live coordinates) + MPU6050 Accelerometer
* **Emergency Triggers:** Tactile Waterproof SOS Button (D6) + 3V Piezo Siren / Status LED (D0)
* **Bluetooth Advertising Names:** `Meshtastic_9448`, `Meshtastic_aee8`, `Meshtastic_af88`
* **Default Bluetooth PIN:** `123456`

---

## 2. Dependencies to Add (`pubspec.yaml`)
Add these to your `pubspec.yaml`:
```yaml
dependencies:
  flutter_blue_plus: ^1.34.0
  permission_handler: ^11.3.1
```

---

## 3. How to Drop in the Code
1. Copy `meshtastic_ble_service.dart` into your `lib/services/` folder.
2. In your UI (e.g. Map Screen or Dashboard):
```dart
final bleService = MeshtasticBleService();

// 1. Scan for our nodes:
bleService.scanForNodes().listen((results) {
  for (var r in results) {
    if (r.device.platformName.startsWith("Meshtastic_")) {
      print("Found rescue node: ${r.device.platformName}");
      bleService.connect(r.device);
    }
  }
});

// 2. Listen to live GPS from NEO-6M:
bleService.onGpsReceived.listen((gps) {
  print("Lat: ${gps.latitude}, Lon: ${gps.longitude}");
  // Update your Flutter map pin here!
});

// 3. Listen to Emergency SOS:
bleService.onSosAlert.listen((sos) {
  // Pop up emergency banner / siren alert!
});

// 4. Trigger the physical Piezo Buzzer on the lost person's node:
bleService.triggerAcousticSiren();
```

---

## 4. Master AI Prompt for Cursor / Copilot / Claude
If you want an AI coding assistant to automatically integrate this into your existing screens and state management (Provider/Riverpod/Bloc), copy and paste this prompt:

> **Role:** Senior Flutter Engineer.
> **Task:** Integrate `MeshtasticBleService` into our existing Flutter app screens and state management.
> **Context:** We have 3 active LoRa mesh nodes advertising as `Meshtastic_*` with Bluetooth pairing PIN `123456`.
> **Requirements:**
> 1. Add a Bluetooth connection indicator in our AppBar.
> 2. Bind `onGpsReceived` to update markers on our live map view.
> 3. Bind `onSosAlert` to trigger an emergency modal with sound/vibration.
> 4. Add a "Trigger SAR Acoustic Siren" button that calls `triggerAcousticSiren()`.
