import React, { useState } from 'react';
import {
  Radio,
  Bluetooth,
  Usb,
  Unplug,
  Loader2,
  CheckCircle2,
} from 'lucide-react';
import { useMeshStore } from '../store/useMeshStore';
import { meshtasticTransport } from '../services/meshtasticTransport';

export const TopTelemetryBar: React.FC = () => {
  const connectionState = useMeshStore((s) => s.connectionState);
  const transportType = useMeshStore((s) => s.transportType);
  const localNode = useMeshStore((s) => s.localNode);
  const [isLinking, setIsLinking] = useState(false);

  const isConnected = connectionState === 'CONNECTED';
  const isConnecting = connectionState === 'CONNECTING' || connectionState === 'CONFIGURING';

  const handleBleLink = async () => {
    setIsLinking(true);
    await meshtasticTransport.connectBle();
    setIsLinking(false);
  };

  const handleSerialLink = async () => {
    setIsLinking(true);
    await meshtasticTransport.connectSerial();
    setIsLinking(false);
  };

  const handleDisconnect = async () => {
    await meshtasticTransport.disconnect();
  };

  // Subtitle format: `!hexId • 88% • -62 dBm` or `Offline • Tap to pair`
  const subtitle = isConnected && localNode
    ? `${localNode.hexId}${localNode.batteryLevel !== undefined ? ` • ${localNode.batteryLevel}%` : ''}${localNode.snr !== undefined ? ` • ${localNode.snr.toFixed(0)} dB` : ''}`
    : isConnecting
    ? 'Syncing Protobuf...'
    : 'Offline • Tap to pair';

  return (
    <header className="h-14 bg-slate-950/90 border-b border-white/10 backdrop-blur-xl px-4 flex items-center justify-between select-none z-30 shrink-0 font-sans">
      {/* Left side: Brand mark + Status dot + Subtitle */}
      <div className="flex items-center space-x-2.5 min-w-0">
        <div className="w-8 h-8 rounded-xl bg-cyan-500/15 border border-cyan-400/30 flex items-center justify-center text-cyan-400 shrink-0 shadow-[0_0_12px_rgba(6,182,212,0.25)]">
          <Radio className="w-4 h-4 animate-pulse" />
        </div>

        <div className="flex flex-col min-w-0">
          <div className="flex items-center space-x-1.5">
            <span className="font-bold text-sm tracking-tight text-white">RescueLink</span>
            <span
              className={`w-2 h-2 rounded-full ${
                isConnected
                  ? 'bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.8)] animate-pulse'
                  : isConnecting
                  ? 'bg-amber-400 animate-ping'
                  : 'bg-slate-600'
              }`}
            />
          </div>
          <span className="text-[11px] text-slate-400 font-mono tracking-tight truncate">
            {subtitle}
          </span>
        </div>
      </div>

      {/* Right side: Sleek pill buttons */}
      <div className="flex items-center space-x-2 shrink-0">
        {isConnected ? (
          <button
            onClick={handleDisconnect}
            className="px-3 py-1.5 rounded-full bg-slate-800/80 hover:bg-rose-500/20 border border-slate-700/80 hover:border-rose-400/40 text-slate-200 hover:text-rose-300 text-xs font-semibold flex items-center gap-1.5 transition-all cursor-pointer active:scale-95"
            title="Disconnect hardware link"
          >
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
            <span className="font-mono text-[11px]">{transportType === 'BLE' ? 'BLE 5.0' : 'USB'}</span>
            <Unplug className="w-3.5 h-3.5 ml-0.5 text-slate-400" />
          </button>
        ) : isConnecting ? (
          <div className="px-3.5 py-1.5 rounded-full bg-amber-500/15 border border-amber-400/30 text-amber-300 text-xs font-semibold flex items-center gap-1.5">
            <Loader2 className="w-3.5 h-3.5 animate-spin" />
            <span>Linking...</span>
          </div>
        ) : (
          <>
            {/* Mobile & Desktop: Single sleek Connect BLE pill button */}
            <button
              onClick={handleBleLink}
              disabled={isLinking}
              className="px-3.5 py-1.5 rounded-full bg-cyan-500/15 hover:bg-cyan-500/25 active:scale-95 border border-cyan-400/40 text-cyan-300 text-xs font-semibold flex items-center gap-1.5 whitespace-nowrap transition-all shadow-[0_0_15px_rgba(6,182,212,0.15)] cursor-pointer"
            >
              <Bluetooth className="w-3.5 h-3.5 text-cyan-300" />
              <span>Connect BLE</span>
            </button>

            {/* Desktop Only: Optional USB Serial COM pill button */}
            <button
              onClick={handleSerialLink}
              disabled={isLinking}
              className="hidden md:flex px-3 py-1.5 rounded-full bg-slate-800/80 hover:bg-slate-700 border border-slate-700 text-slate-300 text-xs font-semibold items-center gap-1.5 transition-all cursor-pointer"
            >
              <Usb className="w-3.5 h-3.5 text-emerald-400" />
              <span>USB (COM)</span>
            </button>
          </>
        )}
      </div>
    </header>
  );
};
