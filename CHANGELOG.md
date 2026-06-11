# Changelog

All notable changes to the ESP Frame companion app.

The build version is derived from the git tag at release time (see
`pubspec.yaml`); the headings below track the notable changes per version.

## v0.1.0 — 2026-06-11

First release of **server mode** — the app can now act as a mobile client of
the [esp32-photoframe-server](https://github.com/Snille/esp32-photoframe-server),
making all the rich, board-agnostic features available from the phone even
while a frame is asleep. The original direct-to-frame mode is unchanged and
remains usable as a local-only fallback (e.g. for a frame given to someone
without a server).

### Added

- **Server mode**: connect to a photoframe-server (address + login → bearer
  token, persisted). A `dns` action on the local devices screen and an
  auto-route on startup when a connection is saved.
- **Frame dashboard**: every frame the server manages, each with a live
  **server-rendered preview** of what it shows next (works while the frame is
  asleep), battery status (percent + trend), and source.
- **Per-frame controls** (device detail): live preview, change **image
  source**, per-frame **Immich album** filter, and a Refresh action. Source and
  album changes apply on the frame's next pull.
- **Full overlay editor**: mirrors the web UI's overlay tab with a real
  server-rendered preview that refreshes after each change — per-element
  show toggles and placement (6 corners + 2 full-width bands), battery
  style/text-side/rotation/icon-size, font/weight/text-size, name
  format/age/length, location & description length, per-chip show-icon, and
  layout/display-mode. Auto-saves (debounced).
- **Theme picker**: the same six themes as the rest of the system
  (Terracotta / Ocean / Forest × Light / Dark), with seed colours matching the
  web UIs, selectable from a palette menu and persisted.
- Server-hosted install: download the app straight from the server at `/app`.

### Fixed

- Preview now shows upright: the panel-native bitmap (e.g. the 4" FireBeetle is
  natively portrait although mounted landscape) is rotated to the frame's
  viewing orientation.
- Frame-list thumbnails refresh after edits (per-device preview cache-buster)
  instead of showing a stale cached image.
- Edge overlay chips (e.g. battery in a corner) are no longer clipped by the
  rounded preview corners — previews sit on a small matte and use `contain`.
- The battery badge now renders in the preview (the app sends the battery
  reading the server needs to draw it).
