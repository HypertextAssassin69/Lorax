#ifndef _VARIANT_RESCUE_NODE_C6_
#define _VARIANT_RESCUE_NODE_C6_

#ifdef __cplusplus
extern "C" {
#endif

// I2C (Wire) - used for MPU6050 Accelerometer
#define WIRE_INTERFACES_COUNT (1)
#define I2C_SDA (22) // XIAO D4
#define I2C_SCL (23) // XIAO D5

// GPS (NEO-6M UART interface)
#define HAS_GPS 1
#undef GPS_RX_PIN
#undef GPS_TX_PIN
#define GPS_RX_PIN (17) // XIAO D7 (Connects to NEO-6M TX)
#define GPS_TX_PIN (-1) // Free GPIO 0 from HardwareSerial
#define GPS_BAUDRATE 9600

// Button & Buzzer / Status LED pins
#define BUTTON_PIN (16)   // XIAO D6 (External Tactile Button to D6 & GND)
#define LED_PIN (0)       // XIAO D0 (Piezo Buzzer & Status LED)

// LoRa SX1262 Configuration
#define USE_SX1262
#define USE_SX1268
#define USE_LLCC68

#define LORA_SCK (19)   // XIAO D8
#define LORA_MISO (20)  // XIAO D9
#define LORA_MOSI (18)  // XIAO D10
#define LORA_CS (21)    // XIAO D3

#define LORA_DIO1 (2)   // XIAO D2
#define LORA_BUSY (1)   // XIAO D1
#define LORA_RESET RADIOLIB_NC // SX1262 RESET tied to XIAO RST/EN pin
#define LORA_DIO0 RADIOLIB_NC
#define LORA_RXEN RADIOLIB_NC

#define SX126X_CS LORA_CS
#define SX126X_DIO1 LORA_DIO1
#define SX126X_BUSY LORA_BUSY
#define SX126X_RESET LORA_RESET
#define SX126X_RXEN LORA_RXEN

// TCXO Configuration
#define SX126X_DIO3_TCXO_VOLTAGE (1.8)
#define TCXO_OPTIONAL

#ifdef __cplusplus
}
#endif

#endif // _VARIANT_RESCUE_NODE_C6_
