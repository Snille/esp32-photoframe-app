import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

/// App-bar palette menu mirroring the web UIs' theme switcher.
class ThemeMenu extends StatelessWidget {
  const ThemeMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return PopupMenuButton<String>(
      icon: const Icon(Icons.palette_outlined),
      tooltip: 'Theme',
      onSelected: theme.setTheme,
      itemBuilder: (_) => appThemes
          .map(
            (t) => CheckedPopupMenuItem<String>(
              value: t.key,
              checked: t.key == theme.key,
              child: Text(t.label),
            ),
          )
          .toList(),
    );
  }
}
