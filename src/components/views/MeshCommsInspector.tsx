import React, { useState } from 'react';
import {
  Send,
  Radio,
  Check,
  CheckCheck,
  Clock,
  Wifi,
  Users,
  AlertCircle,
} from 'lucide-react';
import { useMeshStore } from '../../store/useMeshStore';
import { meshtasticTransport } from '../../services/meshtasticTransport';

const CANNED_PRESETS = [
  'SAR Team En Route',
  'Survivor Located - Need Evac',
  'Medical Assistance Requested',
  'Grid Clear - Moving to Next Waypoint',
  'Radio Check / Signal Report',
];

export const MeshCommsInspector: React.FC = () => {
  const messages = useMeshStore((s) => s.messages);
  const nodes = useMeshStore((s) => s.nodes);
  const localNode = useMeshStore((s) => s.localNode);

  const [messageText, setMessageText] = useState('');
  const [targetDestination, setTargetDestination] = useState<number>(0xffffffff);
  const [wantAck, setWantAck] = useState(true);
  const [isSending, setIsSending] = useState(false);

  const handleSendMessage = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!messageText.trim() || isSending) return;

    setIsSending(true);
    await meshtasticTransport.sendTextMessage(messageText.trim(), targetDestination, wantAck);
    setMessageText('');
    setIsSending(false);
  };

  const handleSendCanned = async (text: string) => {
    setIsSending(true);
    await meshtasticTransport.sendTextMessage(text, targetDestination, wantAck);
    setIsSending(false);
  };

  return (
    <div className="flex-1 w-full h-full flex flex-col bg-slate-950 font-sans overflow-hidden select-none">
      {/* Top Channel / Target Selector */}
      <div className="h-11 px-4 border-b border-white/10 bg-slate-950/90 backdrop-blur-xl flex items-center justify-between shrink-0">
        <div className="flex items-center space-x-2">
          <Radio className="w-3.5 h-3.5 text-cyan-400" />
          <span className="text-[11px] font-semibold text-slate-400 uppercase tracking-tight">Channel:</span>
          <select
            value={targetDestination}
            onChange={(e) => setTargetDestination(Number(e.target.value))}
            className="px-2 py-0.5 bg-slate-900 border border-white/10 rounded-lg text-xs font-semibold text-cyan-300 focus:outline-none"
          >
            <option value={0xffffffff}>📡 Primary Broadcast (#All)</option>
            {Object.values(nodes)
              .filter((n) => !n.isLocal)
              .map((n) => (
                <option key={n.num} value={n.num}>
                  👤 {n.shortName} ({n.hexId})
                </option>
              ))}
          </select>
        </div>

        <label className="flex items-center space-x-1.5 text-xs text-slate-400 cursor-pointer">
          <input
            type="checkbox"
            checked={wantAck}
            onChange={(e) => setWantAck(e.target.checked)}
            className="rounded bg-slate-800 border-white/20 text-cyan-400 focus:ring-0"
          />
          <span className="text-[11px] font-semibold">ACK</span>
        </label>
      </div>

      {/* Messages Stream (iMessage/Signal Dark Style) */}
      <div className="flex-1 overflow-y-auto p-4 space-y-3">
        {messages.length === 0 ? (
          <div className="h-full flex flex-col items-center justify-center text-center p-8 text-xs text-slate-500">
            <Radio className="w-10 h-10 mb-2.5 opacity-25 text-cyan-400" />
            <span className="font-semibold text-slate-400">No LoRa Messages Yet</span>
            <span className="text-slate-500 mt-1 max-w-xs text-[11px]">
              Broadcast or direct message over 865-868MHz SX1262 LoRa mesh.
            </span>
          </div>
        ) : (
          messages.map((msg) => {
            const isFromMe = msg.from === localNode?.myNodeNum;
            const senderNode = nodes[msg.from];
            const senderName = isFromMe
              ? 'Me'
              : senderNode?.shortName || `!${(msg.from >>> 0).toString(16).padStart(8, '0')}`;

            return (
              <div
                key={msg.id}
                className={`flex flex-col max-w-[85%] sm:max-w-md ${
                  isFromMe ? 'ml-auto items-end' : 'mr-auto items-start'
                }`}
              >
                <div className="flex items-center space-x-1.5 text-[10px] text-slate-400 mb-1 px-1">
                  <span className="font-semibold text-slate-300">{senderName}</span>
                  <span>•</span>
                  <span>{new Date(msg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                  {msg.rxSnr !== undefined && (
                    <span className="font-mono text-cyan-400">
                      {msg.rxSnr > 0 ? `+${msg.rxSnr.toFixed(0)}` : msg.rxSnr.toFixed(0)}dB
                    </span>
                  )}
                </div>

                <div
                  className={`px-3.5 py-2.5 rounded-2xl text-xs select-text shadow-md ${
                    msg.isAlert
                      ? 'bg-rose-500/25 border border-rose-500/50 text-rose-100'
                      : isFromMe
                      ? 'bg-gradient-to-r from-cyan-600 to-blue-600 text-white rounded-br-sm'
                      : 'bg-slate-900 border border-white/10 text-slate-200 rounded-bl-sm'
                  }`}
                >
                  <div className="leading-relaxed whitespace-pre-wrap">{msg.text}</div>

                  {/* Delivery Status */}
                  {isFromMe && (
                    <div className="flex items-center justify-end space-x-1 mt-1 text-[9px] text-cyan-200">
                      {msg.ackStatus === 'SENDING' && (
                        <>
                          <Clock className="w-3 h-3 animate-spin" />
                          <span>Routing</span>
                        </>
                      )}
                      {msg.ackStatus === 'ACKED' && (
                        <>
                          <CheckCheck className="w-3.5 h-3.5 text-emerald-300" />
                          <span className="text-emerald-300 font-semibold">Mesh ACK</span>
                        </>
                      )}
                      {msg.ackStatus === 'FAILED' && (
                        <>
                          <AlertCircle className="w-3 h-3 text-rose-300" />
                          <span className="text-rose-300">Timeout</span>
                        </>
                      )}
                      {msg.ackStatus === 'RECEIVED' && (
                        <Check className="w-3 h-3" />
                      )}
                    </div>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Canned Quick SAR Presets Carousel */}
      <div className="px-3 py-1.5 bg-slate-950/80 border-t border-white/5 overflow-x-auto flex items-center space-x-2 shrink-0 no-scrollbar">
        {CANNED_PRESETS.map((canned, idx) => (
          <button
            key={idx}
            onClick={() => handleSendCanned(canned)}
            disabled={isSending}
            className="whitespace-nowrap px-2.5 py-1 rounded-full bg-slate-900 hover:bg-slate-800 text-slate-300 text-[11px] border border-white/10 font-medium transition-colors cursor-pointer"
          >
            {canned}
          </button>
        ))}
      </div>

      {/* Sticky Bottom Message Input Bar */}
      <form
        onSubmit={handleSendMessage}
        className="p-3 bg-slate-950 border-t border-white/10 flex items-center gap-2 shrink-0 pb-[max(12px,env(safe-area-inset-bottom,0px))]"
      >
        <input
          type="text"
          value={messageText}
          onChange={(e) => setMessageText(e.target.value)}
          placeholder="Message LoRa mesh..."
          className="flex-1 px-4 py-2 bg-slate-900 border border-white/10 rounded-full text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-400 select-text"
        />

        <button
          type="submit"
          disabled={isSending || !messageText.trim()}
          className="w-9 h-9 rounded-full bg-cyan-500 hover:bg-cyan-400 disabled:opacity-40 text-slate-950 flex items-center justify-center transition-all shadow-[0_0_12px_rgba(6,182,212,0.4)] cursor-pointer shrink-0"
        >
          <Send className="w-4 h-4 ml-0.5" />
        </button>
      </form>
    </div>
  );
};
