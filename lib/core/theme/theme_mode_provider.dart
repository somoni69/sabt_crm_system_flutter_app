import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dependencies.dart';

/// The user's theme choice, persisted in the prefs box.
///
/// Defaults to [ThemeMode.dark]: Sabt's brand surface is the dark
/// "liquid graphite", and existing users must not wake up to a
/// different-looking app because their phone is set to light. The
/// picker in Settings offers dark / light / system.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _prefsKey = 'ui.themeMode';

  @override
  ThemeMode build() {
    final prefs = ref.watch(dependenciesProvider).prefs;
    return switch (prefs.get(_prefsKey) as String?) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(dependenciesProvider).prefs;
    await prefs.put(_prefsKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    });
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
