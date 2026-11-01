@echo off
title RESCUE NODE C6 — MPU6050 & HARDWARE SERIAL MONITOR
color 0B
cd /d "%~dp0"
echo ========================================================
echo   RESCUE NODE C6 - MPU6050 & HARDWARE SERIAL MONITOR
echo ========================================================
echo.

if exist "C:\Users\hiaar\anaconda3\python.exe" (
    "C:\Users\hiaar\anaconda3\python.exe" mpu_monitor.py
    goto done
)

where uv >nul 2>nul
if %ERRORLEVEL% equ 0 (
    uv run --with pyserial python mpu_monitor.py
    goto done
)

python mpu_monitor.py

:done
pause
