import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/server_models.dart';
import '../../providers/server_provider.dart';
import 'server_preview.dart';

const _positions = <String, String>{
  'top-left': 'Top left',
  'top-center': 'Top center',
  'top-right': 'Top right',
  'bottom-left': 'Bottom left',
  'bottom-center': 'Bottom center',
  'bottom-right': 'Bottom right',
  'wide-top': 'Wide band (top)',
  'wide-bottom': 'Wide band (bottom)',
};
const _fonts = <String, String>{
  'noto_sans': 'Noto Sans',
  'inter': 'Inter',
  'dejavu_sans': 'DejaVu Sans',
  'liberation_sans': 'Liberation Sans',
  'dejavu_serif': 'DejaVu Serif',
  'ole': 'Ole (handwritten)',
};
const _weights = <String, String>{
  'regular': 'Regular',
  'medium': 'Medium',
  'bold': 'Bold',
};
const _batteryStyles = <String, String>{
  'both': 'Icon + text',
  'icon': 'Icon only',
  'text': 'Text only',
};
const _textSides = <String, String>{'right': 'Right', 'left': 'Left'};
const _nameFormats = <String, String>{
  'first_last': 'First Last',
  'first_initial': 'First + initial',
  'first': 'First only',
  'last_first': 'Last, First',
  'last_initial': 'Last + initial',
  'last': 'Last only',
};
const _layouts = <String, String>{
  'photo_overlay': 'Photo overlay',
  'photo_info': 'Photo + info panel',
  'side_panel': 'Side panel',
};
const _displayModes = <String, String>{
  'cover': 'Cover (fill)',
  'fit': 'Fit (letterbox)',
};

/// Full overlay editor for a server-managed frame — mirrors the web UI's
/// Overlay tab, with a live server-rendered preview that refreshes after every
/// change. Auto-saves (debounced) via the full-device PUT.
class ServerOverlayScreen extends StatefulWidget {
  final int deviceId;
  const ServerOverlayScreen({super.key, required this.deviceId});

  @override
  State<ServerOverlayScreen> createState() => _ServerOverlayScreenState();
}

class _ServerOverlayScreenState extends State<ServerOverlayScreen> {
  late Map<String, dynamic> _d;
  Timer? _debounce;
  bool _saving = false;
  int _previewBust = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    final device = context.read<ServerProvider>().deviceById(widget.deviceId);
    _d = Map<String, dynamic>.from(device?.raw ?? const {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // --- typed readers ---
  bool _b(String k) => _d[k] == true;
  String _s(String k, String def) {
    final v = _d[k];
    return (v is String && v.isNotEmpty) ? v : def;
  }

  double _f(String k, double def) {
    final v = _d[k];
    return v is num ? v.toDouble() : def;
  }

  int _i(String k, int def) {
    final v = _d[k];
    return v is num ? v.toInt() : def;
  }

  Set<String> get _hiddenIcons => _s('overlay_hidden_icons', '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  // --- mutation + debounced save ---
  void _patch(String key, dynamic value) {
    setState(() => _d[key] = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  void _setIconShown(String elementKey, bool shown) {
    final set = _hiddenIcons;
    if (shown) {
      set.remove(elementKey);
    } else {
      set.add(elementKey);
    }
    _patch('overlay_hidden_icons', set.join(','));
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saving = true);
    final err =
        await context.read<ServerProvider>().saveDeviceRaw(widget.deviceId, _d);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _previewBust = DateTime.now().millisecondsSinceEpoch;
    });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = ServerDevice(_d);
    final layout = _s('layout', 'photo_overlay');
    final overlayLayout = layout == 'photo_overlay';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overlay'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: device.viewAspectRatio,
              child: ServerPreview(
                client: context.read<ServerProvider>().client,
                host: device.host,
                source: device.source,
                fit: BoxFit.contain,
                cacheBust: _previewBust,
                quarterTurns: device.previewQuarterTurns,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Layout / display
          _card('Layout', [
            _mapDropdown('Layout', 'layout', _layouts, 'photo_overlay'),
            _mapDropdown('Display mode', 'display_mode', _displayModes, 'cover'),
            if (!overlayLayout)
              _hint('Most overlays only render on the “Photo overlay” layout '
                  '(battery shows on all).'),
          ]),

          // Typography
          _card('Typography', [
            _mapDropdown('Font', 'overlay_font', _fonts, 'noto_sans'),
            _mapDropdown('Weight', 'overlay_weight', _weights, 'medium'),
            _slider('Text size', 'overlay_scale', 0.5, 2.0, 15),
          ]),

          // Date
          _card('Date (today)', [
            _switch('Show date', 'show_date'),
            if (_b('show_date'))
              _posDropdown('Position', 'date_position', 'bottom-left'),
            _switch('Show calendar event', 'show_calendar'),
          ]),

          // Photo date
          _card('Photo date', [
            _switch('Show photo date', 'show_photo_date'),
            if (_b('show_photo_date')) ...[
              _posDropdown('Position', 'photo_date_position', 'bottom-left'),
              _iconToggle('photo_date'),
            ],
          ]),

          // Weather
          _card('Weather', [
            _switch('Show weather', 'show_weather'),
            if (_b('show_weather')) ...[
              Row(children: [
                Expanded(child: _num('Latitude', 'weather_lat')),
                const SizedBox(width: 12),
                Expanded(child: _num('Longitude', 'weather_lon')),
              ]),
              const SizedBox(height: 8),
              _posDropdown('Position', 'weather_position', 'bottom-right'),
              _iconToggle('weather'),
            ],
          ]),

          // Battery
          _card('Battery', [
            _switch('Show battery', 'show_battery'),
            if (_b('show_battery')) ...[
              _posDropdown('Position', 'battery_position', 'top-right'),
              _mapDropdown('Style', 'battery_style', _batteryStyles, 'both'),
              _mapDropdown('Text side', 'battery_text_side', _textSides, 'right'),
              _intDropdown('Rotation', 'battery_rotation', const [0, 90, 180, 270],
                  suffix: '°'),
              _slider('Icon size', 'battery_icon_scale', 0.5, 2.0, 15),
            ],
          ]),

          // Names
          _card('People names', [
            _switch('Show names', 'show_names'),
            if (_b('show_names')) ...[
              _posDropdown('Position', 'names_position', 'top-left'),
              _mapDropdown('Name format', 'name_format', _nameFormats, 'first_last'),
              _switch('Show age', 'names_show_age'),
              _slider('Max length', 'names_max_len', 10, 60, 50, asInt: true),
              _iconToggle('names'),
            ],
          ]),

          // Location
          _card('Location', [
            _switch('Show location', 'show_location'),
            if (_b('show_location')) ...[
              _posDropdown('Position', 'location_position', 'bottom-center'),
              _slider('Max length', 'location_max_len', 10, 80, 70, asInt: true),
              _iconToggle('location'),
            ],
          ]),

          // Description
          _card('Description', [
            _switch('Show description', 'show_description'),
            if (_b('show_description')) ...[
              _posDropdown('Position', 'description_position', 'wide-bottom'),
              _slider('Max length', 'description_max_len', 20, 240, 44,
                  asInt: true),
              _iconToggle('description'),
            ],
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- builders ---
  Widget _card(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              ...children,
            ],
          ),
        ),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      );

  Widget _switch(String label, String key) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label),
        value: _b(key),
        onChanged: (v) => _patch(key, v),
      );

  Widget _posDropdown(String label, String key, String def) =>
      _mapDropdown(label, key, _positions, def);

  Widget _mapDropdown(
      String label, String key, Map<String, String> options, String def) {
    final value = options.containsKey(_s(key, def)) ? _s(key, def) : def;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: options.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) {
          if (v != null) _patch(key, v);
        },
      ),
    );
  }

  Widget _intDropdown(String label, String key, List<int> options,
      {String suffix = ''}) {
    final value = options.contains(_i(key, options.first))
        ? _i(key, options.first)
        : options.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: options
            .map((e) => DropdownMenuItem(value: e, child: Text('$e$suffix')))
            .toList(),
        onChanged: (v) {
          if (v != null) _patch(key, v);
        },
      ),
    );
  }

  Widget _slider(String label, String key, double min, double max, int divisions,
      {bool asInt = false}) {
    final value = _f(key, asInt ? min : 1.0).clamp(min, max).toDouble();
    final shown = asInt
        ? value.round().toString()
        : '${(value * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('$label · $shown',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: shown,
          onChanged: (v) =>
              setState(() => _d[key] = asInt ? v.roundToDouble() : v),
          onChangeEnd: (v) => _patch(key, asInt ? v.round() : v),
        ),
      ],
    );
  }

  Widget _iconToggle(String elementKey) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Show icon'),
        value: !_hiddenIcons.contains(elementKey),
        onChanged: (v) => _setIconShown(elementKey, v),
      );

  Widget _num(String label, String key) => TextFormField(
        initialValue: _d[key] == null ? '' : '${_d[key]}',
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => _patch(key, double.tryParse(v) ?? 0),
      );
}
