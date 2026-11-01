import React, { useState } from 'react';
import {
  Users,
  Wifi,
  Battery,
  Navigation,
  Send,
  Clock,
  Terminal,
  ChevronDown,
  ChevronUp,
  Copy,
  Trash2,
} from 'lucide-react';
import { useMeshStore } from '../../store/useMeshStore';
import { meshtasticTransport } from '../../services/meshtasticTransport';
import { MeshNode } from '../../types/meshtastic';

export const NodeDirectoryDiagnostics: React.FC = () => {
  const nodes = useMeshStore((s) => s.nodes);
  const localNode = useMeshStore((s) => s.localNode);
  const rawPackets = useMeshStore((s) => s.rawPackets);
  const clearPacketLogs = useMeshStore((s) => s.clearPacketLogs);
  const setActiveTab = useMeshStore((s) => s.setActiveTab);
  const setSelectedNodeNum = useMeshStore((s) => s.setSelectedNodeNum);

  const [showPacketInspector, setShowPacketInspector] = useState(false);
  const [tracingNodeNum, setTracingNodeNum] = useState<number | null>(null);

  const nodeList = Object.values(nodes);

  const handleTraceroute = async (nodeNum: number) => {
    setTracingNodeNum(nodeNum);
    await meshtasticTransport.sendTraceroute(nodeNum);
    setTimeout(() => setTracingNodeNum(null), 3000);
  };

  const handleDirectComms = (nodeNum: number) => {
    setSelectedNodeNum(nodeNum);
    setActiveTab('comms');
  };

  const copyHex = (hex: string) => {
    navigator.clipboard.writeText(hex);
  };

  return (
    <div className="flex-1 w-full h-full overflow-y-auto bg-slate-950 p-4 font-sans select-none pb-20">
      <div className="max-w-xl mx-auto space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between px-0.5">
          <div className="flex items-center space-x-2">
            <Users className="w-4 h-4 text-cyan-400" />
            <h2 className="text-sm font-bold text-slate-100 uppercase tracking-tight">
              Mesh Node Directory
            </h2>
          </div>
          <span className="text-[11px] font-mono text-cyan-400 font-semibold px-2 py-0.5 rounded-full bg-cyan-500/15 border border-cyan-400/30">
            {nodeList.length} Discovered
          </span>
        </div>

        {/* Nodes List */}
        <div className="space-y-2.5">
          {nodeList.length === 0 ? (
            <div className="p-8 rounded-2xl bg-slate-900/50 border border-white/5 text-center text-xs text-slate-500">
              <Users className="w-10 h-10 mb-2 opacity-25 text-cyan-400 mx-auto" />
              <span className="font-semibold text-slate-400">No Mesh Peers Discovered</span>
              <p className="text-[11px] text-slate-500 mt-1 max-w-xs mx-auto">
                Nodes populate automatically as live <code className="text-cyan-400">NODEINFO_APP</code> packets are decoded over SX1262 LoRa.
              </p>
            </div>
          ) : (
            nodeList.map((node) => {
              const isLocal = node.isLocal;
              return (
                <div
                  key={node.num}
                  className={`p-3.5 rounded-2xl border text-xs transition-all ${
                    isLocal
                      ? 'bg-cyan-500/10 border-cyan-400/40'
                      : 'bg-slate-900/70 border-white/10'
                  }`}
                >
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center space-x-2">
                      <span
                        className={`w-2 h-2 rounded-full ${
                          isLocal ? 'bg-cyan-400' : 'bg-emerald-400'
                        }`}
                      />
                      <span className="font-bold text-slate-100 text-sm">{node.shortName}</span>
                      <span className="font-mono text-[10px] text-slate-400">{node.hexId}</span>
                      {isLocal && (
                        <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-cyan-500/20 text-cyan-300 border border-cyan-400/40">
                          HOST
                        </span>
                      )}
                    </div>

                    <div className="flex items-center space-x-1 text-[10px] font-mono text-slate-400">
                      <Clock className="w-3 h-3" />
                      <span>{new Date(node.lastHeard).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                    </div>
                  </div>

                  {/* Telemetry Row */}
                  <div className="grid grid-cols-3 gap-2 py-2 px-2.5 rounded-xl bg-slate-950/60 border border-white/5 text-[11px] font-mono text-slate-300 mb-2.5">
                    <div className="flex items-center space-x-1">
                      <Wifi className="w-3 h-3 text-cyan-400 shrink-0" />
                      <span>{node.snr > 0 ? `+${node.snr.toFixed(0)}` : node.snr.toFixed(0)}dB</span>
                    </div>

                    <div className="flex items-center space-x-1">
                      <Battery className="w-3 h-3 text-emerald-400 shrink-0" />
                      <span>{node.metrics?.batteryLevel !== undefined ? `${node.metrics.batteryLevel}%` : 'LiPo'}</span>
                    </div>

                    <div className="text-right text-slate-400">
                      <span>{node.hopsAway} Hops</span>
                    </div>
                  </div>

                  {/* Node Actions */}
                  {!isLocal && (
                    <div className="flex items-center justify-end space-x-2 pt-1">
                      <button
                        onClick={() => handleDirectComms(node.num)}
                        className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold flex items-center space-x-1 transition-all active:scale-95 cursor-pointer"
                      >
                        <Send className="w-3 h-3" />
                        <span>Chat</span>
                      </button>

                      <button
                        onClick={() => handleTraceroute(node.num)}
                        disabled={tracingNodeNum === node.num}
                        className="px-3 py-1.5 rounded-xl bg-cyan-500/15 hover:bg-cyan-500/25 border border-cyan-400/30 text-cyan-300 text-xs font-semibold flex items-center space-x-1 transition-all active:scale-95 cursor-pointer"
                      >
                        <Navigation className={`w-3 h-3 ${tracingNodeNum === node.num ? 'animate-spin' : ''}`} />
                        <span>{tracingNodeNum === node.num ? 'Tracing...' : 'Trace'}</span>
                      </button>
                    </div>
                  )}
                </div>
              );
            })
          )}
        </div>

        {/* Collapsible Live Raw Packet Inspector */}
        <div className="pt-2">
          <button
            onClick={() => setShowPacketInspector(!showPacketInspector)}
            className="w-full p-3.5 rounded-2xl bg-slate-900/80 border border-white/10 flex items-center justify-between text-xs font-semibold text-slate-300 hover:text-white transition-colors cursor-pointer"
          >
            <div className="flex items-center space-x-2">
              <Terminal className="w-4 h-4 text-cyan-400" />
              <span>Live Packet Inspector ({rawPackets.length} Frames)</span>
            </div>
            {showPacketInspector ? (
              <ChevronUp className="w-4 h-4 text-slate-400" />
            ) : (
              <ChevronDown className="w-4 h-4 text-slate-400" />
            )}
          </button>

          {showPacketInspector && (
            <div className="mt-2 p-3 rounded-2xl bg-slate-900/90 border border-white/10 space-y-2">
              <div className="flex items-center justify-between pb-2 border-b border-white/10 text-xs font-mono">
                <span className="text-slate-400">STREAMING DECODED FRAMES</span>
                <button
                  onClick={clearPacketLogs}
                  className="text-slate-500 hover:text-rose-400 flex items-center space-x-1"
                >
                  <Trash2 className="w-3 h-3" />
                  <span>Clear</span>
                </button>
              </div>

              <div className="max-h-64 overflow-y-auto space-y-1.5 font-mono text-[10px]">
                {rawPackets.length === 0 ? (
                  <div className="py-4 text-center text-slate-500">No frames captured yet.</div>
                ) : (
                  rawPackets.slice(0, 50).map((pkt) => (
                    <div
                      key={pkt.id}
                      className="p-2 rounded-xl bg-slate-950 border border-white/5 space-y-1"
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-1.5">
                          <span
                            className={`px-1 py-0.2 rounded text-[9px] font-bold ${
                              pkt.direction === 'TX'
                                ? 'bg-cyan-500/20 text-cyan-300'
                                : 'bg-emerald-500/20 text-emerald-300'
                            }`}
                          >
                            {pkt.direction}
                          </span>
                          <span className="font-bold text-slate-200">{pkt.portnum}</span>
                        </div>
                        <span className="text-slate-500">
                          {new Date(pkt.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
                        </span>
                      </div>

                      <div className="text-slate-400 text-[10px] truncate">{pkt.summary}</div>

                      <div className="flex items-center justify-between pt-1 text-slate-500">
                        <span className="truncate max-w-[200px] text-slate-400 font-mono text-[9px]">
                          {pkt.payloadHex || '<empty>'}
                        </span>
                        <button
                          onClick={() => copyHex(pkt.payloadHex)}
                          className="text-cyan-400 hover:underline flex items-center space-x-0.5"
                        >
                          <Copy className="w-2.5 h-2.5" />
                          <span>Copy</span>
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
