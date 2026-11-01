import React, { useState, useMemo, useEffect, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from 'react-leaflet';
import L from 'leaflet';
import {
  Satellite,
  Battery,
  Wifi,
  Users,
  Crosshair,
  Navigation,
  Compass,
  MessageSquare,
  Footprints,
  ArrowUpRight,
  X,
} from 'lucide-react';
import { useMeshStore } from '../../store/useMeshStore';
import { meshtasticTransport } from '../../services/meshtasticTransport';
import { MeshNode } from '../../types/meshtastic';
import {
  calculateDistanceMeters,
  calculateBearing,
  formatDistance,
  formatBearing,
  estimatePaceTime,
} from '../../utils/geoTactical';

// Smooth map recenter & size invalidator
function MapController({
  center,
  autoCenterCoord,
}: {
  center: [number, number] | null;
  autoCenterCoord: [number, number] | null;
}) {
  const map = useMap();
  const hasAutoCentered = useRef(false);

  useEffect(() => {
    const timer = setTimeout(() => {
      map.invalidateSize();
    }, 150);
    return () => clearTimeout(timer);
  }, [map]);

  // Recenter when user explicitly taps recenter button
  useEffect(() => {
    if (center) {
      map.flyTo(center, 15, { duration: 1.0 });
    }
  }, [center, map]);

  // Auto-center once when first live GPS coordinate arrives from NEO-6M
  useEffect(() => {
    if (autoCenterCoord && !hasAutoCentered.current) {
      hasAutoCentered.current = true;
      map.flyTo(autoCenterCoord, 15, { duration: 1.2 });
    }
  }, [autoCenterCoord, map]);

  return null;
}

export const TacticalMapView: React.FC = () => {
  const nodes = useMeshStore((s) => s.nodes);
  const localNode = useMeshStore((s) => s.localNode);
  const connectionState = useMeshStore((s) => s.connectionState);
  const selectedNodeNum = useMeshStore((s) => s.selectedNodeNum);
  const setSelectedNodeNum = useMeshStore((s) => s.setSelectedNodeNum);
  const setActiveTab = useMeshStore((s) => s.setActiveTab);

  const isConnected = connectionState === 'CONNECTED';
  const [panTarget, setPanTarget] = useState<[number, number] | null>(null);
  const [isBroadcasting, setIsBroadcasting] = useState(false);

  // Selected node details
  const selectedNode = selectedNodeNum ? nodes[selectedNodeNum] : null;

  // Nodes with valid GPS (guaranteeing local node is included)
  const allMapNodes = useMemo(() => {
    const mapNodes = { ...nodes };
    if (localNode?.position && localNode.myNodeNum) {
      if (!mapNodes[localNode.myNodeNum]) {
        mapNodes[localNode.myNodeNum] = {
          num: localNode.myNodeNum,
          hexId: localNode.hexId,
          shortName: localNode.shortName,
          longName: localNode.longName,
          hwModel: 'Seeed XIAO ESP32C6',
          lastHeard: Date.now(),
          hopsAway: 0,
          snr: localNode.snr ?? 0,
          position: localNode.position,
          metrics: {
            batteryLevel: localNode.batteryLevel,
            voltage: localNode.voltage,
          },
          isLocal: true,
          isEmergency: false,
        };
      } else {
        mapNodes[localNode.myNodeNum] = {
          ...mapNodes[localNode.myNodeNum],
          position: localNode.position,
          isLocal: true,
        };
      }
    }

    return Object.values(mapNodes).filter(
      (n): n is MeshNode & { position: NonNullable<MeshNode['position']> } =>
        Boolean(n.position && n.position.latitude && n.position.longitude)
    );
  }, [nodes, localNode]);

  // Live coordinate for auto-centering
  const liveLocalCoord = useMemo<[number, number] | null>(() => {
    if (localNode?.position?.latitude && localNode?.position?.longitude) {
      return [localNode.position.latitude, localNode.position.longitude];
    }
    return null;
  }, [localNode]);

  // Center coordinate: default to local node, first node, or Indian/EU ISM center
  const defaultCenter = useMemo<[number, number]>(() => {
    if (liveLocalCoord) return liveLocalCoord;
    if (allMapNodes.length > 0) {
      return [allMapNodes[0].position.latitude, allMapNodes[0].position.longitude];
    }
    return [31.781, 77.004]; // User's hardware node locus
  }, [liveLocalCoord, allMapNodes]);

  // Tactical Range & Bearing vector between local and selected node
  const tacticalVector = useMemo(() => {
    if (
      !selectedNode?.position ||
      !liveLocalCoord ||
      selectedNode.isLocal ||
      selectedNode.num === localNode?.myNodeNum
    ) {
      return null;
    }

    const [localLat, localLon] = liveLocalCoord;
    const targetLat = selectedNode.position.latitude;
    const targetLon = selectedNode.position.longitude;

    const distanceMeters = calculateDistanceMeters(localLat, localLon, targetLat, targetLon);
    const bearing = calculateBearing(localLat, localLon, targetLat, targetLon);
    const altDiff =
      selectedNode.position.altitude !== undefined && localNode?.position?.altitude !== undefined
        ? Math.round(selectedNode.position.altitude - localNode.position.altitude)
        : null;

    return {
      distanceMeters,
      distanceFormatted: formatDistance(distanceMeters),
      bearing,
      bearingFormatted: formatBearing(bearing),
      paceTime: estimatePaceTime(distanceMeters),
      altDiff,
      localCoord: [localLat, localLon] as [number, number],
      targetCoord: [targetLat, targetLon] as [number, number],
    };
  }, [selectedNode, liveLocalCoord, localNode]);

  // Custom Tactical Marker
  const createMarkerIcon = (node: MeshNode) => {
    const isEmergency = node.isEmergency;
    const isLocal = node.isLocal;

    const bgClass = isEmergency
      ? 'bg-rose-500/25 border-rose-500 text-rose-300 shadow-[0_0_15px_rgba(244,63,94,0.6)]'
      : isLocal
      ? 'bg-cyan-500/25 border-cyan-400 text-cyan-300 shadow-[0_0_14px_rgba(6,182,212,0.6)] ring-2 ring-cyan-400/30'
      : 'bg-slate-900/90 border-emerald-400 text-emerald-300 shadow-[0_0_10px_rgba(52,211,153,0.3)]';

    const dotClass = isEmergency
      ? 'bg-rose-500 animate-pulse'
      : isLocal
      ? 'bg-cyan-400 animate-pulse'
      : 'bg-emerald-400';

    const pulseHtml = isEmergency
      ? `<span class="absolute -inset-2 rounded-full border border-rose-500 animate-ping opacity-75"></span>`
      : isLocal
      ? `<span class="absolute -inset-1.5 rounded-full border border-cyan-400 animate-ping opacity-40"></span>`
      : '';

    const html = `
      <div class="relative flex items-center justify-center font-sans">
        ${pulseHtml}
        <div class="px-2 py-1 rounded-full border text-[11px] font-semibold flex items-center space-x-1.5 backdrop-blur-md ${bgClass} whitespace-nowrap">
          <span class="w-2 h-2 rounded-full ${dotClass}"></span>
          <span class="font-mono font-bold">${node.shortName}</span>
          ${node.metrics?.batteryLevel !== undefined ? `<span class="text-[9px] text-slate-300 font-mono">(${Math.min(100, node.metrics.batteryLevel)}%)</span>` : ''}
        </div>
      </div>
    `;

    return L.divIcon({
      html,
      className: 'tactical-custom-marker',
      iconSize: [80, 24],
      iconAnchor: [40, 12],
    });
  };

  // Center on Local Node
  const handleCenterLocal = () => {
    if (localNode?.position) {
      setPanTarget([localNode.position.latitude, localNode.position.longitude]);
    } else if ('geolocation' in navigator) {
      navigator.geolocation.getCurrentPosition((pos) => {
        setPanTarget([pos.coords.latitude, pos.coords.longitude]);
      });
    }
  };

  // Broadcast Position Ping
  const handleBroadcastPosition = async () => {
    setIsBroadcasting(true);
    if ('geolocation' in navigator) {
      navigator.geolocation.getCurrentPosition(
        async (pos) => {
          await meshtasticTransport.broadcastPosition(
            pos.coords.latitude,
            pos.coords.longitude,
            pos.coords.altitude || 0
          );
          setIsBroadcasting(false);
        },
        () => setIsBroadcasting(false),
        { enableHighAccuracy: true, timeout: 5000 }
      );
    } else {
      setIsBroadcasting(false);
    }
  };

  // Battery display (capped at 100%)
  const batteryDisplay = localNode?.batteryLevel !== undefined
    ? `${Math.min(100, localNode.batteryLevel)}%`
    : localNode?.voltage
    ? `${localNode.voltage.toFixed(2)}V`
    : isConnected
    ? '100%'
    : '--';

  return (
    <div className="flex-1 w-full h-full relative overflow-hidden bg-slate-950 font-sans">
      {/* Full-Bleed Map with OpenStreetMap Standard + Dark Tactical Filter (NO API KEY REQUIRED) */}
      <MapContainer
        center={defaultCenter}
        zoom={14}
        zoomControl={false}
        scrollWheelZoom={true}
        className="h-full w-full z-0"
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
          maxZoom={19}
          className="tactical-dark-tiles"
        />

        <MapController center={panTarget} autoCenterCoord={liveLocalCoord} />

        {/* Tactical Vector Line to Selected Node */}
        {tacticalVector && (
          <Polyline
            positions={[tacticalVector.localCoord, tacticalVector.targetCoord]}
            pathOptions={{
              color: '#00F0FF',
              weight: 2.5,
              dashArray: '6, 8',
              opacity: 0.85,
            }}
          />
        )}

        {/* Node Markers */}
        {allMapNodes.map((node) => (
          <Marker
            key={`marker-${node.num}`}
            position={[node.position.latitude, node.position.longitude]}
            icon={createMarkerIcon(node)}
            eventHandlers={{
              click: () => setSelectedNodeNum(node.num),
            }}
          >
            <Popup className="tactical-popup">
              <div className="p-1 space-y-1.5 text-xs font-sans text-slate-100 select-text">
                <div className="flex items-center justify-between border-b border-slate-800 pb-1">
                  <span className="font-bold text-cyan-400">{node.shortName}</span>
                  <span className="font-mono text-[10px] text-slate-400">{node.hexId}</span>
                </div>
                <div className="text-[11px] text-slate-300 font-medium">{node.longName}</div>
                <div className="grid grid-cols-2 gap-1 text-[10px] font-mono text-slate-400">
                  <div>LAT: <span className="text-slate-200">{node.position.latitude.toFixed(5)}</span></div>
                  <div>LON: <span className="text-slate-200">{node.position.longitude.toFixed(5)}</span></div>
                  {node.metrics?.batteryLevel !== undefined && (
                    <div>BAT: <span className="text-emerald-400">{Math.min(100, node.metrics.batteryLevel)}%</span></div>
                  )}
                  {node.snr !== undefined && (
                    <div>SNR: <span className="text-cyan-400">{node.snr.toFixed(1)} dB</span></div>
                  )}
                </div>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>

      {/* Floating Glassmorphic HUD Overlay at Top of Map */}
      <div className="absolute top-2.5 inset-x-2.5 sm:top-3 sm:inset-x-3 z-[500] pointer-events-none flex justify-center">
        <div className="grid grid-cols-4 gap-1.5 w-full max-w-xl p-1.5 rounded-2xl backdrop-blur-xl bg-slate-950/85 border border-white/10 shadow-2xl pointer-events-auto">
          {/* Chip 1: GPS Lock */}
          <div className="flex flex-col items-center justify-center py-1 px-1 rounded-xl bg-slate-900/60 border border-white/5 text-center min-w-0">
            <div className="flex items-center space-x-1 text-slate-400 text-[10px]">
              <Satellite className="w-3 h-3 text-cyan-400 shrink-0" />
              <span className="truncate">GPS</span>
            </div>
            <span className="text-[10px] sm:text-[11px] font-mono font-semibold text-slate-100 truncate mt-0.5 leading-tight w-full px-0.5">
              {localNode?.position?.latitude
                ? `${localNode.position.latitude.toFixed(3)}, ${localNode.position.longitude.toFixed(3)}`
                : isConnected
                ? 'Acquiring'
                : '--'}
            </span>
          </div>

          {/* Chip 2: LoRa SNR / RSSI */}
          <div className="flex flex-col items-center justify-center py-1 px-1 rounded-xl bg-slate-900/60 border border-white/5 text-center min-w-0">
            <div className="flex items-center space-x-1 text-slate-400 text-[10px]">
              <Wifi className="w-3 h-3 text-cyan-400 shrink-0" />
              <span className="truncate">LoRa</span>
            </div>
            <span className="text-[10px] sm:text-[11px] font-mono font-semibold text-cyan-400 truncate mt-0.5 leading-tight">
              {isConnected && localNode?.snr !== undefined
                ? `${localNode.snr > 0 ? `+${localNode.snr.toFixed(0)}` : localNode.snr.toFixed(0)} dB`
                : isConnected
                ? 'Ready'
                : '--'}
            </span>
          </div>

          {/* Chip 3: Battery / Voltage */}
          <div className="flex flex-col items-center justify-center py-1 px-1 rounded-xl bg-slate-900/60 border border-white/5 text-center min-w-0">
            <div className="flex items-center space-x-1 text-slate-400 text-[10px]">
              <Battery className="w-3 h-3 text-emerald-400 shrink-0" />
              <span className="truncate">Power</span>
            </div>
            <span className="text-[10px] sm:text-[11px] font-mono font-semibold text-emerald-400 truncate mt-0.5 leading-tight">
              {batteryDisplay}
            </span>
          </div>

          {/* Chip 4: Nodes Online */}
          <div className="flex flex-col items-center justify-center py-1 px-1 rounded-xl bg-slate-900/60 border border-white/5 text-center min-w-0">
            <div className="flex items-center space-x-1 text-slate-400 text-[10px]">
              <Users className="w-3 h-3 text-cyan-400 shrink-0" />
              <span className="truncate">Peers</span>
            </div>
            <span className="text-[10px] sm:text-[11px] font-mono font-semibold text-slate-100 truncate mt-0.5 leading-tight">
              {isConnected ? `${Math.max(1, Object.keys(nodes).length)} Mesh` : '--'}
            </span>
          </div>
        </div>
      </div>

      {/* Floating Tactical Vector HUD Card for Selected Node */}
      {selectedNode && (
        <div className="absolute bottom-4 left-3 right-16 sm:left-4 sm:right-20 z-[500] pointer-events-auto max-w-lg">
          <div className="p-3 rounded-2xl backdrop-blur-2xl bg-slate-950/90 border border-cyan-400/40 shadow-2xl flex flex-col space-y-2">
            <div className="flex items-center justify-between border-b border-white/10 pb-1.5">
              <div className="flex items-center space-x-2">
                <span className="w-2 h-2 rounded-full bg-cyan-400 animate-pulse" />
                <span className="font-bold text-sm text-cyan-300">{selectedNode.shortName}</span>
                <span className="font-mono text-[10px] text-slate-400">{selectedNode.hexId}</span>
                {selectedNode.isEmergency && (
                  <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-rose-500/20 text-rose-400 border border-rose-500/40 animate-pulse">
                    DISTRESS
                  </span>
                )}
              </div>
              <button
                onClick={() => setSelectedNodeNum(null)}
                className="p-1 rounded-lg hover:bg-white/10 text-slate-400 hover:text-white transition-colors cursor-pointer"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>

            {tacticalVector ? (
              <div className="grid grid-cols-4 gap-1.5 text-center">
                <div className="p-1 rounded-xl bg-slate-900/60 border border-white/5">
                  <div className="text-[9px] font-mono text-slate-400">RANGE</div>
                  <div className="text-xs font-mono font-bold text-cyan-300">
                    {tacticalVector.distanceFormatted}
                  </div>
                </div>

                <div className="p-1 rounded-xl bg-slate-900/60 border border-white/5">
                  <div className="text-[9px] font-mono text-slate-400">BEARING</div>
                  <div className="text-xs font-mono font-bold text-emerald-400 flex items-center justify-center space-x-0.5">
                    <Compass
                      className="w-3 h-3 inline text-emerald-400"
                      style={{ transform: `rotate(${tacticalVector.bearing}deg)` }}
                    />
                    <span>{tacticalVector.bearingFormatted}</span>
                  </div>
                </div>

                <div className="p-1 rounded-xl bg-slate-900/60 border border-white/5">
                  <div className="text-[9px] font-mono text-slate-400">EST. PACE</div>
                  <div className="text-xs font-mono font-bold text-amber-300">
                    {tacticalVector.paceTime}
                  </div>
                </div>

                <div className="p-1 rounded-xl bg-slate-900/60 border border-white/5">
                  <div className="text-[9px] font-mono text-slate-400">ALT DELTA</div>
                  <div className="text-xs font-mono font-bold text-slate-200">
                    {tacticalVector.altDiff !== null
                      ? `${tacticalVector.altDiff > 0 ? `+${tacticalVector.altDiff}` : tacticalVector.altDiff} m`
                      : '--'}
                  </div>
                </div>
              </div>
            ) : (
              <div className="text-[11px] text-slate-400 font-mono">
                {selectedNode.isLocal ? 'Host Station (This Unit)' : 'Waiting for GPS fix from peer node'}
              </div>
            )}

            <div className="flex items-center justify-end space-x-2 pt-1 border-t border-white/5">
              <button
                onClick={() => {
                  if (selectedNode.position) {
                    setPanTarget([selectedNode.position.latitude, selectedNode.position.longitude]);
                  }
                }}
                className="px-2.5 py-1 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold flex items-center space-x-1 cursor-pointer transition-colors"
              >
                <ArrowUpRight className="w-3 h-3 text-cyan-400" />
                <span>Pan To</span>
              </button>
              <button
                onClick={() => {
                  setActiveTab('comms');
                }}
                className="px-2.5 py-1 rounded-xl bg-cyan-500/20 hover:bg-cyan-500/30 border border-cyan-400/40 text-cyan-300 text-xs font-semibold flex items-center space-x-1 cursor-pointer transition-colors"
              >
                <MessageSquare className="w-3 h-3" />
                <span>Radio Ping</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Floating Quick Action Buttons on Bottom-Right */}
      <div className="absolute bottom-4 right-4 z-[500] flex flex-col space-y-2.5">
        <button
          onClick={handleCenterLocal}
          className="w-11 h-11 rounded-2xl backdrop-blur-xl bg-slate-950/85 hover:bg-slate-900 active:scale-95 border border-white/10 flex items-center justify-center text-slate-200 hover:text-cyan-400 shadow-xl transition-all cursor-pointer"
          title="Center on My Node"
        >
          <Crosshair className="w-5 h-5" />
        </button>

        <button
          onClick={handleBroadcastPosition}
          disabled={isBroadcasting}
          className="w-11 h-11 rounded-2xl backdrop-blur-xl bg-cyan-500/20 hover:bg-cyan-500/30 active:scale-95 border border-cyan-400/40 flex items-center justify-center text-cyan-300 shadow-xl transition-all cursor-pointer"
          title="Broadcast GPS Ping to Mesh"
        >
          <Navigation className={`w-5 h-5 ${isBroadcasting ? 'animate-spin' : ''}`} />
        </button>
      </div>
    </div>
  );
};
