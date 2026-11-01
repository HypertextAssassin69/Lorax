import React from 'react';
import { TopTelemetryBar } from './components/TopTelemetryBar';
import { HttpsBanner } from './components/HttpsBanner';
import { NavigationRail } from './components/NavigationRail';
import { TacticalMapView } from './components/views/TacticalMapView';
import { EmergencySosConsole } from './components/views/EmergencySosConsole';
import { MeshCommsInspector } from './components/views/MeshCommsInspector';
import { NodeDirectoryDiagnostics } from './components/views/NodeDirectoryDiagnostics';
import { useMeshStore } from './store/useMeshStore';

export const App: React.FC = () => {
  const activeTab = useMeshStore((s) => s.activeTab);

  return (
    <div className="flex flex-col h-[100dvh] max-h-[100dvh] w-screen overflow-hidden bg-slate-950 text-slate-100 font-sans">
      {/* 1. Ultra-Clean Mobile Top Header (h-14) */}
      <TopTelemetryBar />

      {/* 2. One-Line HTTPS Warning Banner (Shown only on insecure http:// context) */}
      <HttpsBanner />

      {/* 3. Main Full-Screen Viewport (Always active, never blocked by disconnected modal) */}
      <main className="flex-1 w-full h-full relative overflow-hidden flex flex-col">
        {activeTab === 'map' && <TacticalMapView />}
        {activeTab === 'sos' && <EmergencySosConsole />}
        {activeTab === 'comms' && <MeshCommsInspector />}
        {activeTab === 'nodes' && <NodeDirectoryDiagnostics />}
      </main>

      {/* 4. Floating Glassmorphic Bottom Navigation Bar (h-16) */}
      <NavigationRail />
    </div>
  );
};

export default App;
