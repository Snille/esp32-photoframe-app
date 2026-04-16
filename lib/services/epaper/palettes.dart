// E-paper display color palettes.
//
// Each palette contains a pair:
// - theoretical: Pure RGB values for device output (what gets sent to the display)
// - perceived: Actual RGB values as measured on screen (for dithering calculations)

class PaletteColor {
  final int r, g, b;
  const PaletteColor(this.r, this.g, this.b);
}

class Palette {
  final PaletteColor black;
  final PaletteColor white;
  final PaletteColor yellow;
  final PaletteColor red;
  final PaletteColor blue;
  final PaletteColor green;

  const Palette({
    required this.black,
    required this.white,
    required this.yellow,
    required this.red,
    required this.blue,
    required this.green,
  });

  PaletteColor? operator [](String name) {
    switch (name) {
      case 'black':
        return black;
      case 'white':
        return white;
      case 'yellow':
        return yellow;
      case 'red':
        return red;
      case 'blue':
        return blue;
      case 'green':
        return green;
      default:
        return null;
    }
  }

  /// Convert to array format: [black, white, yellow, red, reserved, blue, green]
  /// Index 4 is reserved (not used).
  List<List<int>> toArray() {
    return [
      [black.r, black.g, black.b],
      [white.r, white.g, white.b],
      [yellow.r, yellow.g, yellow.b],
      [red.r, red.g, red.b],
      [0, 0, 0], // Reserved (index 4)
      [blue.r, blue.g, blue.b],
      [green.r, green.g, green.b],
    ];
  }
}

class PalettePair {
  final Palette theoretical;
  final Palette perceived;
  const PalettePair({required this.theoretical, required this.perceived});
}

/// Spectra 6 (ACeP) — default palette for 6-color e-paper displays.
const spectra6 = PalettePair(
  theoretical: Palette(
    black: PaletteColor(0, 0, 0),
    white: PaletteColor(255, 255, 255),
    yellow: PaletteColor(255, 255, 0),
    red: PaletteColor(255, 0, 0),
    blue: PaletteColor(0, 0, 255),
    green: PaletteColor(0, 255, 0),
  ),
  perceived: Palette(
    black: PaletteColor(2, 2, 2),
    white: PaletteColor(190, 200, 200),
    yellow: PaletteColor(205, 202, 0),
    red: PaletteColor(135, 19, 0),
    blue: PaletteColor(5, 64, 158),
    green: PaletteColor(39, 102, 60),
  ),
);

const defaultPalette = spectra6;
