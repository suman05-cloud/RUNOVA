import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final themeModeProvider = NotifierProvider<AppearanceController, ThemeMode>(
  AppearanceController.new,
);

class AppearanceController extends Notifier<ThemeMode> {
  static const storageKey = 'runova_appearance';
  final _storage = const FlutterSecureStorage();
  bool _changed = false;
  Future<void> _writes = Future.value();

  @override
  ThemeMode build() {
    unawaited(_restore());
    return ThemeMode.light;
  }

  Future<void> _restore() async {
    try {
      final saved = await _storage.read(key: storageKey);
      if (!ref.mounted || _changed) return;
      state = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.light,
      );
    } catch (_) {
      // Appearance remains available when platform storage is unavailable.
    }
  }

  Future<void> select(ThemeMode mode) async {
    _changed = true;
    state = mode;
    _writes = _writes.then(
      (_) => _storage.write(key: storageKey, value: mode.name),
    );
    try {
      await _writes;
    } catch (_) {
      _writes = Future.value();
    }
  }
}

class AppearanceButton extends ConsumerWidget {
  const AppearanceButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton.filledTonal(
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => ref
          .read(themeModeProvider.notifier)
          .select(dark ? ThemeMode.light : ThemeMode.dark),
      icon: Icon(
        dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 21,
      ),
    );
  }
}
