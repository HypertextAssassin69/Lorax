import React, { useState } from 'react';
import {
  Bluetooth,
  Usb,
  Cpu,
  Radio,
  Satellite,
  ShieldAlert,
  AlertCircle,
  Lock,
  ExternalLink,
  ChevronRight,
  CheckCircle2,
  Info,
} from 'lucide-react';
import { meshtasticTransport } from '../services/meshtasticTransport';
import { useMeshStore } from '../store/useMeshStore';

export const AwaitingHardwareModal: React.FC = () => {
  const connectionState = useMeshStore((s) => s.connectionState);
  const errorMessage = useMeshStore((s) => s.errorMessage);
  const [isConnecting, setIsConnecting] = useState(false);

  // Check if browser is running in a Secure Context (required for Web Bluetooth)
  const isSecure = typeof window !== 'undefined' ? window.isSecureContext : true;
  const isHttp = typeof window !== 'undefined' && window.location.protocol === 'http:';
  const httpsUrl = typeof window !== 'undefined' ? window.location.href.replace('http:', 'https:') : '';

  const handleBle = async () => {
    setIsConnecting(true);
    await meshtasticTransport.connectBle();
    setIsConnecting(false);
  };

  const handleSerial = async () => {
    setIsConnecting(true);
    await meshtasticTransport.connectSerial();
    setIsConnecting(false);
  };

  const handleSwitchToHttps = () => {
    if (httpsUrl) {
      window.location.href = httpsUrl;
    }
  };

  return (
    <div className="flex-1 w-full h-full flex flex-col items-center justify-start sm:justify-center p-3 sm:p-6 bg-obsidian-950 overflow-y-auto select-none">
      <div className="w-full max-w-lg bg-slate-900 border border-tactical-border rounded-xl p-4 sm:p-6 shadow-2xl relative overflow-hidden my-auto">
        {/* Glow ambient accent */}
        <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-transparent via-tactical-cyan to-transparent" />

        {/* Header */}
        <div className="text-center mb-4 sm:mb-6">
          <div className="inline-flex items-center justify-center w-12 h-12 sm:w-14 sm:h-14 rounded-2xl bg-tactical-cyan/15 border border-tactical-cyan/40 text-tactical-cyan mb-2.5 shadow-tactical-cyan">
            <Radio className="w-6 h-6 sm:w-7 sm:h-7 animate-pulse" />
          </div>
          <h2 className="text-lg sm:text-xl font-bold tracking-wider text-slate-100 uppercase">
            Awaiting Hardware Link
          </h2>
          <p className="text-[11px] sm:text-xs font-mono text-slate-400 mt-1 max-w-sm mx-auto leading-relaxed">
            Zero mock data. Connect your physical Seeed Studio XIAO ESP32-C6 node to ingest live decoded Meshtastic LoRa telemetry.
          </p>
        </div>

        {/* INSECURE CONTEXT BANNER (Crucial for Mobile Chrome) */}
        {!isSecure && isHttp && (
          <div className="mb-4 p-3 rounded-lg bg-tactical-amber/15 border border-tactical-amber/40 text-slate-200 text-xs font-mono">
            <div className="flex items-start space-x-2">
              <Lock className="w-4 h-4 text-tactical-amber shrink-0 mt-0.5" />
              <div className="flex-1">
                <div className="font-bold text-tactical-amber uppercase tracking-wide text-[11px]">
                  HTTPS Required for Mobile BLE
                </div>
                <p className="text-[10px] text-slate-300 mt-1 leading-normal">
                  Chrome Mobile requires a secure context (HTTPS) to unlock the Web Bluetooth API on LAN IP addresses.
                </p>
                <button
                  onClick={handleSwitchToHttps}
                  className="mt-2.5 w-full flex items-center justify-center space-x-1.5 py-1.5 px-3 rounded bg-tactical-amber/25 hover:bg-tactical-amber/35 text-tactical-amber border border-tactical-amber/50 font-bold text-xs transition-all cursor-pointer"
                >
                  <ExternalLink className="w-3.5 h-3.5" />
                  <span>SWITCH TO HTTPS ({httpsUrl.slice(0, 28)}...)</span>
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Error notification banner if any */}
        {errorMessage && (
          <div className="mb-4 p-3 rounded-lg bg-tactical-crimson/15 border border-tactical-crimson/40 text-tactical-crimson flex items-start space-x-2 text-xs font-mono">
            <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
            <div className="flex-1 text-[11px] leading-relaxed">
              <span className="font-bold">Hardware Link Alert: </span>
              {errorMessage}
            </div>
          </div>
        )}

        {/* Primary Hardware Link Actions */}
        <div className="space-y-3 mb-5">
          {/* BLE Link Button (Primary for mobile) */}
          <button
            onClick={handleBle}
            disabled={isConnecting}
            className="w-full group p-3.5 sm:p-4 rounded-xl bg-slate-800/90 hover:bg-slate-800 border-2 border-tactical-cyan/40 hover:border-tactical-cyan transition-all hover:shadow-tactical-cyan cursor-pointer text-left flex items-center justify-between"
          >
            <div className="flex items-center space-x-3 min-w-0">
              <div className="w-10 h-10 sm:w-11 sm:h-11 rounded-lg bg-tactical-cyan/15 flex items-center justify-center text-tactical-cyan shrink-0 group-hover:scale-105 transition-transform">
                <Bluetooth className="w-5 h-5 sm:w-6 sm:h-6" />
              </div>
              <div className="min-w-0">
                <div className="font-bold text-slate-100 text-xs sm:text-sm tracking-wide flex items-center space-x-1.5">
                  <span>LINK VIA BLE 5.0</span>
                  <span className="text-[9px] px-1 py-0.2 rounded bg-tactical-cyan/20 text-tactical-cyan border border-tactical-cyan/30">
                    WIRELESS
                  </span>
                </div>
                <div className="text-[10px] sm:text-[11px] font-mono text-slate-400 mt-0.5 truncate">
                  Pairs with <span className="text-tactical-cyan">Meshtastic_*</span> (PIN: 123456)
                </div>
              </div>
            </div>
            <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-tactical-cyan group-hover:translate-x-0.5 transition-all shrink-0 ml-2" />
          </button>

          {/* USB Serial Button */}
          <button
            onClick={handleSerial}
            disabled={isConnecting}
            className="w-full group p-3 sm:p-3.5 rounded-xl bg-slate-800/60 hover:bg-slate-800 border border-tactical-border hover:border-tactical-emerald transition-all hover:shadow-tactical-emerald cursor-pointer text-left flex items-center justify-between"
          >
            <div className="flex items-center space-x-3 min-w-0">
              <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-lg bg-tactical-emerald/15 flex items-center justify-center text-tactical-emerald shrink-0 group-hover:scale-105 transition-transform">
                <Usb className="w-4 h-4 sm:w-5 sm:h-5" />
              </div>
              <div className="min-w-0">
                <div className="font-bold text-slate-200 text-xs tracking-wide">
                  LINK USB CDC SERIAL (COM PORT)
                </div>
                <div className="text-[10px] font-mono text-slate-400 mt-0.5 truncate">
                  Espressif Native USB CDC (VID: 0x303A, PID: 0x1001)
                </div>
              </div>
            </div>
            <ChevronRight className="w-4 h-4 text-slate-500 group-hover:text-tactical-emerald group-hover:translate-x-0.5 transition-all shrink-0 ml-2" />
          </button>
        </div>

        {/* Physical Hardware Ground Truth Specs (Compact Grid) */}
        <div className="border-t border-tactical-border/70 pt-3.5">
          <div className="text-[10px] font-mono uppercase tracking-wider text-slate-400 mb-2 flex items-center justify-between">
            <span className="flex items-center space-x-1.5">
              <Cpu className="w-3.5 h-3.5 text-tactical-cyan" />
              <span>Target Node: Seeed XIAO ESP32-C6</span>
            </span>
            <span className="text-tactical-cyan text-[9px]">865-868MHz</span>
          </div>

          <div className="grid grid-cols-2 gap-2 text-[10px] font-mono">
            <div className="p-2 rounded bg-slate-800/40 border border-tactical-border/60">
              <div className="text-slate-500 text-[9px]">LoRa RADIO</div>
              <div className="text-slate-200 font-semibold truncate">IndieSemiC SX1262</div>
              <div className="text-[9px] text-tactical-cyan">SPI D8-D10, D1-D3</div>
            </div>

            <div className="p-2 rounded bg-slate-800/40 border border-tactical-border/60">
              <div className="text-slate-500 text-[9px]">GPS SENSOR</div>
              <div className="text-slate-200 font-semibold truncate">u-blox NEO-6M</div>
              <div className="text-[9px] text-slate-400">UART RX (GPIO17)</div>
            </div>

            <div className="p-2 rounded bg-slate-800/40 border border-tactical-border/60">
              <div className="text-slate-500 text-[9px]">IMU SENSOR</div>
              <div className="text-slate-200 font-semibold truncate">MPU6050 6-Axis</div>
              <div className="text-[9px] text-slate-400">I2C (GPIO22/23)</div>
            </div>

            <div className="p-2 rounded bg-slate-800/40 border border-tactical-border/60">
              <div className="text-slate-500 text-[9px]">EMERGENCY TRIGGERS</div>
              <div className="text-slate-200 font-semibold truncate">Tactile Button (D6)</div>
              <div className="text-[9px] text-tactical-amber">3V Piezo / LED (D0)</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
