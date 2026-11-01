#ifndef _VARIANT_RESCUE_NODE_
#define _VARIANT_RESCUE_NODE_

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

// I2C (Wire) - used for MPU6050 Accelerometer
#define WIRE_INTERFACES_COUNT (1)
#define I2C_SDA (5) // XIAO D3
#define I2C_SCL (4) // XIAO D2

// GPS (NEO-6M UART interface)
#define HAS_GPS 1
#undef GPS_RX_PIN
#undef GPS_TX_PIN
#define GPS_RX_PIN (3) // XIAO D1 (Connects to NEO-6M TX)
// GPS_TX_PIN intentionally omitted to save a GPIO pin
#define GPS_BAUDRATE 9600

// Button & Piezo/LED pins
#define BUTTON_PIN (9)   // XIAO D9 (Wire Tactile Button to D9 & GND)
#define LED_PIN (2)      // XIAO D0 (Piezo Buzzer & LED)

// LoRa SX1262 Configuration
#define USE_SX1262
#define USE_SX1268
#define USE_LLCC68

#define LORA_SCK (8)    // XIAO D8
#define LORA_MISO (10)  // XIAO D10
#define LORA_MOSI (20)  // XIAO D7
#define LORA_CS (21)    // XIAO D6

#define LORA_DIO1 (7)   // XIAO D5
#define LORA_BUSY (6)   // XIAO D4
#define LORA_RESET RADIOLIB_NC // SX1262 RESET tied to XIAO EN pin
#define LORA_DIO0 RADIOLIB_NC
#define LORA_RXEN RADIOLIB_NC

#define SX126X_CS LORA_CS
#define SX126X_DIO1 LORA_DIO1
#define SX126X_BUSY LORA_BUSY
#define SX126X_RESET LORA_RESET
#define SX126X_RXEN LORA_RXEN

// TCXO Configuration (if the SX1262 uses a TCXO instead of a crystal)
#define SX126X_DIO3_TCXO_VOLTAGE (1.8)
#define TCXO_OPTIONAL // allow fallback to standard crystal if TCXO is not found

#ifdef __cplusplus
}
#endif

#endif // _VARIANT_RESCUE_NODE_
