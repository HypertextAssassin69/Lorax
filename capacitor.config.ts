import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'org.meshtastic.sar.rescuecmd',
  appName: 'SAR Tactical Command',
  webDir: 'dist',
  server: {
    androidScheme: 'https',
    cleartext: true,
  },
  plugins: {
    BluetoothLe: {
      displayStrings: {
        scanning: "Scanning for Meshtastic SAR nodes...",
        cancel: "Cancel",
        availableDevices: "Available SAR Rescue Nodes",
        noDeviceFound: "No Meshtastic nodes detected"
      }
    }
  }
};

export default config;
