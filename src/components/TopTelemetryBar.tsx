import React, { useState } from 'react';
import {
  Radio,
  Bluetooth,
  Usb,
  Unplug,
  Loader2,
  Volume2,
  VolumeX,
  Download,
  FileSpreadsheet,
  MapPin,
  CheckCircle2,
} from 'lucide-react';
import { useMeshStore } from '../store/useMeshStore';
import { meshtasticTransport } from '../services/meshtasticTransport';
import { exportMissionGpx, exportMissionGeoJson, exportCommsCsv } from '../utils/missionExport';

export const TopTelemetryBar: React.FC = () => {
  const connectionState = useMeshStore((s) => s.connectionState);
  const transportType = useMeshStore((s) => s.transportType);
  const localNode = useMeshStore((s) => s.localNode);
  const nodes = useMeshStore((s) => s.nodes);
  const messages = useMeshStore((s) => s.messages);
  const distressAlerts = useMeshStore((s) => s.distressAlerts);
  const isAudioMuted = useMeshStore((s) => s.isAudioMuted);
  const toggleAudioMute = useMeshStore((s) => s.toggleAudioMute);

  const [isLinking, setIsLinking] = useState(false);
  const [showExportMenu, setShowExportMenu] = useState(false);

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

  const handleExportGpx = () => {
    exportMissionGpx(nodes, distressAlerts);
    setShowExportMenu(false);
  };

  const handleExportGeoJson = () => {
    exportMissionGeoJson(nodes, distressAlerts);
    setShowExportMenu(false);
  };

  const handleExportCsv = () => {
    exportCommsCsv(messages, nodes);
    setShowExportMenu(false);
  };

  // Subtitle format: `!hexId • 88% • -62 dBm` or `Offline • Tap to pair`
  const subtitle = isConnected && localNode
    ? `${localNode.hexId}${localNode.batteryLevel !== undefined ? ` • ${localNode.batteryLevel}%` : ''}${localNode.snr !== undefined ? ` • ${localNode.snr.toFixed(0)} dB` : ''}`
    : isConnecting
    ? 'Syncing Protobuf...'
    : 'Offline • Tap to pair';

  return (
    <header className="w-full bg-slate-950/95 border-b border-white/10 backdrop-blur-2xl px-3 sm:px-4 pt-[max(env(safe-area-inset-top,0px),34px)] sm:pt-3 pb-2.5 sm:pb-3 flex items-center justify-between select-none z-30 shrink-0 font-sans transition-all">
      {/* Left side: Brand mark + Status dot + Subtitle */}
      <div className="flex items-center space-x-2 sm:space-x-2.5 min-w-0">
        <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-xl bg-cyan-500/15 border border-cyan-400/30 flex items-center justify-center text-cyan-400 shrink-0 shadow-[0_0_12px_rgba(6,182,212,0.25)]">
          <Radio className="w-3.5 h-3.5 sm:w-4 sm:h-4 animate-pulse" />
        </div>

        <div className="flex flex-col min-w-0">
          <div className="flex items-center space-x-1.5">
            <span className="font-bold text-xs sm:text-sm tracking-tight text-white">RescueLink</span>
            <span
              className={`w-2 h-2 rounded-full shrink-0 ${
                isConnected
                  ? 'bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.8)] animate-pulse'
                  : isConnecting
                  ? 'bg-amber-400 animate-ping'
                  : 'bg-slate-600'
              }`}
            />
          </div>
          <span className="text-[10px] sm:text-[11px] text-slate-400 font-mono tracking-tight truncate max-w-[110px] xs:max-w-none">
            {subtitle}
          </span>
        </div>
      </div>

      {/* Right side: Sleek action & link buttons */}
      <div className="flex items-center space-x-1 sm:space-x-2 shrink-0">
        {/* Audio Mute/Unmute button */}
        <button
          onClick={toggleAudioMute}
          className={`p-1.5 sm:p-2 rounded-xl sm:rounded-full border transition-all cursor-pointer ${
            isAudioMuted
              ? 'bg-slate-900 border-white/10 text-slate-500 hover:text-slate-300'
              : 'bg-cyan-500/10 border-cyan-400/30 text-cyan-400 hover:bg-cyan-500/20'
          }`}
          title={isAudioMuted ? 'Audio Alerts Muted (Tap to unmute)' : 'Tactical Audio Active (Tap to mute)'}
        >
          {isAudioMuted ? <VolumeX className="w-3.5 h-3.5" /> : <Volume2 className="w-3.5 h-3.5" />}
        </button>

        {/* Mission Export Menu Trigger */}
        <div className="relative">
          <button
            onClick={() => setShowExportMenu(!showExportMenu)}
            className="p-1.5 sm:p-2 rounded-xl sm:rounded-full bg-slate-900 hover:bg-slate-800 border border-white/10 text-slate-300 hover:text-white transition-all cursor-pointer"
            title="Export Mission Coordinates (GPX / GeoJSON / CSV)"
          >
            <Download className="w-3.5 h-3.5 text-cyan-400" />
          </button>

          {showExportMenu && (
            <div className="absolute right-0 top-11 w-56 rounded-2xl bg-slate-950/95 border border-white/15 p-2 shadow-2xl backdrop-blur-2xl z-50 text-xs space-y-1">
              <div className="px-2.5 py-1 text-[10px] font-mono font-semibold text-slate-400 border-b border-white/5 uppercase">
                Export Mission Telemetry
              </div>
              <button
                onClick={handleExportGpx}
                className="w-full px-2.5 py-2 rounded-xl hover:bg-cyan-500/15 text-left text-slate-200 hover:text-cyan-300 flex items-center space-x-2 transition-colors cursor-pointer"
              >
                <MapPin className="w-3.5 h-3.5 text-cyan-400" />
                <div>
                  <div className="font-semibold">Garmin GPX (.gpx)</div>
                  <div className="text-[10px] text-slate-500">Waypoints for GPS & OsmAnd</div>
                </div>
              </button>
              <button
                onClick={handleExportGeoJson}
                className="w-full px-2.5 py-2 rounded-xl hover:bg-cyan-500/15 text-left text-slate-200 hover:text-cyan-300 flex items-center space-x-2 transition-colors cursor-pointer"
              >
                <MapPin className="w-3.5 h-3.5 text-emerald-400" />
                <div>
                  <div className="font-semibold">GIS GeoJSON (.geojson)</div>
                  <div className="text-[10px] text-slate-500">For QGIS, Google Earth & Web</div>
                </div>
              </button>
              <button
                onClick={handleExportCsv}
                className="w-full px-2.5 py-2 rounded-xl hover:bg-cyan-500/15 text-left text-slate-200 hover:text-cyan-300 flex items-center space-x-2 transition-colors cursor-pointer"
              >
                <FileSpreadsheet className="w-3.5 h-3.5 text-amber-400" />
                <div>
                  <div className="font-semibold">Comms Log (.csv)</div>
                  <div className="text-[10px] text-slate-500">Radio packet and text history</div>
                </div>
              </button>
            </div>
          )}
        </div>

        {isConnected ? (
          <button
            onClick={handleDisconnect}
            className="px-2.5 sm:px-3 py-1.5 rounded-full bg-slate-800/80 hover:bg-rose-500/20 border border-slate-700/80 hover:border-rose-400/40 text-slate-200 hover:text-rose-300 text-xs font-semibold flex items-center gap-1.5 transition-all cursor-pointer active:scale-95"
            title="Disconnect hardware link"
          >
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
            <span className="font-mono text-[11px]">{transportType === 'BLE' ? 'BLE' : 'USB'}</span>
            <Unplug className="w-3.5 h-3.5 ml-0.5 text-slate-400" />
          </button>
        ) : isConnecting ? (
          <div className="px-2.5 sm:px-3.5 py-1.5 rounded-full bg-amber-500/15 border border-amber-400/30 text-amber-300 text-xs font-semibold flex items-center gap-1.5">
            <Loader2 className="w-3.5 h-3.5 animate-spin" />
            <span className="text-[11px]">Linking...</span>
          </div>
        ) : (
          <>
            {/* Mobile & Desktop: Single sleek Connect BLE pill button */}
            <button
              onClick={handleBleLink}
              disabled={isLinking}
              className="px-2.5 sm:px-3.5 py-1.5 rounded-full bg-cyan-500/15 hover:bg-cyan-500/25 active:scale-95 border border-cyan-400/40 text-cyan-300 text-xs font-semibold flex items-center gap-1.5 whitespace-nowrap transition-all shadow-[0_0_15px_rgba(6,182,212,0.15)] cursor-pointer"
            >
              <Bluetooth className="w-3.5 h-3.5 text-cyan-300 shrink-0" />
              <span>Link BLE</span>
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
