#pragma once
#ifndef _MPU6050_SENSOR_H_
#define _MPU6050_SENSOR_H_

#include "MotionSensor.h"

#if !defined(ARCH_STM32WL) && !MESHTASTIC_EXCLUDE_I2C && __has_include(<Adafruit_MPU6050.h>)

#include <Adafruit_MPU6050.h>

#ifndef CRASH_THRESHOLD_G
#define CRASH_THRESHOLD_G 2.5f // Impact threshold in Gs to trigger emergency crash alert
#endif

#ifndef CRASH_COOLDOWN_MS
#define CRASH_COOLDOWN_MS 15000 // 15s cooldown to prevent channel congestion during tumbling
#endif

#ifndef ALARM_DURATION_MS
#define ALARM_DURATION_MS 5000 // 5s acoustic and visual beacon alarm duration
#endif

/**
 * @brief High-Performance Crash & Impact Detection Sensor Handler for MPU6050.
 *
 * Samples 3-axis accelerometer vectors at 50Hz (20ms interval), calculates total vector
 * magnitude G = sqrt(ax^2 + ay^2 + az^2), and broadcasts high-priority ALERT mesh packets
 * with GPS coordinates and battery metrics when severe impact is verified.
 */
class MPU6050Sensor : public MotionSensor
{
  private:
    Adafruit_MPU6050 sensor;
    uint32_t lastCrashBroadcast = 0;
    uint32_t alarmEndTime = 0;
    uint32_t lastMotionLog = 0;
    uint32_t lastGpsCheck = 0;
    int32_t savedLat = 0;
    int32_t savedLon = 0;

    void triggerCrashAlert(float totalG, float ax, float ay, float az);
    void updateAlarmBeacon();
    void syncAndPersistGps();

  public:
    explicit MPU6050Sensor(ScanI2C::FoundDevice foundDevice);
    virtual bool init() override;
    virtual int32_t runOnce() override;
};

#endif

#endif
