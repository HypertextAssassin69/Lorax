import React from 'react';
import {
  Map,
  ShieldAlert,
  MessageSquare,
  Cpu,
} from 'lucide-react';
import { useMeshStore } from '../store/useMeshStore';

export const NavigationRail: React.FC = () => {
  const activeTab = useMeshStore((s) => s.activeTab);
  const setActiveTab = useMeshStore((s) => s.setActiveTab);
  const distressAlerts = useMeshStore((s) => s.distressAlerts);

  const activeAlerts = distressAlerts.filter((a) => !a.acknowledged).length;

  return (
    <nav className="h-16 w-full backdrop-blur-xl bg-slate-950/85 border-t border-white/10 flex items-center justify-around px-2 select-none z-40 shrink-0 pb-[env(safe-area-inset-bottom,0px)] font-sans">
      {/* Tab 1: Live Tactical Map */}
      <button
        onClick={() => setActiveTab('map')}
        className={`flex-1 flex flex-col items-center justify-center py-1 rounded-xl transition-all active:scale-95 cursor-pointer ${
          activeTab === 'map'
            ? 'text-cyan-400 font-semibold'
            : 'text-slate-400 hover:text-slate-200'
        }`}
      >
        <div className={`p-1 rounded-lg ${activeTab === 'map' ? 'bg-cyan-500/15' : ''}`}>
          <Map className="w-5 h-5" />
        </div>
        <span className="text-[11px] tracking-tight mt-0.5">Map</span>
      </button>

      {/* Tab 2: SOS & SAR Beacon */}
      <button
        onClick={() => setActiveTab('sos')}
        className={`relative flex-1 flex flex-col items-center justify-center py-1 rounded-xl transition-all active:scale-95 cursor-pointer ${
          activeTab === 'sos'
            ? 'text-rose-400 font-semibold'
            : 'text-slate-400 hover:text-rose-400'
        }`}
      >
        {activeAlerts > 0 && (
          <span className="absolute top-1.5 right-1/4 flex h-3 w-3">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-rose-500 opacity-75"></span>
            <span className="relative inline-flex rounded-full h-3 w-3 bg-rose-500 text-[8px] text-white font-bold items-center justify-center">
              {activeAlerts}
            </span>
          </span>
        )}
        <div className={`p-1 rounded-lg ${activeTab === 'sos' ? 'bg-rose-500/15' : ''}`}>
          <ShieldAlert className="w-5 h-5" />
        </div>
        <span className="text-[11px] tracking-tight mt-0.5">SOS</span>
      </button>

      {/* Tab 3: Mesh Chat & Channels */}
      <button
        onClick={() => setActiveTab('comms')}
        className={`flex-1 flex flex-col items-center justify-center py-1 rounded-xl transition-all active:scale-95 cursor-pointer ${
          activeTab === 'comms'
            ? 'text-cyan-400 font-semibold'
            : 'text-slate-400 hover:text-slate-200'
        }`}
      >
        <div className={`p-1 rounded-lg ${activeTab === 'comms' ? 'bg-cyan-500/15' : ''}`}>
          <MessageSquare className="w-5 h-5" />
        </div>
        <span className="text-[11px] tracking-tight mt-0.5">Mesh Chat</span>
      </button>

      {/* Tab 4: Nodes & Diagnostics */}
      <button
        onClick={() => setActiveTab('nodes')}
        className={`flex-1 flex flex-col items-center justify-center py-1 rounded-xl transition-all active:scale-95 cursor-pointer ${
          activeTab === 'nodes'
            ? 'text-cyan-400 font-semibold'
            : 'text-slate-400 hover:text-slate-200'
        }`}
      >
        <div className={`p-1 rounded-lg ${activeTab === 'nodes' ? 'bg-cyan-500/15' : ''}`}>
          <Cpu className="w-5 h-5" />
        </div>
        <span className="text-[11px] tracking-tight mt-0.5">Nodes</span>
      </button>
    </nav>
  );
};
