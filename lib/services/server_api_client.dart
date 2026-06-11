import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_models.dart';

class ServerApiException implements Exception {
  final int statusCode;
  final String body;
  const ServerApiException(this.statusCode, this.body);

  bool get isAuth => statusCode == 401;

  @override
  String toString() => 'ServerApiException($statusCode): $body';
}

/// REST client for the esp32-photoframe-server. Mirrors the endpoints the Vue
/// web UI uses (see the server's webapp/src/api.ts). Native app → no CORS.
class ServerApiClient {
  final String baseUrl;
  final String token;
  final http.Client _client;

  ServerApiClient({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _kUrl = 'server_base_url';
  static const _kToken = 'server_token';

  void dispose() => _client.close();

  static String normalizeBaseUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Map<String, String> get _authHeaders => {'Authorization': 'Bearer $token'};
  Map<String, String> get _jsonHeaders =>
      {..._authHeaders, 'Content-Type': 'application/json'};

  /// Headers needed to fetch a /image/* preview as an authenticated image
  /// (Image.network supports a headers map).
  Map<String, String> imageHeaders(String host) =>
      {..._authHeaders, 'X-Hostname': host};

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  dynamic _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ServerApiException(res.statusCode, res.body);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  // --- auth + persistence ---

  static Future<String> login(
      String baseUrl, String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw ServerApiException(res.statusCode, res.body);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ServerApiException(200, 'no token in login response');
    }
    return token;
  }

  static Future<ServerConnection?> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_kUrl);
    final token = prefs.getString(_kToken);
    if (url == null || token == null || url.isEmpty || token.isEmpty) {
      return null;
    }
    return ServerConnection(baseUrl: url, token: token);
  }

  static Future<void> saveConnection(ServerConnection c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUrl, c.baseUrl);
    await prefs.setString(_kToken, c.token);
  }

  static Future<void> clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUrl);
    await prefs.remove(_kToken);
  }

  // --- devices + content ---

  Future<List<ServerDevice>> listDevices() async {
    final data = _decode(await _client.get(_u('/api/devices'), headers: _authHeaders));
    if (data is! List) return [];
    return data
        .map((e) => ServerDevice(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<BatteryEstimate> getBatteryEstimate(int id) async {
    final data = _decode(
        await _client.get(_u('/api/devices/$id/battery'), headers: _authHeaders));
    if (data is Map) {
      return BatteryEstimate.fromJson(Map<String, dynamic>.from(data));
    }
    return BatteryEstimate.empty;
  }

  Future<List<String>> listSources() async {
    final data = _decode(await _client.get(_u('/api/sources'), headers: _authHeaders));
    if (data is Map && data['sources'] is List) {
      return (data['sources'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<List<ImmichAlbum>> listImmichAlbums() async {
    final data =
        _decode(await _client.get(_u('/api/immich/albums'), headers: _authHeaders));
    if (data is! List) return [];
    return data
        .map((e) => ImmichAlbum.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Change the source the frame pulls. Sent via the merging config endpoint so
  /// only image_url is touched; the device-facing base in the existing
  /// image_url is preserved (only the trailing /image/<source> segment swaps).
  Future<void> setDeviceSource(ServerDevice device, String source) async {
    final current = device.imageUrl;
    String newUrl;
    const marker = '/image/';
    final idx = current.indexOf(marker);
    if (idx >= 0) {
      newUrl = '${current.substring(0, idx)}$marker$source';
    } else {
      // No prior server source: fall back to the app's server base. Works when
      // the frame can reach the same host the app connected to (typical LAN).
      newUrl = '$baseUrl/image/$source';
    }
    _decode(await _client.put(
      _u('/api/devices/${device.id}/config'),
      headers: _jsonHeaders,
      body: jsonEncode({'image_url': newUrl, 'rotation_mode': 'url'}),
    ));
  }

  /// Set the per-frame Immich album filter. Round-trips the full device map so
  /// the server's non-pointer bind doesn't zero other fields.
  Future<ServerDevice> setDeviceImmichAlbums(
      ServerDevice device, List<String> albumIds) async {
    final body = device.rawWith('immich_album_ids', albumIds.join(','));
    final data = _decode(await _client.put(
      _u('/api/devices/${device.id}'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    ));
    if (data is Map) return ServerDevice(Map<String, dynamic>.from(data));
    return ServerDevice(body);
  }

  /// Full PUT of a device. Pass the device's own raw map with the changed
  /// field(s) applied so no server-owned field is zeroed (the server binds
  /// non-pointer fields). Returns the server's updated device.
  Future<ServerDevice> updateDeviceRaw(int id, Map<String, dynamic> raw) async {
    final data = _decode(await _client.put(
      _u('/api/devices/$id'),
      headers: _jsonHeaders,
      body: jsonEncode(raw),
    ));
    if (data is Map) return ServerDevice(Map<String, dynamic>.from(data));
    return ServerDevice(raw);
  }

  /// Pull live state (dimensions/board/config/battery) from the frame.
  /// Requires the frame to be online.
  Future<ServerDevice> refreshDevice(int id) async {
    final data = _decode(
        await _client.post(_u('/api/devices/$id/refresh'), headers: _authHeaders));
    return ServerDevice(Map<String, dynamic>.from(data as Map));
  }

  /// URL for a non-mutating preview of what the frame shows next. Fetch with
  /// [imageHeaders] for the device host. [cacheBust] forces a fresh render.
  String previewUrl(String source, {int? cacheBust}) {
    final q = <String, String>{
      'preview': '1',
      if (cacheBust != null) 't': '$cacheBust',
    };
    return _u('/image/$source', q).toString();
  }
}
