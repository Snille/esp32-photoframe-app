import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/server_models.dart';
import '../../providers/server_provider.dart';
import '../../widgets/theme_menu.dart';
import 'server_device_detail_screen.dart';
import 'server_preview.dart';

/// Server mode home: the frames managed by the connected photoframe-server,
/// with battery status and a live "what's on the wall" preview per frame.
class ServerDashboardScreen extends StatefulWidget {
  const ServerDashboardScreen({super.key});

  @override
  State<ServerDashboardScreen> createState() => _ServerDashboardScreenState();
}

class _ServerDashboardScreenState extends State<ServerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<ServerProvider>();
    if (provider.devices.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => provider.loadDevices());
    }
  }

  Future<void> _logout() async {
    final provider = context.read<ServerProvider>();
    await provider.disconnect();
    if (mounted) context.go('/devices');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServerProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photoframe Server'),
        actions: [
          const ThemeMenu(),
          IconButton(
            icon: const Icon(Icons.devices_other),
            tooltip: 'Local device mode',
            onPressed: () => context.go('/devices'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('Disconnect')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.loadDevices,
        child: _body(context, provider),
      ),
    );
  }

  Widget _body(BuildContext context, ServerProvider provider) {
    if (provider.loading && provider.devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.devices.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.photo_library_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Center(
            child: Text(
              provider.error ?? 'No frames on this server yet.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: provider.devices.length,
      itemBuilder: (context, i) {
        final d = provider.devices[i];
        return _DeviceCard(
          device: d,
          battery: provider.batteryFor(d.id),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServerDeviceDetailScreen(deviceId: d.id),
            ),
          ),
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final ServerDevice device;
  final BatteryEstimate battery;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.device,
    required this.battery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ServerProvider>();
    final source = device.source;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: device.viewAspectRatio,
              child: ServerPreview(
                client: provider.client,
                host: device.host,
                source: source,
                fit: BoxFit.cover,
                quarterTurns: device.previewQuarterTurns,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          source == null
                              ? device.host
                              : '${device.host} · ${_titleForSource(source)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  BatteryChip(battery: battery),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _titleForSource(String s) {
  switch (s) {
    case 'immich':
      return 'Immich';
    case 'gallery':
      return 'Gallery';
    case 'ai_generation':
      return 'AI';
    case 'synology_photos':
      return 'Synology';
    case 'google_photos':
      return 'Google Photos';
    case 'url_proxy':
      return 'URL';
    default:
      return s
          .split('_')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
  }
}

/// Small battery status chip used on cards and the detail screen.
class BatteryChip extends StatelessWidget {
  final BatteryEstimate battery;
  const BatteryChip({super.key, required this.battery});

  @override
  Widget build(BuildContext context) {
    if (!battery.hasData) {
      return Chip(
        avatar: const Icon(Icons.battery_unknown, size: 18),
        label: const Text('—'),
        visualDensity: VisualDensity.compact,
      );
    }
    final pct = battery.currentPercent;
    Color color;
    if (pct < 20) {
      color = Colors.red;
    } else if (pct < 50) {
      color = Colors.orange;
    } else {
      color = Colors.green;
    }
    IconData icon;
    switch (battery.trend) {
      case 'charging':
        icon = Icons.battery_charging_full;
        break;
      case 'discharging':
        icon = Icons.battery_5_bar;
        break;
      default:
        icon = Icons.battery_std;
    }
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text('$pct%'),
      visualDensity: VisualDensity.compact,
    );
  }
}
