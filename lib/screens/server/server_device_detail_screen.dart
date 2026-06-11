import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/server_models.dart';
import '../../providers/server_provider.dart';
import 'server_dashboard_screen.dart' show BatteryChip;
import 'server_preview.dart';

/// Per-frame controls in server mode: live preview, source + Immich album
/// selection (applies on the frame's next pull), battery status, and a manual
/// refresh of live device state.
class ServerDeviceDetailScreen extends StatefulWidget {
  final int deviceId;
  const ServerDeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<ServerDeviceDetailScreen> createState() =>
      _ServerDeviceDetailScreenState();
}

class _ServerDeviceDetailScreenState extends State<ServerDeviceDetailScreen> {
  int _previewBust = DateTime.now().millisecondsSinceEpoch;
  bool _busy = false;

  void _reloadPreview() =>
      setState(() => _previewBust = DateTime.now().millisecondsSinceEpoch);

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    _reloadPreview();
    final msg = err ?? 'Done';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServerProvider>();
    final device = provider.deviceById(widget.deviceId);
    if (device == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final battery = provider.batteryFor(device.id);
    final source = device.source;

    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload preview',
            onPressed: _busy ? null : _reloadPreview,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: device.viewAspectRatio,
              child: ServerPreview(
                client: provider.client,
                host: device.host,
                source: source,
                fit: BoxFit.contain,
                cacheBust: _previewBust,
                quarterTurns: device.previewQuarterTurns,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Preview of what this frame shows next — rendered by the server, '
            'so it works even while the frame is asleep.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          // Battery
          _SectionTitle('Battery'),
          Row(
            children: [
              BatteryChip(battery: battery),
              const SizedBox(width: 12),
              Expanded(child: Text(_batteryLine(battery))),
            ],
          ),
          const SizedBox(height: 24),

          // Source
          _SectionTitle('Image source'),
          DropdownButtonFormField<String>(
            initialValue: provider.sources.contains(source) ? source : null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.collections_outlined),
            ),
            items: provider.sources
                .map((s) => DropdownMenuItem(value: s, child: Text(_title(s))))
                .toList(),
            onChanged: _busy
                ? null
                : (v) {
                    if (v != null && v != source) {
                      _run(() => provider.changeSource(device, v));
                    }
                  },
          ),
          const SizedBox(height: 6),
          Text(
            'Applies on the frame’s next scheduled pull.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),

          // Immich albums (only when this frame pulls Immich)
          if (source == 'immich') ...[
            const SizedBox(height: 24),
            _SectionTitle('Immich albums (this frame)'),
            if (provider.albums.isEmpty)
              Text(
                'No Immich albums available (Immich not configured on the server).',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              _AlbumPicker(device: device, busy: _busy, onChange: _run),
            const SizedBox(height: 6),
            Text(
              'Empty = all Immich photos this server syncs.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],

          const SizedBox(height: 28),
          // Quick action: refresh live state (needs the frame awake)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(() => provider.refreshDevice(device)),
            icon: const Icon(Icons.sync),
            label: const Text('Refresh from frame (needs it awake)'),
          ),
        ],
      ),
    );
  }

  String _title(String s) => s
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _batteryLine(BatteryEstimate b) {
    if (!b.hasData) return 'No battery data reported yet.';
    final parts = <String>[];
    if (b.trend == 'discharging' && b.daysRemaining > 0) {
      parts.add('~${b.drainPerDay.toStringAsFixed(1)} %/day');
      parts.add('est. ${b.daysRemaining.toStringAsFixed(0)} days left');
    } else {
      parts.add(b.trend);
    }
    if (b.lastSampledAt != null) {
      parts.add('seen ${_ago(b.lastSampledAt!)}');
    }
    return parts.join(' · ');
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

class _AlbumPicker extends StatelessWidget {
  final ServerDevice device;
  final bool busy;
  final Future<void> Function(Future<String?> Function()) onChange;

  const _AlbumPicker({
    required this.device,
    required this.busy,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ServerProvider>();
    final selected = device.immichAlbumIdList.toSet();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: provider.albums.map((a) {
        final on = selected.contains(a.id);
        return FilterChip(
          label: Text(a.name),
          selected: on,
          onSelected: busy
              ? null
              : (val) {
                  final next = Set<String>.from(selected);
                  if (val) {
                    next.add(a.id);
                  } else {
                    next.remove(a.id);
                  }
                  onChange(() => provider.changeAlbums(device, next.toList()));
                },
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
