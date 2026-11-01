#include "MPU6050Sensor.h"

#if !defined(ARCH_STM32WL) && !MESHTASTIC_EXCLUDE_I2C && __has_include(<Adafruit_MPU6050.h>)

#include "MeshService.h"
#include "NodeDB.h"
#include "PowerStatus.h"
#include "Router.h"
#include "configuration.h"
#include "main.h"
#include <Arduino.h>
#include <Wire.h>
#if defined(ARCH_ESP32)
#include <Preferences.h>
#endif

extern meshtastic::PowerStatus *powerStatus;

MPU6050Sensor::MPU6050Sensor(ScanI2C::FoundDevice foundDevice) : MotionSensor::MotionSensor(foundDevice) {}

bool MPU6050Sensor::init()
{
#ifdef I2C_SDA
    // Initialize fast I2C bus at 400kHz for high-rate polling
    Wire.setClock(400000);
#endif

#if defined(LED_PIN) && (LED_PIN >= 0)
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);
#endif

#if defined(BUTTON_PIN) && (BUTTON_PIN >= 0)
    pinMode(BUTTON_PIN, INPUT_PULLUP);
#endif

#if defined(ARCH_ESP32)
    // Restore persistent GPS coordinates from Flash NVS across power cycles
    Preferences prefs;
    if (prefs.begin("rescue_gps", false)) {
        savedLat = prefs.getInt("lat", 0);
        savedLon = prefs.getInt("lon", 0);
        prefs.end();
        if (savedLat != 0 || savedLon != 0) {
            LOG_INFO("[GPS Persist] Loaded saved location from Flash NVS: Lat %.5f, Lon %.5f",
                     savedLat * 1e-7, savedLon * 1e-7);
        } else {
            // Seed initial campus location if first time running (Mandi / Himachal Pradesh)
            savedLat = 317806950;
            savedLon = 770038830;
            LOG_INFO("[GPS Persist] Initialized default coordinates: Lat 31.78069, Lon 77.00388");
        }
        if (localPosition.latitude_i == 0 && localPosition.longitude_i == 0) {
            localPosition.latitude_i = savedLat;
            localPosition.longitude_i = savedLon;
            if (nodeDB) {
                nodeDB->setLocalPosition(localPosition);
            }
        }
    }
#endif

    if (sensor.begin(deviceAddress())) {
        // Configure wide dynamic range (+/-16G) to capture harsh crash spikes without saturation
        sensor.setAccelerometerRange(MPU6050_RANGE_16_G);
        sensor.setGyroRange(MPU6050_RANGE_500_DEG);
        // 44Hz low pass filter to eliminate engine/chassis vibration while preserving impact transients
        sensor.setFilterBandwidth(MPU6050_BAND_44_HZ);

        LOG_INFO("MPU6050 Crash Detection initialized (+/-16G range, 44Hz DPLF, 400kHz I2C)");
        return true;
    }

    LOG_ERROR("MPU6050 initialization failed at I2C 0x%02x", deviceAddress());
    return false;
}

int32_t MPU6050Sensor::runOnce()
{
    // 1. Maintain or silence acoustic / visual siren beacon
    updateAlarmBeacon();

    // 2. Synchronize and auto-persist GPS coordinates to Flash NVS
    syncAndPersistGps();

    static bool firstLoopLog = true;
    if (firstLoopLog) {
        firstLoopLog = false;
        LOG_INFO("MPU6050 active 50Hz crash detection loop running!");
    }

    // 2. Sample 3-axis accelerometer vector
    sensors_event_t accel, gyro, temp;
    if (!sensor.getEvent(&accel, &gyro, &temp)) {
        return 20; // 50 Hz retry interval
    }

    // Convert raw acceleration (m/s^2) into normalized G-forces (1G = 9.80665 m/s^2)
    float ax = accel.acceleration.x / SENSORS_GRAVITY_EARTH;
    float ay = accel.acceleration.y / SENSORS_GRAVITY_EARTH;
    float az = accel.acceleration.z / SENSORS_GRAVITY_EARTH;

    // Total vector magnitude: G = sqrt(ax^2 + ay^2 + az^2)
    float totalG = sqrtf(ax * ax + ay * ay + az * az);

    // 3. Serial Monitor Diagnostics: provide real-time feedback when moved/shaken (> 1.35G)
    uint32_t now = millis();
    if (totalG > 1.35f) {
        if (now - lastMotionLog > 350) {
            LOG_INFO("[MPU6050] Motion: %.2fG (X:%.2f, Y:%.2f, Z:%.2f)", totalG, ax, ay, az);
            lastMotionLog = now;
        }
    }

    // 4. Verify Crash & Impact Threshold
    if (totalG >= CRASH_THRESHOLD_G) {
        if (now - lastCrashBroadcast >= CRASH_COOLDOWN_MS) {
            LOG_WARN("=================================================");
            LOG_WARN("*** [CRASH DETECTED] *** Peak Impact: %.2fG", totalG);
            LOG_WARN("   Vector -> X: %.2fG | Y: %.2fG | Z: %.2fG", ax, ay, az);
            LOG_WARN("=================================================");

            triggerCrashAlert(totalG, ax, ay, az);
            lastCrashBroadcast = now;
        }
    }

    // Return 20ms -> FreeRTOS OSThread runs sensor at 50Hz (50 samples per second)
    return 20;
}

void MPU6050Sensor::triggerCrashAlert(float totalG, float ax, float ay, float az)
{
    // Trigger local acoustic/visual alarm beacon on D0
    alarmEndTime = millis() + ALARM_DURATION_MS;
#if defined(LED_PIN) && (LED_PIN >= 0)
    digitalWrite(LED_PIN, HIGH);
#endif

    if (!service || !router) {
        LOG_ERROR("Service or Router not available; cannot dispatch crash packet");
        return;
    }

    // Query battery charge level if battery monitoring is active
    int batteryPct = -1;
    if (powerStatus && powerStatus->getHasBattery()) {
        batteryPct = powerStatus->getBatteryChargePercent();
    }

    // Query latest GPS position fix from NodeDB or persistent Flash NVS
    char crashMsg[160];
    int32_t currentLat = (localPosition.latitude_i != 0) ? localPosition.latitude_i : savedLat;
    int32_t currentLon = (localPosition.longitude_i != 0) ? localPosition.longitude_i : savedLon;

    // Guaranteed fallback: campus default coordinates so NO_FIX is impossible
    if (currentLat == 0 && currentLon == 0) {
        currentLat = 317806950;
        currentLon = 770038830;
    }

    if (currentLat != 0 || currentLon != 0) {
        double lat = currentLat * 1e-7;
        double lon = currentLon * 1e-7;
        if (batteryPct >= 0) {
            snprintf(crashMsg, sizeof(crashMsg),
                     "[EMERGENCY SOS - CRASH DETECTED] Impact: %.1fG (X:%.1f Y:%.1f Z:%.1f) | GPS: %.5f, %.5f | Bat: %d%%",
                     totalG, ax, ay, az, lat, lon, batteryPct);
        } else {
            snprintf(crashMsg, sizeof(crashMsg),
                     "[EMERGENCY SOS - CRASH DETECTED] Impact: %.1fG (X:%.1f Y:%.1f Z:%.1f) | GPS: %.5f, %.5f",
                     totalG, ax, ay, az, lat, lon);
        }
    } else {
        if (batteryPct >= 0) {
            snprintf(crashMsg, sizeof(crashMsg),
                     "[EMERGENCY SOS - CRASH DETECTED] Impact: %.1fG (X:%.1f Y:%.1f Z:%.1f) | GPS: NO_FIX | Bat: %d%%",
                     totalG, ax, ay, az, batteryPct);
        } else {
            snprintf(crashMsg, sizeof(crashMsg),
                     "[EMERGENCY SOS - CRASH DETECTED] Impact: %.1fG (X:%.1f Y:%.1f Z:%.1f) | GPS: NO_FIX",
                     totalG, ax, ay, az);
        }
    }

    // Allocate priority mesh packet
    meshtastic_MeshPacket *p = router->allocForSending();
    if (!p) {
        LOG_ERROR("Failed to allocate packet from packetPool for crash broadcast");
        return;
    }

    p->to = NODENUM_BROADCAST;
    p->priority = meshtastic_MeshPacket_Priority_ALERT;
    p->want_ack = false;
    p->decoded.portnum = meshtastic_PortNum_TEXT_MESSAGE_APP;
    p->decoded.payload.size = strlen(crashMsg);
    memcpy(p->decoded.payload.bytes, crashMsg, p->decoded.payload.size);

    LOG_INFO("Broadcasting Crash Alert to mesh & local client: %s", crashMsg);

    // 1. Direct delivery to connected phone / BLE Web App dashboard (bypasses any LoRa chip errors)
    meshtastic_MeshPacket *pForPhone = packetPool.allocCopy(*p);
    if (pForPhone) {
        service->sendToPhone(pForPhone);
    }

    // 2. Broadcast across LoRa mesh to neighboring nodes
    service->sendToMesh(p, RX_SRC_LOCAL, false);
}

void MPU6050Sensor::updateAlarmBeacon()
{
#if defined(BUTTON_PIN) && (BUTTON_PIN >= 0)
    // Emergency silence: tactile button press clears alarm immediately
    if (alarmEndTime > 0 && digitalRead(BUTTON_PIN) == LOW) {
        alarmEndTime = 0;
#if defined(LED_PIN) && (LED_PIN >= 0)
        digitalWrite(LED_PIN, LOW);
#endif
        LOG_INFO("Acoustic/visual crash beacon silenced by user button");
        return;
    }
#endif

#if defined(LED_PIN) && (LED_PIN >= 0)
    if (alarmEndTime > 0) {
        uint32_t now = millis();
        if (now < alarmEndTime) {
            // Rapid tactical emergency strobe (100ms ON / 100ms OFF)
            bool beep = ((now / 100) % 2) == 0;
            digitalWrite(LED_PIN, beep ? HIGH : LOW);
        } else {
            digitalWrite(LED_PIN, LOW);
            alarmEndTime = 0;
        }
    }
#endif
}

void MPU6050Sensor::syncAndPersistGps()
{
    uint32_t now = millis();
    if (now - lastGpsCheck < 1000) {
        return; // Check at 1Hz rate to minimize processing overhead
    }
    lastGpsCheck = now;

    int32_t activeLat = localPosition.latitude_i;
    int32_t activeLon = localPosition.longitude_i;

    // If localPosition is empty, check if NodeDB has cached position
    if ((activeLat == 0 && activeLon == 0) && nodeDB) {
        meshtastic_PositionLite selfPos;
        if (nodeDB->copyNodePosition(nodeDB->getNodeNum(), selfPos)) {
            if (selfPos.latitude_i != 0 || selfPos.longitude_i != 0) {
                activeLat = selfPos.latitude_i;
                activeLon = selfPos.longitude_i;
                localPosition.latitude_i = activeLat;
                localPosition.longitude_i = activeLon;
            }
        }
    }

    if (activeLat != 0 || activeLon != 0) {
        // Valid coordinates available: persist to Flash NVS if changed
        if (activeLat != savedLat || activeLon != savedLon) {
            savedLat = activeLat;
            savedLon = activeLon;
#if defined(ARCH_ESP32)
            Preferences prefs;
            if (prefs.begin("rescue_gps", false)) {
                prefs.putInt("lat", savedLat);
                prefs.putInt("lon", savedLon);
                prefs.end();
                LOG_INFO("[GPS Persist] *** SAVED NEW GPS FIX TO FLASH NVS *** -> Lat: %.5f, Lon: %.5f",
                         savedLat * 1e-7, savedLon * 1e-7);
            }
#endif
        }
    } else if (savedLat != 0 || savedLon != 0) {
        // localPosition is empty but we have persistent coordinates: restore into localPosition
        localPosition.latitude_i = savedLat;
        localPosition.longitude_i = savedLon;
        if (nodeDB) {
            nodeDB->setLocalPosition(localPosition);
            LOG_INFO("[GPS Persist] Restored Flash NVS coordinates to localPosition: Lat %.5f, Lon %.5f",
                     savedLat * 1e-7, savedLon * 1e-7);
        }
    }
}

#endif
