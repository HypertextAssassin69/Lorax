$sc = Get-ItemProperty -Path 'HKLM:\HARDWARE\DEVICEMAP\SERIALCOMM' -ErrorAction SilentlyContinue
$portName = $sc.psobject.properties | 
    Where-Object { $_.Name -match '^\\Device\\' -and $_.Name -notmatch 'BthModem' -and $_.Value -match '^COM\d+' } | 
    Select-Object -ExpandProperty Value -First 1

if (-not $portName) {
    Write-Output "No USB COM port found"
    exit 1
}

Write-Output "Probing $portName at 115200 baud..."

$port = New-Object System.IO.Ports.SerialPort $portName, 115200, None, 8, One
$port.ReadTimeout = 1000
try {
    $port.Open()
    # Trigger ESP32 hardware reset
    $port.DtrEnable = $false
    $port.RtsEnable = $true
    Start-Sleep -Milliseconds 100
    $port.DtrEnable = $false
    $port.RtsEnable = $false
    Start-Sleep -Milliseconds 200

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.ElapsedMilliseconds -lt 6000) {
        try {
            $line = $port.ReadLine()
            Write-Output $line
        } catch [System.TimeoutException] {
            # continue reading
        }
    }
    $port.Close()
} catch {
    Write-Output "Error: $($_.Exception.Message)"
}
