"""
Rescue Node C6 — Live MPU6050 Crash & Motion Hardware Serial Monitor
Direct streaming serial monitor for Seeed Studio XIAO ESP32-C6.
"""

import sys
import time
import os
import serial
import serial.tools.list_ports
import re

# Set unbuffered UTF-8 output
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(line_buffering=True, encoding='utf-8')

# ANSI Color codes for Windows Terminal
GREEN = "\033[92m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
RED = "\033[91;1m"
BOLD = "\033[1m"
RESET = "\033[0m"

def find_port():
    ports = serial.tools.list_ports.comports()
    for p in ports:
        if p.vid == 0x303A:
            return p.device
    for p in ports:
        if any(c in p.device for c in ["COM7", "COM13"]):
            return p.device
    return None

def main():
    os.system("cls" if os.name == "nt" else "clear")
    print(f"{CYAN}======================================================================{RESET}", flush=True)
    print(f"{BOLD}   RESCUE NODE C6 — MPU6050 & CRASH DETECTION LIVE MONITOR{RESET}", flush=True)
    print(f"{CYAN}======================================================================{RESET}", flush=True)

    port = find_port()
    if not port:
        print(f"{YELLOW}[!] Searching for connected ESP32-C6 on USB...{RESET}", flush=True)
        while not port:
            time.sleep(0.5)
            port = find_port()

    print(f"{GREEN}[+] Found Seeed Studio XIAO ESP32-C6 on {port}!{RESET}", flush=True)
    print(f"[*] Opening {port} at 115200 baud (Direct Hardware Logging Mode)...", flush=True)

    try:
        ser = serial.Serial(port, 115200, timeout=0.1)
        ser.dtr = True
        ser.rts = False
    except Exception as e:
        print(f"{RED}[!] Error opening {port}: {e}{RESET}", flush=True)
        print(f"{YELLOW}[*] If another terminal has the port open, please close it first.{RESET}", flush=True)
        return

    print(f"{GREEN}[+] Serial Monitor ACTIVE! Listening for MPU6050 & Crash events:{RESET}\n", flush=True)
    print(f"{CYAN}{'TIME':<10} | {'SOURCE':<14} | {'HARDWARE TELEMETRY / CRASH EVENT'}{RESET}", flush=True)
    print(f"{CYAN}{'-'*70}{RESET}", flush=True)

    buf = bytearray()

    try:
        while True:
            chunk = ser.read(512)
            if not chunk:
                time.sleep(0.01)
                continue

            buf.extend(chunk)

            while b"\n" in buf:
                pos = buf.index(b"\n")
                raw = bytes(buf[:pos]).strip(b"\r\n")
                buf = buf[pos + 1:]

                if not raw:
                    continue

                now = time.strftime("%H:%M:%S")

                # Decode printable ASCII strings
                text = raw.decode("utf-8", errors="replace").strip()

                # Highlight Crash Detection Events
                if "CRASH DETECTED" in text or "Peak Impact" in text:
                    print(f"\n{now:<10} | {RED}{'CRASH ALERT':<14}{RESET} | {RED}{BOLD}>>> {text} <<<{RESET}\n", flush=True)

                # Highlight GPS Persistence & Coordinates
                elif "GPS Persist" in text or "SAVED NEW GPS FIX" in text:
                    print(f"\n{now:<10} | {GREEN}{'GPS PERSIST':<14}{RESET} | {GREEN}{BOLD}>>> {text} <<<{RESET}\n", flush=True)

                # Highlight Motion / G-force telemetry
                elif "MPU6050" in text or "High Motion" in text or "Vector" in text:
                    print(f"{now:<10} | {YELLOW}{'MPU6050 MOTION':<14}{RESET} | {YELLOW}{text}{RESET}", flush=True)

                # Highlight Device & System logs
                elif any(k in text for k in ["INFO", "DEBUG", "WARN", "ERROR"]):
                    clean_text = re.sub(r'^[A-Z]+\s*\|\s*[\?\:\d]+\s*\d*\s*', '', text)
                    if clean_text:
                        print(f"{now:<10} | {'SYSTEM':<14} | {clean_text}", flush=True)
                    else:
                        print(f"{now:<10} | {'SYSTEM':<14} | {text}", flush=True)

                # Embedded text in binary frames
                else:
                    readable = re.findall(r'[A-Za-z0-9\s\:\,\.\-\_\!\@\#\$\%\^\&\*\(\)\=\+\/\[\]\<\>]{6,}', text)
                    for r in readable:
                        if any(w in r for w in ["CRASH", "Impact", "MPU", "Motion", "GPS", "Bat", "rescue"]):
                            print(f"{now:<10} | {CYAN}{'TELEMETRY':<14}{RESET} | {r}", flush=True)

    except KeyboardInterrupt:
        print(f"\n{YELLOW}[*] Monitor stopped by user.{RESET}", flush=True)
    finally:
        ser.close()

if __name__ == "__main__":
    main()
