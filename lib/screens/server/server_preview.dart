import 'package:flutter/material.dart';

import '../../services/server_api_client.dart';

/// Renders the server-side preview of what a frame shows next (non-mutating
/// `/image/<source>?preview=1`). Falls back to a placeholder when the source is
/// unknown or the render fails.
class ServerPreview extends StatelessWidget {
  final ServerApiClient? client;
  final String host;
  final String? source;
  final BoxFit fit;

  /// Bump to force a fresh render (cache-buster). Null = let the image cache.
  final int? cacheBust;

  /// Clockwise quarter-turns to apply so the panel-native preview shows in the
  /// frame's viewing orientation (see ServerDevice.previewQuarterTurns).
  final int quarterTurns;

  /// Battery percentage to report so the server renders the battery badge (the
  /// server only draws it when a reading is present — the frame sends one on a
  /// real fetch, the app must send one for the preview). Null = don't send.
  final int? batteryPercent;

  const ServerPreview({
    super.key,
    required this.client,
    required this.host,
    required this.source,
    this.fit = BoxFit.cover,
    this.cacheBust,
    this.quarterTurns = 0,
    this.batteryPercent,
  });

  @override
  Widget build(BuildContext context) {
    final c = client;
    final s = source;
    if (c == null || s == null) {
      return _placeholder(
        context,
        icon: Icons.image_not_supported_outlined,
        text: s == null ? 'No server source set' : 'Not connected',
      );
    }
    final headers = {...c.imageHeaders(host)};
    if (batteryPercent != null) {
      headers['X-Battery-Percentage'] = '$batteryPercent';
    }
    final image = Image.network(
      c.previewUrl(s, cacheBust: cacheBust),
      headers: headers,
      fit: fit,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder(
          context,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
      errorBuilder: (context, error, stack) => _placeholder(
        context,
        icon: Icons.broken_image_outlined,
        text: 'Preview unavailable',
      ),
    );
    if (quarterTurns == 0) return image;
    return RotatedBox(quarterTurns: quarterTurns, child: image);
  }

  Widget _placeholder(BuildContext context,
      {IconData? icon, String? text, Widget? child}) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: child ??
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.outline),
              if (text != null) ...[
                const SizedBox(height: 6),
                Text(text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
              ],
            ],
          ),
    );
  }
}
