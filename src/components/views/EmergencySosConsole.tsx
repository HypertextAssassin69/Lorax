import React, { useState, useRef } from 'react';
import {
  AlertTriangle,
  Volume2,
  ShieldAlert,
  Radio,
  MapPin,
  CheckCircle,
  Clock,
  Check,
  Zap,
  Activity,
  UserCheck,
} from 'lucide-react';
import { useMeshStore } from '../../store/useMeshStore';
import { meshtasticTransport } from '../../services/meshtasticTransport';
import { alertAudioService } from '../../services/alertAudioService';
import { DistressAlert } from '../../types/meshtastic';

export const EmergencySosConsole: React.FC = () => {
  const distressAlerts = useMeshStore((s) => s.distressAlerts);
  const acknowledgeDistress = useMeshStore((s) => s.acknowledgeDistress);
  const localNode = useMeshStore((s) => s.localNode);
  const setActiveTab = useMeshStore((s) => s.setActiveTab);
  const setSelectedNodeNum = useMeshStore((s) => s.setSelectedNodeNum);

  // Hold-to-transmit SOS state (2000ms duration)
  const [holdProgress, setHoldProgress] = useState(0); // 0 to 100
  const [isHolding, setIsHolding] = useState(false);
  const [sosStatus, setSosStatus] = useState<'IDLE' | 'TRANSMITTING' | 'SENT' | 'FAILED'>('IDLE');
  const [customNote, setCustomNote] = useState('');
  const holdIntervalRef = useRef<number | null>(null);

  const HOLD_DURATION_MS = 2000;
  const HOLD_STEP_MS = 40;

  const startHold = () => {
    if (sosStatus === 'TRANSMITTING') return;
    setIsHolding(true);
    setHoldProgress(0);

    // Haptic feedback if supported
    if ('vibrate' in navigator) {
      try { navigator.vibrate(50); } catch (e) {}
    }

    const startTime = Date.now();
    holdIntervalRef.current = window.setInterval(() => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(100, (elapsed / HOLD_DURATION_MS) * 100);
      setHoldProgress(progress);

      if (progress >= 100) {
        cancelHold();
        executeSos();
      }
    }, HOLD_STEP_MS);
  };

  const cancelHold = () => {
    setIsHolding(false);
    setHoldProgress(0);
    if (holdIntervalRef.current) {
      clearInterval(holdIntervalRef.current);
      holdIntervalRef.current = null;
    }
  };

  const executeSos = async () => {
    setSosStatus('TRANSMITTING');
    alertAudioService.playSosAlarm();

    try {
      const pktId = await meshtasticTransport.triggerEmergencySos(
        customNote.trim() || 'TACTICAL SOS DISTRESS'
      );
      if (pktId) {
        setSosStatus('SENT');
      } else {
        setSosStatus('FAILED');
      }
    } catch (e) {
      setSosStatus('FAILED');
    }
  };

  const handleTriggerSiren = async () => {
    alertAudioService.playSosAlarm();
    await meshtasticTransport.triggerAcousticBeacon();
  };

  const handleAckAlert = async (alert: DistressAlert) => {
    acknowledgeDistress(alert.id);
    await meshtasticTransport.sendTextMessage(
      `SAR ACK: Rescue Team Acknowledged Distress. Unit ${localNode?.shortName || 'CMD'} en route.`,
      alert.senderNum,
      true
    );
  };

  const handleCenterOnMap = (alert: DistressAlert) => {
    setSelectedNodeNum(alert.senderNum);
    setActiveTab('map');
  };

  // SVG circular ring calculations (radius: 76, circumference: 2 * pi * 76 = 477.5)
  const radius = 76;
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - (holdProgress / 100) * circumference;

  return (
    <div className="flex-1 w-full h-full overflow-y-auto bg-slate-950 p-4 font-sans select-none pb-20">
      <div className="max-w-xl mx-auto space-y-5">
        {/* Centered Circular 2-Second Hold SOS Button */}
        <div className="flex flex-col items-center justify-center pt-2">
          <div className="relative w-44 h-44 flex items-center justify-center">
            {/* SVG Circular Progress Ring */}
            <svg className="w-full h-full -rotate-90 transform" viewBox="0 0 176 176">
              {/* Background Track */}
              <circle
                cx="88"
                cy="88"
                r={radius}
                className="stroke-rose-950/50"
                strokeWidth="8"
                fill="none"
              />
              {/* Animated Progress Ring */}
              <circle
                cx="88"
                cy="88"
                r={radius}
                className="stroke-rose-500 transition-all duration-75 ease-linear"
                strokeWidth="8"
                fill="none"
                strokeDasharray={circumference}
                strokeDashoffset={strokeDashoffset}
                strokeLinecap="round"
              />
            </svg>

            {/* Inner Tactile Button */}
            <button
              onMouseDown={startHold}
              onMouseUp={cancelHold}
              onMouseLeave={cancelHold}
              onTouchStart={startHold}
              onTouchEnd={cancelHold}
              disabled={sosStatus === 'TRANSMITTING'}
              className="absolute inset-4 rounded-full bg-gradient-to-b from-rose-600 to-rose-700 hover:from-rose-500 hover:to-rose-600 active:scale-95 shadow-[0_0_30px_rgba(244,63,94,0.45)] border border-rose-400/40 flex flex-col items-center justify-center text-white cursor-pointer transition-transform"
            >
              <AlertTriangle className={`w-8 h-8 ${isHolding ? 'animate-bounce' : 'animate-pulse'}`} />
              <span className="font-extrabold text-2xl tracking-wider mt-0.5">SOS</span>
              <span className="text-[10px] font-mono font-medium text-rose-200 uppercase tracking-tight mt-0.5">
                {isHolding
                  ? `${(2 - (holdProgress / 100) * 2).toFixed(1)}s`
                  : sosStatus === 'TRANSMITTING'
                  ? 'TRANSMITTING'
                  : 'HOLD 2s'}
              </span>
            </button>
          </div>

          {/* SOS Status Pill */}
          {sosStatus === 'SENT' && (
            <div className="mt-3 px-3 py-1 rounded-full bg-emerald-500/20 border border-emerald-400/40 text-emerald-300 text-xs font-semibold flex items-center space-x-1.5 animate-fadeIn">
              <Check className="w-3.5 h-3.5" />
              <span>SOS Broadcasted to LoRa Mesh</span>
            </div>
          )}

          {/* Optional SITREP input */}
          <div className="w-full mt-3">
            <input
              type="text"
              value={customNote}
              onChange={(e) => setCustomNote(e.target.value)}
              placeholder="Optional SITREP Note (e.g. Broken Leg, Need Evac)"
              className="w-full px-3.5 py-2 bg-slate-900/70 border border-white/10 rounded-xl text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-rose-500/50 select-text font-sans"
            />
          </div>
        </div>

        {/* 2-Column Grid: XIAO ESP32-C6 Hardware Status Cards */}
        <div>
          <div className="text-[11px] font-semibold uppercase tracking-wider text-slate-400 mb-2.5 px-0.5 flex items-center justify-between">
            <span>Hardware Diagnostics (Rescue Node C6)</span>
            <span className="text-cyan-400 font-mono text-[10px]">11-PIN ARCH</span>
          </div>

          <div className="grid grid-cols-2 gap-2.5">
            {/* Card 1: SX1262 LoRa */}
            <div className="p-3 rounded-2xl bg-slate-900/70 border border-white/10">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-100">SX1262 LoRa</span>
                <span className="w-2 h-2 rounded-full bg-emerald-400" />
              </div>
              <div className="text-[11px] text-cyan-400 font-mono mt-1">865-868 MHz</div>
              <div className="text-[10px] text-slate-400 mt-0.5">IndieSemiC SPI D8-D10</div>
            </div>

            {/* Card 2: u-blox NEO-6M GPS */}
            <div className="p-3 rounded-2xl bg-slate-900/70 border border-white/10">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-100">NEO-6M GPS</span>
                <span className={`w-2 h-2 rounded-full ${localNode?.position?.latitude ? 'bg-emerald-400' : 'bg-amber-400'}`} />
              </div>
              <div className="text-[11px] text-slate-200 font-mono mt-1">
                {localNode?.position?.satsInView ? `${localNode.position.satsInView} Sats Fixed` : 'Acquiring UART'}
              </div>
              <div className="text-[10px] text-slate-400 mt-0.5">GPIO17 / D7 (9600)</div>
            </div>

            {/* Card 3: MPU6050 IMU */}
            <div className="p-3 rounded-2xl bg-slate-900/70 border border-white/10">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-100">MPU6050 IMU</span>
                <span className="w-2 h-2 rounded-full bg-emerald-400" />
              </div>
              <div className="text-[11px] text-slate-200 font-mono mt-1">Fall / Motion Module</div>
              <div className="text-[10px] text-slate-400 mt-0.5">I2C D4 (SDA), D5 (SCL)</div>
            </div>

            {/* Card 4: GPIO0 Piezo Beacon */}
            <div className="p-3 rounded-2xl bg-slate-900/70 border border-white/10 flex flex-col justify-between">
              <div>
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-slate-100">GPIO0 Siren</span>
                  <Volume2 className="w-3.5 h-3.5 text-amber-400" />
                </div>
                <div className="text-[10px] text-slate-400 mt-0.5">3V Piezo & Status LED</div>
              </div>

              <button
                onClick={handleTriggerSiren}
                className="mt-2 py-1 px-2.5 rounded-lg bg-amber-500/20 hover:bg-amber-500/30 text-amber-300 border border-amber-400/30 text-[10px] font-semibold flex items-center justify-center space-x-1 transition-all active:scale-95 cursor-pointer"
              >
                <Zap className="w-3 h-3" />
                <span>Trigger Siren</span>
              </button>
            </div>
          </div>
        </div>

        {/* Real-time Incoming Distress Feed */}
        <div>
          <div className="text-[11px] font-semibold uppercase tracking-wider text-slate-400 mb-2.5 px-0.5 flex items-center justify-between">
            <span className="flex items-center space-x-1.5">
              <Activity className="w-3.5 h-3.5 text-rose-400" />
              <span>Incoming Distress Feed</span>
            </span>
            <span className="text-rose-400 font-mono text-[10px]">
              {distressAlerts.filter((a) => !a.acknowledged).length} Active
            </span>
          </div>

          <div className="space-y-2">
            {distressAlerts.length === 0 ? (
              <div className="p-4 rounded-2xl bg-slate-900/50 border border-white/5 text-center text-xs text-slate-500 font-sans">
                No active SOS signals detected on mesh.
              </div>
            ) : (
              distressAlerts.map((alert) => (
                <div
                  key={alert.id}
                  className={`p-3.5 rounded-2xl border text-xs font-sans transition-all ${
                    alert.acknowledged
                      ? 'bg-slate-900/50 border-white/5 text-slate-400'
                      : 'bg-rose-500/15 border-rose-500/40 text-slate-100 shadow-[0_0_15px_rgba(244,63,94,0.15)]'
                  }`}
                >
                  <div className="flex items-center justify-between mb-1.5">
                    <div className="flex items-center space-x-1.5 font-bold">
                      <span className="text-rose-400">{alert.senderName}</span>
                      <span className="text-slate-400 font-mono text-[10px]">({alert.senderHex})</span>
                    </div>
                    <span className="text-[10px] text-slate-400 font-mono">
                      {new Date(alert.timestamp).toLocaleTimeString()}
                    </span>
                  </div>

                  <p className="text-slate-200 text-xs mb-2">"{alert.message}"</p>

                  <div className="flex items-center justify-between pt-1">
                    {alert.position ? (
                      <span className="text-[10px] font-mono text-cyan-400">
                        {alert.position.latitude.toFixed(4)}, {alert.position.longitude.toFixed(4)}
                      </span>
                    ) : (
                      <span className="text-[10px] text-slate-500">No GPS Fix</span>
                    )}

                    <div className="flex items-center space-x-1.5">
                      {alert.position && (
                        <button
                          onClick={() => handleCenterOnMap(alert)}
                          className="px-2.5 py-1 rounded-lg bg-slate-800 text-cyan-300 border border-white/10 text-[10px] font-semibold"
                        >
                          Map
                        </button>
                      )}
                      {!alert.acknowledged && (
                        <button
                          onClick={() => handleAckAlert(alert)}
                          className="px-2.5 py-1 rounded-lg bg-emerald-500/20 text-emerald-300 border border-emerald-400/40 text-[10px] font-semibold active:scale-95"
                        >
                          ACK
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
