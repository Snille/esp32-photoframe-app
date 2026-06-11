import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Colour families shared with the web UIs (server + frame). Seed colours match
/// the Vuetify themes' primary colours so the whole system looks consistent.
enum AppPalette { terracotta, ocean, forest }

Color _seedFor(AppPalette p) {
  switch (p) {
    case AppPalette.terracotta:
      return const Color(0xFFCE9160);
    case AppPalette.ocean:
      return const Color(0xFF2F6398);
    case AppPalette.forest:
      return const Color(0xFF2F9852);
  }
}

/// A named theme = a colour family + a light/dark mode. Keys/labels mirror the
/// web UIs' theme menu (terracotta|ocean|forest × Light|Dark).
class AppTheme {
  final String key;
  final String label;
  final AppPalette palette;
  final bool dark;

  const AppTheme(this.key, this.label, this.palette, this.dark);
}

const List<AppTheme> appThemes = [
  AppTheme('terracotta', 'Terracotta (Light)', AppPalette.terracotta, false),
  AppTheme('terracottaDark', 'Terracotta (Dark)', AppPalette.terracotta, true),
  AppTheme('ocean', 'Ocean (Light)', AppPalette.ocean, false),
  AppTheme('oceanDark', 'Ocean (Dark)', AppPalette.ocean, true),
  AppTheme('forest', 'Forest (Light)', AppPalette.forest, false),
  AppTheme('forestDark', 'Forest (Dark)', AppPalette.forest, true),
];

/// Holds the selected theme and persists it (same `pf_theme` key the web UIs
/// use in localStorage — a separate store, but a consistent convention).
class ThemeProvider extends ChangeNotifier {
  static const _storageKey = 'pf_theme';
  String _key = 'terracotta';

  String get key => _key;

  AppTheme get current =>
      appThemes.firstWhere((t) => t.key == _key, orElse: () => appThemes.first);

  ThemeMode get mode => current.dark ? ThemeMode.dark : ThemeMode.light;

  ThemeData get light => _build(Brightness.light);
  ThemeData get dark => _build(Brightness.dark);

  ThemeData _build(Brightness b) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedFor(current.palette),
          brightness: b,
        ),
        useMaterial3: true,
      );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null && appThemes.any((t) => t.key == saved)) {
      _key = saved;
      notifyListeners();
    }
  }

  Future<void> setTheme(String key) async {
    if (key == _key || !appThemes.any((t) => t.key == key)) return;
    _key = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, key);
  }
}
