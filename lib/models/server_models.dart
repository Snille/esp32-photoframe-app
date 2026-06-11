import 'dart:convert';

/// A saved connection to a photoframe-server instance.
class ServerConnection {
  final String baseUrl; // normalized: scheme included, no trailing slash
  final String token; // JWT bearer

  const ServerConnection({required this.baseUrl, required this.token});
}

/// Battery drain estimate for a server-managed frame (mirrors the server's
/// BatteryEstimate). Built from the X-Battery-Percentage readings the frame
/// reports on every image fetch — last_sampled_at doubles as "last seen".
class BatteryEstimate {
  final bool hasData;
  final int currentPercent;
  final int currentVoltageMv;
  final double drainPerDay;
  final double daysRemaining;
  final String trend; // discharging | charging | stable | insufficient
  final String basis; // voltage | percent
  final int sampleCount;
  final DateTime? lastSampledAt;

  const BatteryEstimate({
    required this.hasData,
    required this.currentPercent,
    required this.currentVoltageMv,
    required this.drainPerDay,
    required this.daysRemaining,
    required this.trend,
    required this.basis,
    required this.sampleCount,
    required this.lastSampledAt,
  });

  static const empty = BatteryEstimate(
    hasData: false,
    currentPercent: 0,
    currentVoltageMv: 0,
    drainPerDay: 0,
    daysRemaining: 0,
    trend: 'insufficient',
    basis: 'percent',
    sampleCount: 0,
    lastSampledAt: null,
  );

  factory BatteryEstimate.fromJson(Map<String, dynamic> j) {
    DateTime? ts;
    final raw = j['last_sampled_at'];
    if (raw is String && raw.isNotEmpty) {
      final p = DateTime.tryParse(raw);
      // The server emits Go's zero time for "never" — treat that as null.
      if (p != null && p.year > 2000) ts = p;
    }
    return BatteryEstimate(
      hasData: j['has_data'] as bool? ?? false,
      currentPercent: (j['current_percent'] as num?)?.toInt() ?? 0,
      currentVoltageMv: (j['current_voltage_mv'] as num?)?.toInt() ?? 0,
      drainPerDay: (j['drain_per_day'] as num?)?.toDouble() ?? 0,
      daysRemaining: (j['days_remaining'] as num?)?.toDouble() ?? 0,
      trend: j['trend'] as String? ?? 'insufficient',
      basis: j['basis'] as String? ?? 'percent',
      sampleCount: (j['sample_count'] as num?)?.toInt() ?? 0,
      lastSampledAt: ts,
    );
  }
}

/// An Immich album (id + display name).
class ImmichAlbum {
  final String id;
  final String name;
  final int assetCount;

  const ImmichAlbum({required this.id, required this.name, this.assetCount = 0});

  factory ImmichAlbum.fromJson(Map<String, dynamic> j) => ImmichAlbum(
        id: j['id'] as String? ?? '',
        name: j['albumName'] as String? ?? '',
        assetCount: (j['assetCount'] as num?)?.toInt() ?? 0,
      );
}

/// A device as the server sees it. Wraps the raw JSON map so a full
/// `PUT /api/devices/:id` can be round-tripped without dropping any
/// server-owned field the app doesn't explicitly model (the server's update
/// handler binds non-pointer fields, so a partial PUT would zero them).
class ServerDevice {
  final Map<String, dynamic> raw;

  ServerDevice(this.raw);

  int get id => (raw['id'] as num?)?.toInt() ?? 0;
  String get name => raw['name'] as String? ?? '';
  String get host => raw['host'] as String? ?? '';
  String get boardName => raw['board_name'] as String? ?? '';
  int get width => (raw['width'] as num?)?.toInt() ?? 0;
  int get height => (raw['height'] as num?)?.toInt() ?? 0;
  String get orientation => raw['orientation'] as String? ?? '';
  String get displayOrder => raw['display_order'] as String? ?? '';
  String get immichAlbumIds => raw['immich_album_ids'] as String? ?? '';

  List<String> get immichAlbumIdList => immichAlbumIds
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// device_config is stored as a JSON string blob on the device row.
  Map<String, dynamic> get deviceConfig {
    final s = raw['device_config'];
    if (s is String && s.isNotEmpty) {
      try {
        final m = jsonDecode(s);
        if (m is Map<String, dynamic>) return m;
      } catch (_) {}
    }
    return const {};
  }

  String get imageUrl => deviceConfig['image_url'] as String? ?? '';

  /// Source name parsed from the image_url tail (".../image/<source>"), or null
  /// if the frame isn't configured to pull a named server source.
  String? get source {
    final url = imageUrl;
    const marker = '/image/';
    final idx = url.indexOf(marker);
    if (idx < 0) return null;
    var tail = url.substring(idx + marker.length);
    final q = tail.indexOf('?');
    if (q >= 0) tail = tail.substring(0, q);
    final slash = tail.indexOf('/');
    if (slash >= 0) tail = tail.substring(0, slash);
    return tail.isEmpty ? null : tail;
  }

  /// True when the panel's native pixels are taller than wide (e.g. the
  /// FireBeetle 4" is natively 400×600 portrait even though mounted landscape).
  bool get _nativePortrait => height > 0 && width > 0 && height > width;

  /// How the frame is actually viewed (its mounting orientation). Falls back to
  /// the native pixel orientation when the device didn't report one.
  bool get viewedPortrait {
    final o = orientation.toLowerCase();
    if (o == 'portrait') return true;
    if (o == 'landscape') return false;
    return _nativePortrait;
  }

  /// Aspect ratio for displaying the preview in the app (viewing orientation).
  double get viewAspectRatio => viewedPortrait ? 2 / 3 : 3 / 2;

  /// The server rotates the composed image into the panel's native layout
  /// (logical→native is a 90° CW turn when the two orientations differ), so the
  /// raw preview looks sideways on a phone. Turn it back for display: 3 CW
  /// quarter-turns (= 90° CCW) when native pixels and viewing orientation
  /// disagree, else none.
  int get previewQuarterTurns =>
      (width != 0 && height != 0 && _nativePortrait != viewedPortrait) ? 3 : 0;

  /// Returns a copy of the raw map with [key] set to [value] — for building a
  /// safe full-device PUT body.
  Map<String, dynamic> rawWith(String key, dynamic value) {
    final m = Map<String, dynamic>.from(raw);
    m[key] = value;
    return m;
  }
}
