/**
 * Tactical Mission Data Exporter for Search & Rescue (SAR) operations
 * Exports live ground-truth mesh coordinates to standard GPX 1.1, GeoJSON, and CSV formats.
 */

import { MeshNode, DistressAlert, MeshChatMessage } from '../types/meshtastic';

function downloadBlob(content: string, filename: string, mimeType: string): void {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

/**
 * Exports all active nodes and emergency distress locations to standard GPX 1.1 format
 * (Compatible with Garmin GPS, OsmAnd, Google Earth, CalTopo, and QGIS).
 */
export function exportMissionGpx(
  nodes: Record<number, MeshNode>,
  distressAlerts: DistressAlert[],
  missionName = 'Lorax-SAR-Mission'
): void {
  const timestamp = new Date().toISOString();
  let gpx = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Lorax Tactical Command - Meshtastic LoRa"
     xmlns="http://www.topografix.com/GPX/1/1"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata>
    <name>${missionName}</name>
    <time>${timestamp}</time>
    <desc>Search and Rescue Tactical Mesh Telemetry Export</desc>
  </metadata>
`;

  // 1. Waypoints for Mesh Nodes with coordinates
  for (const node of Object.values(nodes)) {
    if (node.position && node.position.latitude && node.position.longitude) {
      const lat = node.position.latitude.toFixed(6);
      const lon = node.position.longitude.toFixed(6);
      const ele = node.position.altitude ? `<ele>${node.position.altitude}</ele>` : '';
      const time = node.lastHeard ? `<time>${new Date(node.lastHeard).toISOString()}</time>` : '';
      const type = node.isLocal ? 'Host Node' : node.isEmergency ? 'Distress Node' : 'Mesh Peer';

      gpx += `  <wpt lat="${lat}" lon="${lon}">
    ${ele}
    ${time}
    <name>${escapeXml(node.shortName)}</name>
    <desc>${escapeXml(node.longName)} (${node.hexId}) - Battery: ${node.metrics?.batteryLevel ?? '--'}% | SNR: ${node.snr ?? '--'} dB</desc>
    <type>${type}</type>
  </wpt>\n`;
    }
  }

  // 2. Waypoints for Emergency Distress Events
  for (const alert of distressAlerts) {
    if (alert.position && alert.position.latitude && alert.position.longitude) {
      const lat = alert.position.latitude.toFixed(6);
      const lon = alert.position.longitude.toFixed(6);
      const time = `<time>${new Date(alert.timestamp).toISOString()}</time>`;

      gpx += `  <wpt lat="${lat}" lon="${lon}">
    ${time}
    <name>SOS: ${escapeXml(alert.senderName)}</name>
    <desc>EMERGENCY DISTRESS: ${escapeXml(alert.message || 'No note')} (${alert.alertType} - Ack: ${alert.acknowledged})</desc>
    <type>Emergency SOS</type>
    <sym>Danger</sym>
  </wpt>\n`;
    }
  }

  gpx += `</gpx>`;
  const dateStr = new Date().toISOString().slice(0, 10);
  downloadBlob(gpx, `${missionName}-${dateStr}.gpx`, 'application/gpx+xml');
}

/**
 * Exports nodes and emergency locations to GeoJSON FeatureCollection
 */
export function exportMissionGeoJson(
  nodes: Record<number, MeshNode>,
  distressAlerts: DistressAlert[]
): void {
  const features: any[] = [];

  for (const node of Object.values(nodes)) {
    if (node.position && node.position.latitude && node.position.longitude) {
      features.push({
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [
            node.position.longitude,
            node.position.latitude,
            node.position.altitude || 0,
          ],
        },
        properties: {
          nodeNum: node.num,
          hexId: node.hexId,
          shortName: node.shortName,
          longName: node.longName,
          isLocal: node.isLocal,
          isEmergency: node.isEmergency,
          batteryLevel: node.metrics?.batteryLevel,
          voltage: node.metrics?.voltage,
          snr: node.snr,
          lastHeard: node.lastHeard,
        },
      });
    }
  }

  for (const alert of distressAlerts) {
    if (alert.position && alert.position.latitude && alert.position.longitude) {
      features.push({
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [
            alert.position.longitude,
            alert.position.latitude,
            alert.position.altitude || 0,
          ],
        },
        properties: {
          alertId: alert.id,
          senderNum: alert.senderNum,
          senderName: alert.senderName,
          type: 'EMERGENCY_SOS',
          alertType: alert.alertType,
          acknowledged: alert.acknowledged,
          message: alert.message,
          timestamp: alert.timestamp,
        },
      });
    }
  }

  const geoJson = {
    type: 'FeatureCollection',
    metadata: {
      generator: 'Lorax Tactical Command',
      timestamp: new Date().toISOString(),
    },
    features,
  };

  const dateStr = new Date().toISOString().slice(0, 10);
  downloadBlob(
    JSON.stringify(geoJson, null, 2),
    `lorax-mesh-features-${dateStr}.geojson`,
    'application/geo+json'
  );
}

/**
 * Exports all radio communications to CSV
 */
export function exportCommsCsv(
  messages: MeshChatMessage[],
  nodes: Record<number, MeshNode>
): void {
  const headers = ['Timestamp', 'ISO Time', 'Sender Hex', 'Sender Name', 'Recipient', 'Text', 'ACK Status'];
  const rows = messages.map((m) => {
    const sender = nodes[m.from]?.shortName || `!${(m.from >>> 0).toString(16)}`;
    const recipient = m.to === 0xffffffff ? 'BROADCAST' : nodes[m.to]?.shortName || `!${(m.to >>> 0).toString(16)}`;
    return [
      m.timestamp,
      new Date(m.timestamp).toISOString(),
      `!${(m.from >>> 0).toString(16)}`,
      `"${sender.replace(/"/g, '""')}"`,
      `"${recipient.replace(/"/g, '""')}"`,
      `"${m.text.replace(/"/g, '""')}"`,
      m.ackStatus || 'NONE',
    ].join(',');
  });

  const csv = [headers.join(','), ...rows].join('\n');
  const dateStr = new Date().toISOString().slice(0, 10);
  downloadBlob(csv, `lorax-comms-log-${dateStr}.csv`, 'text/csv');
}

function escapeXml(unsafe: string): string {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}
