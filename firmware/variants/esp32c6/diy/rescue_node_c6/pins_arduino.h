#ifndef Pins_Arduino_h
#define Pins_Arduino_h

#include <stdint.h>

#define USB_VID 0x303A
#define USB_PID 0x1001

// UART interface (for GPS)
static const uint8_t TX = 16;
static const uint8_t RX = 17;

// I2C interface (for MPU6050 accelerometer)
static const uint8_t SDA = 22;
static const uint8_t SCL = 23;

// SPI interface (for SX1262 LoRa)
static const uint8_t SS = 21;
static const uint8_t MOSI = 18;
static const uint8_t MISO = 20;
static const uint8_t SCK = 19;

// Analog pins (XIAO D0-D2)
static const uint8_t A0 = 0;
static const uint8_t A1 = 1;
static const uint8_t A2 = 2;

#endif /* Pins_Arduino_h */
