# ESP32 PhotoFrame App

Cross-platform companion app for [ESP32 PhotoFrame](https://github.com/nickoala/esp32-photoframe) e-paper displays.

## Features

### Device Management
- **mDNS auto-discovery** via `_esp32-pframe._tcp` service type
- **Saved devices** with online status indicators (HTTP ping every 15s)
- **Manual connection** by IP address or `.local` hostname
- Automatic `.local` hostname resolution to IP for reliable connections

### Gallery
- Browse and manage albums on the device
- View image thumbnails with caching
- Multi-select for batch deletion
- Create and delete albums
- Pull-to-refresh with per-device caching for instant load

### Image Processing
Full port of [epaper-image-convert](https://github.com/nickoala/epaper-image-convert) to Dart:
- **Dithering algorithms**: Floyd-Steinberg, Stucki, Burkes, Sierra
- **Color matching**: RGB and LAB (CIE Delta E)
- **Tone mapping**: Contrast and S-curve modes
- **Adjustments**: Exposure, saturation, dynamic range compression
- **Presets**: Balanced, Dynamic, Vivid, Soft, Grayscale
- **Layout modes**: Cover (crop), Fit (letterbox), Custom (drag to pan, pinch to zoom)
- **Live preview** during custom layout adjustments
- **EPDGZ output** at native panel resolution with orientation handling
- Background masking for clean letterbox edges after dithering

### Device Settings
All settings from the webapp:
- WiFi, display orientation/rotation, timezone, NTP server
- Auto-rotate with interval, clock alignment, storage/URL source
- Sleep schedule, deep sleep
- Home Assistant URL
- AI generation API keys (OpenAI, Google Gemini)
- OTA firmware updates with progress tracking

## Building

### Prerequisites
- Flutter SDK 3.11+
- JDK 17 (for Android builds)
- Android SDK with NDK

### Build & Install
```bash
export JAVA_HOME=/path/to/jdk17
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Firmware
The device firmware needs the `_esp32-pframe._tcp` mDNS service registered for auto-discovery. See `mdns_service.c` in the firmware repo.

## Architecture

```
lib/
  main.dart                     # App entry, routing, theme
  models/
    device.dart                 # Device, SystemInfo, BatteryInfo
    config.dart                 # DeviceConfig
    album.dart                  # Album, PhotoInfo
  providers/
    device_provider.dart        # State management, keep-alive, caching
  screens/
    discovery_screen.dart       # Device discovery & connection
    gallery_screen.dart         # Album browser, image grid
    preview_screen.dart         # Image processing editor
    settings_screen.dart        # Device configuration
  services/
    api_client.dart             # REST API client for ESP32
    device_discovery.dart       # mDNS discovery & online ping
    saved_devices.dart          # Persistent device storage
    epaper/
      image_processor.dart      # Dithering, color conversion, EPDGZ
      palettes.dart             # Measured color palettes (Spectra 6)
      presets.dart               # Processing presets
```
