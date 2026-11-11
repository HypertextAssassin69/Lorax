param(
    [string]$Port = ""
)

$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "      LORAX RESCUE NODE ESP32-C6 1-CLICK FLASHER     " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# 1. Locate esptool
$esptool = "D:\pio\penv\Scripts\esptool.exe"
if (-not (Test-Path $esptool)) {
    $esptool = "esptool.exe"
}

# 2. Locate factory binary
$binFile = (Get-ChildItem -Path "$PSScriptRoot\build_output\firmware-rescue_node_c6-*.factory.bin" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
if (-not $binFile) {
    $binFile = (Get-ChildItem -Path "$PSScriptRoot\.pio\build\rescue_node_c6\firmware-rescue_node_c6-*.factory.bin" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

if (-not $binFile -or -not (Test-Path $binFile)) {
    Write-Host "[ERROR] Could not find compiled factory binary in build_output/!" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Using Unified Firmware Binary:" -ForegroundColor Green
Write-Host "     $binFile`n" -ForegroundColor Gray

# 3. Detect COM port if not specified
if (-not $Port) {
    Write-Host "[...] Auto-detecting connected ESP32-C6 USB Serial Port..." -ForegroundColor Yellow
    $sc = Get-ItemProperty -Path 'HKLM:\HARDWARE\DEVICEMAP\SERIALCOMM' -ErrorAction SilentlyContinue
    $detectedPort = ""
    if ($sc) {
        $detectedPort = $sc.psobject.properties | 
            Where-Object { $_.Name -match '^\\Device\\' -and $_.Name -notmatch 'BthModem' -and $_.Value -match '^COM\d+' } | 
            Select-Object -ExpandProperty Value -First 1
    }

    if ($detectedPort) {
        $Port = $detectedPort
        Write-Host "[OK] Detected ESP32-C6 on port: $Port" -ForegroundColor Green
    } else {
        Write-Host "`n[NOTICE] No ESP32-C6 USB device is currently plugged in." -ForegroundColor Yellow
        Write-Host "Please plug in your XIAO ESP32-C6 via USB-C cable and run this script again." -ForegroundColor Yellow
        Write-Host "Or specify manually: .\flash_node.ps1 -Port COM7`n" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`n>>> Flashing to $Port at 921600 baud...`n" -ForegroundColor Cyan

& $esptool --chip esp32c6 --port $Port --baud 921600 write-flash -z 0x0 $binFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=====================================================" -ForegroundColor Green
    Write-Host " [SUCCESS] Node flashed successfully!" -ForegroundColor Green
    Write-Host " - Factory Image: Bootloader + Partitions + App" -ForegroundColor Green
    Write-Host " - Default RF Region: IN (India 865-867 MHz)" -ForegroundColor Green
    Write-Host " - SX1262 DIO2 RF switch path: ENABLED" -ForegroundColor Green
    Write-Host " - SX1262 DIO3 TCXO: 1.8V CONFIGURED" -ForegroundColor Green
    Write-Host "=====================================================`n" -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Flashing failed with exit code $LASTEXITCODE. Try holding the BOOT button on the XIAO while plugging in USB." -ForegroundColor Red
}
