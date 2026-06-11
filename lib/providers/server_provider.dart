import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/server_models.dart';
import '../services/server_api_client.dart';

/// State for the app's "server mode": a connection to a photoframe-server plus
/// the list of frames it manages. The existing direct-to-frame mode is
/// untouched and remains usable as a "local only" fallback.
class ServerProvider extends ChangeNotifier {
  ServerApiClient? _client;
  ServerConnection? _connection;

  List<ServerDevice> _devices = [];
  final Map<int, BatteryEstimate> _batteries = {};
  // Bumped whenever a device changes so cached previews (keyed by URL) reload.
  final Map<int, int> _previewVersion = {};
  List<String> _sources = [];
  List<ImmichAlbum> _albums = [];

  bool _loading = false;
  String? _error;

  bool get isConnected => _client != null;
  String? get baseUrl => _connection?.baseUrl;
  ServerApiClient? get client => _client;
  List<ServerDevice> get devices => List.unmodifiable(_devices);
  List<String> get sources => List.unmodifiable(_sources);
  List<ImmichAlbum> get albums => List.unmodifiable(_albums);
  bool get loading => _loading;
  String? get error => _error;

  BatteryEstimate batteryFor(int deviceId) =>
      _batteries[deviceId] ?? BatteryEstimate.empty;

  /// A counter that changes whenever the device is edited — use as a preview
  /// cache-buster so list thumbnails reload after source/album/overlay changes.
  int previewVersion(int deviceId) => _previewVersion[deviceId] ?? 0;

  ServerDevice? deviceById(int id) {
    for (final d in _devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Restore a previously-saved connection (called on app start). Returns true
  /// if a connection was restored.
  Future<bool> restore() async {
    final saved = await ServerApiClient.loadSaved();
    if (saved == null) return false;
    _connection = saved;
    _client = ServerApiClient(baseUrl: saved.baseUrl, token: saved.token);
    notifyListeners();
    await loadDevices();
    return true;
  }

  /// Log in to a server and persist the connection. Returns null on success or
  /// an error message on failure.
  Future<String?> connect(String rawUrl, String username, String password) async {
    final base = ServerApiClient.normalizeBaseUrl(rawUrl);
    if (base.isEmpty) return 'Enter a server address';
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final token = await ServerApiClient.login(base, username, password);
      final conn = ServerConnection(baseUrl: base, token: token);
      await ServerApiClient.saveConnection(conn);
      _client?.dispose();
      _connection = conn;
      _client = ServerApiClient(baseUrl: base, token: token);
      _loading = false;
      notifyListeners();
      await loadDevices();
      return null;
    } on ServerApiException catch (e) {
      _loading = false;
      notifyListeners();
      if (e.statusCode == 401) return 'Wrong username or password';
      return 'Login failed (${e.statusCode})';
    } catch (e) {
      _loading = false;
      notifyListeners();
      return 'Could not reach server: $e';
    }
  }

  Future<void> disconnect() async {
    await ServerApiClient.clearSaved();
    _client?.dispose();
    _client = null;
    _connection = null;
    _devices = [];
    _batteries.clear();
    _sources = [];
    _albums = [];
    _error = null;
    notifyListeners();
  }

  Future<void> loadDevices() async {
    if (_client == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _devices = await _client!.listDevices();
      // Sources + Immich albums are best-effort (immich may be unconfigured).
      try {
        _sources = await _client!.listSources();
      } catch (_) {}
      try {
        _albums = await _client!.listImmichAlbums();
      } catch (_) {}
      _loading = false;
      notifyListeners();
      // Fetch battery estimates in the background.
      for (final d in _devices) {
        _loadBattery(d.id);
      }
    } on ServerApiException catch (e) {
      _loading = false;
      if (e.isAuth) {
        await disconnect();
        _error = 'Session expired — please log in again';
      } else {
        _error = 'Failed to load devices (${e.statusCode})';
      }
      notifyListeners();
    } catch (e) {
      _loading = false;
      _error = 'Failed to load devices: $e';
      notifyListeners();
    }
  }

  Future<void> _loadBattery(int id) async {
    if (_client == null) return;
    try {
      _batteries[id] = await _client!.getBatteryEstimate(id);
      notifyListeners();
    } catch (_) {
      // Non-fatal: leave the estimate empty.
    }
  }

  void _replaceDevice(ServerDevice updated) {
    final i = _devices.indexWhere((d) => d.id == updated.id);
    if (i >= 0) {
      _devices[i] = updated;
      _previewVersion[updated.id] = previewVersion(updated.id) + 1;
      notifyListeners();
    }
  }

  /// Change a frame's source. Returns null on success or an error message.
  Future<String?> changeSource(ServerDevice device, String source) async {
    if (_client == null) return 'Not connected';
    try {
      await _client!.setDeviceSource(device, source);
      // Reflect the change locally by patching the cached device_config.
      final cfg = Map<String, dynamic>.from(device.deviceConfig);
      final current = device.imageUrl;
      const marker = '/image/';
      final idx = current.indexOf(marker);
      cfg['image_url'] = idx >= 0
          ? '${current.substring(0, idx)}$marker$source'
          : '${_connection!.baseUrl}/image/$source';
      _replaceDevice(
          ServerDevice(device.rawWith('device_config', jsonEncode(cfg))));
      return null;
    } on ServerApiException catch (e) {
      return 'Failed to change source (${e.statusCode})';
    } catch (e) {
      return 'Failed to change source: $e';
    }
  }

  /// Change a frame's Immich album filter. Returns null on success.
  Future<String?> changeAlbums(ServerDevice device, List<String> albumIds) async {
    if (_client == null) return 'Not connected';
    try {
      final updated = await _client!.setDeviceImmichAlbums(device, albumIds);
      _replaceDevice(updated);
      return null;
    } on ServerApiException catch (e) {
      return 'Failed to change albums (${e.statusCode})';
    } catch (e) {
      return 'Failed to change albums: $e';
    }
  }

  /// Persist a full device map (raw model JSON with edits applied) via the
  /// server's full-device PUT. Used by the overlay editor. Returns null on
  /// success or an error message.
  Future<String?> saveDeviceRaw(int id, Map<String, dynamic> raw) async {
    if (_client == null) return 'Not connected';
    try {
      final updated = await _client!.updateDeviceRaw(id, raw);
      _replaceDevice(updated);
      return null;
    } on ServerApiException catch (e) {
      if (e.isAuth) {
        await disconnect();
        return 'Session expired — please log in again';
      }
      return 'Save failed (${e.statusCode})';
    } catch (e) {
      return 'Save failed: $e';
    }
  }

  /// Pull live state from the frame (needs it online). Returns null on success
  /// or an error message (e.g. the frame is asleep / unreachable).
  Future<String?> refreshDevice(ServerDevice device) async {
    if (_client == null) return 'Not connected';
    try {
      final updated = await _client!.refreshDevice(device.id);
      _replaceDevice(updated);
      await _loadBattery(device.id);
      return null;
    } on ServerApiException catch (e) {
      if (e.statusCode == 503) return 'Frame is offline (asleep or unreachable)';
      return 'Refresh failed (${e.statusCode})';
    } catch (e) {
      return 'Refresh failed: $e';
    }
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }
}
