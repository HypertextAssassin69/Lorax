#ifndef Pins_Arduino_h
#define Pins_Arduino_h

#include <stdint.h>

// UART interface (for GPS)
static const uint8_t TX = 21; // Not used, but defining for framework compatibility
static const uint8_t RX = 3;

// I2C interface (for MPU6050 accelerometer)
static const uint8_t SDA = 5;
static const uint8_t SCL = 4;

// SPI interface (for SX1262 LoRa)
static const uint8_t SS = 21;
static const uint8_t MOSI = 20;
static const uint8_t MISO = 10;
static const uint8_t SCK = 8;

// Analog pins (XIAO D0-D3)
static const uint8_t A0 = 2;
static const uint8_t A1 = 3;
static const uint8_t A2 = 4;
static const uint8_t A3 = 5;

#endif /* Pins_Arduino_h */
