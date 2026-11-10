# Lorax Rescue Node ESP32-C6 Firmware Flashing & Hardware Guide

This directory contains the custom Meshtastic-based firmware build for the **Seeed Studio XIAO ESP32-C6 + IndieSemiC SX1262 (ISC-SX1262-B) + MPU6050 + NEO-6M GPS** hardware rescue node.

---

## 1. What Was Fixed in This Firmware

1. **Pre-configured RF Region (India 865-867 MHz):**
   - Clean flashed nodes boot with `meshtastic_Config_LoRaConfig_RegionCode_IN` enabled by default.
   - Prevents the node from entering the silent/quarantine `UNSET` state where packet transmission is blocked until manually configured.

2. **SX1262 DIO2 Internal RF Antenna Switch:**
   - Enabled `#define SX126X_DIO2_AS_RF_SWITCH`.
   - Without this, the SX1262 power amplifier is disconnected from the antenna path, preventing transmit and receive power from reaching the aerial.

3. **SX1262 DIO3 TCXO Configuration:**
   - Configured `#define SX126X_DIO3_TCXO_VOLTAGE 1.8` and `#define TCXO_OPTIONAL` to provide standard 1.8V oscillator bias to the crystal.

4. **Maximum Output Power:**
   - Configured `#define SX126X_MAX_POWER 22` (+22 dBm) for maximum transmission range in search-and-rescue topologies.

---

## 2. Hardware Wiring Checklist (Critical for Radio Initialization)

If the node reports `SX126x init result -707` (`RADIOLIB_ERR_CHIP_NOT_FOUND`):

| IndieSemiC SX1262 Pin | XIAO ESP32-C6 Pin | Description |
|-----------------------|-------------------|-------------|
| **Pin 1 (GND)** | GND | Ground |
| **Pin 2 (3V3 / VCC)** | 3V3 | Power (3.3V) |
| **Pin 3 (MISO)** | D9 (GPIO 20) | SPI Data In |
| **Pin 4 (NRESET)** | **3V3 or XIAO RST pad** | **CRITICAL:** Active LOW reset. If left floating or disconnected, SX1262 remains in permanent shutdown! |
| **Pin 5 (BUSY)** | D1 (GPIO 1) | Busy indicator |
| **Pin 6 (DIO1)** | D2 (GPIO 2) | Packet RX/TX interrupt |
| **Pin 7 (MOSI)** | D10 (GPIO 18) | SPI Data Out |
| **Pin 8 (SCK)** | D8 (GPIO 19) | SPI Clock |
| **Pin 9 (NSS / CS)** | D3 (GPIO 21) | SPI Chip Select |
| **ANT / SMA** | Connected to Antenna | **NEVER transmit without an antenna attached!** |

---

## 3. How to Flash Your Nodes (When You Reconnect Them)

A unified factory image containing the bootloader, partition table, boot app descriptor, and firmware binary has been pre-compiled in `firmware/build_output/`:
- `firmware/build_output/firmware-rescue_node_c6-2.8.0.d64891c.factory.bin`

### Method A: 1-Click Flasher Script (Recommended)
1. Plug one of your XIAO ESP32-C6 nodes into USB.
2. In PowerShell, navigate to `firmware/` and run:
   ```powershell
   cd d:\College\git\mesh\firmware
   .\flash_node.ps1
   ```
   *The script will automatically detect the COM port and flash the full image in ~15 seconds.*
3. Unplug, plug the second node, and run the script again.

### Method B: Direct PlatformIO Flashing
```powershell
& "D:\pio\penv\Scripts\pio.exe" run -e rescue_node_c6 -t upload -d d:\College\git\mesh\firmware
```

### Method C: Manual Esptool Command
```powershell
& "D:\pio\penv\Scripts\esptool.exe" --chip esp32c6 --port COM7 --baud 921600 write-flash -z 0x0 "d:\College\git\mesh\firmware\build_output\firmware-rescue_node_c6-2.8.0.d64891c.factory.bin"
```
