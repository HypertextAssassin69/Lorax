import { create } from 'zustand';
import { alertAudioService } from '../services/alertAudioService';
import {
  ConnectionState,
  TransportType,
  MeshNode,
  MeshChatMessage,
  DistressAlert,
  RawPacketLog,
  TracerouteResult,
  LocalNodeInfo,
} from '../types/meshtastic';

interface MeshStoreState {
  // Connection state
  connectionState: ConnectionState;
  transportType: TransportType;
  errorMessage: string | null;
  configCompleted: boolean;
  
  // Local connected node
  localNode: LocalNodeInfo | null;
  
  // Mesh database
  nodes: Record<number, MeshNode>;
  
  // Comms and telemetry logs
  messages: MeshChatMessage[];
  distressAlerts: DistressAlert[];
  rawPackets: RawPacketLog[];
  traceroutes: TracerouteResult[];
  
  // UI Selection
  selectedNodeNum: number | null;
  activeTab: 'map' | 'sos' | 'comms' | 'nodes';
  unreadDistressCount: number;
  isAudioMuted: boolean;

  // Actions
  toggleAudioMute: () => void;
  setConnectionState: (state: ConnectionState, transport?: TransportType, error?: string | null) => void;
  setLocalNodeInfo: (update: Partial<LocalNodeInfo>) => void;
  upsertNode: (update: Partial<MeshNode> & { num: number }) => void;
  addChatMessage: (msg: MeshChatMessage) => void;
  updateMessageAck: (packetId: number, status: 'ACKED' | 'ROUTING' | 'FAILED', ackBy?: number) => void;
  addDistressAlert: (alert: DistressAlert) => void;
  acknowledgeDistress: (id: string) => void;
  addRawPacketLog: (log: RawPacketLog) => void;
  addTracerouteResult: (result: TracerouteResult) => void;
  setSelectedNodeNum: (num: number | null) => void;
  setActiveTab: (tab: 'map' | 'sos' | 'comms' | 'nodes') => void;
  clearPacketLogs: () => void;
  resetAll: () => void;
}

export const useMeshStore = create<MeshStoreState>((set, get) => ({
  connectionState: 'DISCONNECTED',
  transportType: 'NONE',
  errorMessage: null,
  configCompleted: false,
  
  localNode: null,
  nodes: {},
  
  messages: [],
  distressAlerts: [],
  rawPackets: [],
  traceroutes: [],
  
  selectedNodeNum: null,
  activeTab: 'map',
  unreadDistressCount: 0,
  isAudioMuted: alertAudioService.getMuted(),

  toggleAudioMute: () => {
    const nextMuted = alertAudioService.toggleMuted();
    set({ isAudioMuted: nextMuted });
  },

  setConnectionState: (state, transport, error = null) => {
    const prev = get();
    if (state === 'CONNECTED' && prev.connectionState !== 'CONNECTED') {
      alertAudioService.playConnectChime();
    }
    set((prev) => ({
      connectionState: state,
      transportType: transport !== undefined ? transport : prev.transportType,
      errorMessage: error,
      configCompleted: state === 'CONNECTED' ? prev.configCompleted : false,
      // If disconnected, preserve nothing or reset according to honest hardware-only state
      ...(state === 'DISCONNECTED'
        ? {
            localNode: null,
            configCompleted: false,
          }
        : {}),
    }));
  },

  setLocalNodeInfo: (update) => {
    set((prev) => {
      const current = prev.localNode ?? {
        myNodeNum: 0,
        hexId: '!00000000',
        shortName: 'RESCUE-C6',
        longName: 'Rescue Node C6',
        firmwareVersion: 'Meshtastic 2.5+',
        rebootCount: 0,
        hardware: {
          sx1262Spi: true,
          neo6mGpsUart: false,
          mpu6050I2c: false,
          sosButtonD6: true,
          piezoBeaconD0: true,
          firmwareVersion: 'Meshtastic 2.5+',
          rebootCount: 0,
        },
      };

      const updatedLocal: LocalNodeInfo = {
        ...current,
        ...update,
        hardware: {
          ...current.hardware,
          ...(update.hardware ?? {}),
          firmwareVersion: update.firmwareVersion ?? current.hardware.firmwareVersion,
          rebootCount: update.rebootCount ?? current.hardware.rebootCount,
        },
      };

      return {
        localNode: updatedLocal,
      };
    });
  },

  upsertNode: (update) => {
    set((prev) => {
      const existing = prev.nodes[update.num];
      const hexId = update.hexId || existing?.hexId || `!${(update.num >>> 0).toString(16).padStart(8, '0')}`;
      
      const merged: MeshNode = {
        num: update.num,
        hexId,
        shortName: update.shortName ?? existing?.shortName ?? hexId.slice(-4).toUpperCase(),
        longName: update.longName ?? existing?.longName ?? `Node ${hexId}`,
        hwModel: update.hwModel ?? existing?.hwModel ?? 'Seeed XIAO ESP32C6',
        macaddr: update.macaddr ?? existing?.macaddr,
        lastHeard: update.lastHeard ?? existing?.lastHeard ?? Date.now(),
        hopsAway: update.hopsAway ?? existing?.hopsAway ?? 0,
        snr: update.snr ?? existing?.snr ?? 0,
        rssi: update.rssi ?? existing?.rssi,
        position: update.position ? { ...(existing?.position ?? {}), ...update.position } : existing?.position,
        metrics: update.metrics ? { ...(existing?.metrics ?? {}), ...update.metrics } : existing?.metrics,
        isLocal: update.isLocal ?? existing?.isLocal ?? false,
        isEmergency: update.isEmergency ?? existing?.isEmergency ?? false,
        emergencyTimestamp: update.emergencyTimestamp ?? existing?.emergencyTimestamp,
        emergencyNote: update.emergencyNote ?? existing?.emergencyNote,
        fallDetected: update.fallDetected ?? existing?.fallDetected ?? false,
      };

      return {
        nodes: {
          ...prev.nodes,
          [update.num]: merged,
        },
      };
    });
  },

  addChatMessage: (msg) => {
    const localNum = get().localNode?.myNodeNum;
    if (msg.from !== localNum) {
      alertAudioService.playMessageChime();
    }
    set((prev) => ({
      messages: [msg, ...prev.messages.slice(0, 199)], // keep last 200 messages
    }));
  },

  updateMessageAck: (packetId, status, ackBy) => {
    set((prev) => ({
      messages: prev.messages.map((m) =>
        m.packetId === packetId
          ? {
              ...m,
              ackStatus: status,
              ackBy: ackBy ?? m.ackBy,
            }
          : m
      ),
    }));
  },

  addDistressAlert: (alert) => {
    alertAudioService.playSosAlarm();
    set((prev) => {
      // Avoid duplicate alert by id
      const exists = prev.distressAlerts.some((a) => a.id === alert.id);
      if (exists) return prev;

      return {
        distressAlerts: [alert, ...prev.distressAlerts.slice(0, 99)],
        unreadDistressCount: prev.unreadDistressCount + 1,
      };
    });
  },

  acknowledgeDistress: (id) => {
    set((prev) => ({
      distressAlerts: prev.distressAlerts.map((a) =>
        a.id === id ? { ...a, acknowledged: true, acknowledgedAt: Date.now() } : a
      ),
      unreadDistressCount: Math.max(0, prev.unreadDistressCount - 1),
    }));
  },

  addRawPacketLog: (log) => {
    set((prev) => ({
      rawPackets: [log, ...prev.rawPackets.slice(0, 299)], // keep last 300 logs
    }));
  },

  addTracerouteResult: (result) => {
    set((prev) => ({
      traceroutes: [result, ...prev.traceroutes.slice(0, 49)],
    }));
  },

  setSelectedNodeNum: (num) => {
    set({ selectedNodeNum: num });
  },

  setActiveTab: (tab) => {
    set({
      activeTab: tab,
      ...(tab === 'sos' ? { unreadDistressCount: 0 } : {}),
    });
  },

  clearPacketLogs: () => {
    set({ rawPackets: [] });
  },

  resetAll: () => {
    set({
      connectionState: 'DISCONNECTED',
      transportType: 'NONE',
      errorMessage: null,
      configCompleted: false,
      localNode: null,
      nodes: {},
      messages: [],
      distressAlerts: [],
      rawPackets: [],
      traceroutes: [],
      selectedNodeNum: null,
      unreadDistressCount: 0,
    });
  },
}));
