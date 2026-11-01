import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/providers/bluetooth_provider.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _calcIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith('/home')) return 0;
    if (loc.startsWith('/map')) return 1;
    if (loc.startsWith('/network')) return 2;
    if (loc.startsWith('/emergency')) return 3;
    if (loc.startsWith('/devices')) return 4;
    return 0;
  }

  void _showConnectionModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const _ConnectionSheet(),
    );
  }

  void _go(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/map');
        break;
      case 2:
        context.go('/network');
        break;
      case 3:
        context.go('/emergency');
        break;
      case 4:
        context.go('/devices');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBleConnected = ref.watch(meshtasticConnectionStateProvider);
    final bleDeviceName = ref.watch(meshtasticDeviceNameProvider) ?? 'Meshtastic_af88';
    final isUsbConnected = ref.watch(hardwareConnectionStateProvider);
    final isAnyConnected = isBleConnected || isUsbConnected;

    final index = _calcIndex(context);
    final isDesktop = MediaQuery.of(context).size.width > 700;

    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.shield_outlined),
        selectedIcon: Icon(Icons.shield),
        label: 'Dashboard',
      ),
      NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map),
        label: 'Map',
      ),
      NavigationDestination(
        icon: Icon(Icons.hub_outlined),
        selectedIcon: Icon(Icons.hub),
        label: 'Mesh Network',
      ),
      NavigationDestination(
        icon: Icon(Icons.warning_amber_outlined),
        selectedIcon: Icon(Icons.warning_amber),
        label: 'Emergency',
      ),
      NavigationDestination(
        icon: Icon(Icons.devices_outlined),
        selectedIcon: Icon(Icons.devices),
        label: 'Nodes',
      ),
    ];

    const railDest = [
      NavigationRailDestination(
        icon: Icon(Icons.shield_outlined),
        selectedIcon: Icon(Icons.shield),
        label: Text('Dashboard'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map),
        label: Text('Map'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.hub_outlined),
        selectedIcon: Icon(Icons.hub),
        label: Text('Mesh Network'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.warning_amber_outlined),
        selectedIcon: Icon(Icons.warning_amber),
        label: Text('Emergency'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.devices_outlined),
        selectedIcon: Icon(Icons.devices),
        label: Text('Nodes'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        title: Row(
          children: [
            Text(
              'RESCUELINK',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE SAR',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
        actions: [
          // Hardware Node connection chip
          InkWell(
            onTap: () => _showConnectionModal(context, ref),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: (isAnyConnected
                          ? (isBleConnected ? AppTheme.secondaryColor : AppTheme.safeColor)
                          : AppTheme.offlineColor)
                      .withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(8),
                color: isAnyConnected
                    ? (isBleConnected
                        ? AppTheme.secondaryColor.withValues(alpha: 0.12)
                        : AppTheme.safeColor.withValues(alpha: 0.12))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isBleConnected
                        ? Icons.bluetooth_connected
                        : (isUsbConnected ? Icons.usb : Icons.sensors_off),
                    size: 16,
                    color: isBleConnected
                        ? AppTheme.secondaryColor
                        : (isUsbConnected ? AppTheme.safeColor : AppTheme.offlineColor),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isBleConnected
                        ? bleDeviceName
                        : (isUsbConnected ? 'USB LIVE' : 'CONNECT NODE'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isBleConnected
                          ? AppTheme.secondaryColor
                          : (isUsbConnected ? AppTheme.safeColor : AppTheme.offlineColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => _go(i, context),
              labelType: NavigationRailLabelType.all,
              destinations: railDest,
            ),
          if (isDesktop)
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => _go(i, context),
              destinations: destinations,
            )
          : null,
    );
  }
}

class _ConnectionSheet extends ConsumerStatefulWidget {
  const _ConnectionSheet();

  @override
  ConsumerState<_ConnectionSheet> createState() => _ConnectionSheetState();
}

class _ConnectionSheetState extends ConsumerState<_ConnectionSheet> {
  bool _isScanning = false;

  final List<Map<String, String>> _targetNodes = const [
    {'name': 'Meshtastic_af88', 'mac': '10:BD:A3:97:AF:8A', 'desc': 'Active Nearby Node (Seeed ESP32-C6)'},
    {'name': 'Meshtastic_9448', 'mac': 'Node ID: 0xa3999448', 'desc': 'LoRa SAR Node 1 (868 MHz)'},
    {'name': 'Meshtastic_aee8', 'mac': 'Node ID: 0xa399aee8', 'desc': 'LoRa SAR Node 2 (868 MHz)'},
  ];

  @override
  Widget build(BuildContext context) {
    final bleService = ref.watch(meshtasticBleServiceProvider);
    final isBleConnected = ref.watch(meshtasticConnectionStateProvider);
    final isUsbConnected = ref.watch(hardwareConnectionStateProvider);
    final connectedName = ref.watch(meshtasticDeviceNameProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.bluetooth_searching, color: AppTheme.secondaryColor, size: 26),
                const SizedBox(width: 10),
                Text(
                  'Meshtastic SAR LoRa Node',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Target nodes: Meshtastic_af88, Meshtastic_9448, Meshtastic_aee8 (PIN: 123456)',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),

            // Brave Browser Notice
            if (kIsWeb)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Browser Pairing Notice (Brave / Chrome / Edge)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Clicking "PAIR WITH BLUETOOTH" opens your browser\'s native pairing popup at the top of your window. Select Meshtastic_af88 and enter PIN 123456.\n\n⚠️ NOTE: Brave Browser blocks Bluetooth by default. If no popup appears, open http://localhost:8080 in Google Chrome or Microsoft Edge.',
                            style: TextStyle(fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Big Action Button: Open Browser Bluetooth Chooser
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bluetooth_searching, size: 24),
              label: Text(
                _isScanning ? 'OPENING BLUETOOTH CHOOSER...' : 'PAIR WITH BLUETOOTH (PIN: 123456)',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
              ),
              onPressed: _isScanning
                  ? null
                  : () async {
                      setState(() => _isScanning = true);
                      await bleService.connect();
                      await Future.delayed(const Duration(seconds: 3));
                      if (mounted) setState(() => _isScanning = false);
                    },
            ),

            const SizedBox(height: 16),

            // Target Nodes List
            const Text(
              'TARGET HARDWARE NODES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            ..._targetNodes.map(
              (node) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: node['name'] == 'Meshtastic_af88'
                        ? AppTheme.secondaryColor.withValues(alpha: 0.5)
                        : Colors.grey.withValues(alpha: 0.2),
                    width: node['name'] == 'Meshtastic_af88' ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.memory,
                    color: node['name'] == 'Meshtastic_af88' ? AppTheme.secondaryColor : Colors.grey,
                  ),
                  title: Text(node['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text('${node['mac']} • ${node['desc']}', style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: node['name'] == 'Meshtastic_af88' ? AppTheme.safeColor : AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () async {
                      await bleService.connect(node['name']);
                    },
                    child: const Text('PAIR (123456)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),

            const Divider(height: 24),

            // USB Fallback Bridge
            ListTile(
              leading: const Icon(Icons.usb, color: AppTheme.safeColor),
              title: const Text('USB-C Web Serial Bridge', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Direct 115200 baud USB COM Port to Seeed ESP32-C6'),
              trailing: isUsbConnected
                  ? const Icon(Icons.check_circle, color: AppTheme.safeColor)
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(hardwareSerialServiceProvider).connect();
              },
            ),

            if (isBleConnected || isUsbConnected) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.emergencyRed,
                  side: const BorderSide(color: AppTheme.emergencyRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.power_settings_new),
                label: Text('DISCONNECT ${connectedName ?? "ACTIVE NODE"}'),
                onPressed: () async {
                  Navigator.pop(context);
                  if (isBleConnected) await bleService.disconnect();
                  if (isUsbConnected) await ref.read(hardwareSerialServiceProvider).disconnect();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
