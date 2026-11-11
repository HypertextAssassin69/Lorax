param(
    [string]$Port = ""
)

if (-not $Port) {
    $sc = Get-ItemProperty -Path 'HKLM:\HARDWARE\DEVICEMAP\SERIALCOMM' -ErrorAction SilentlyContinue
    if ($sc) {
        $Port = $sc.psobject.properties | 
            Where-Object { $_.Name -match '^\\Device\\' -and $_.Name -notmatch 'BthModem' -and $_.Value -match '^COM\d+' } | 
            Select-Object -ExpandProperty Value -First 1
    }
}

if (-not $Port) {
    Write-Output "No USB COM port found"
    exit 1
}

Write-Output "Monitoring $Port at 115200 baud..."
$port = New-Object System.IO.Ports.SerialPort $Port, 115200, None, 8, One
$port.ReadTimeout = 1000
try {
    $port.Open()
    # Hardware reset ESP32 via DTR/RTS
    $port.DtrEnable = $false
    $port.RtsEnable = $true
    Start-Sleep -Milliseconds 100
    $port.DtrEnable = $false
    $port.RtsEnable = $false
    Start-Sleep -Milliseconds 200

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $lines = @()
    while ($stopwatch.ElapsedMilliseconds -lt 6000) {
        try {
            $line = $port.ReadLine()
            $lines += $line
            Write-Output $line
        } catch [System.TimeoutException] {
            # continue reading
        }
    }
    $port.Close()
} catch {
    Write-Output "Error: $($_.Exception.Message)"
}
