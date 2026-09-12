import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';

class AppPreferences {
  const AppPreferences({
    this.notifications = true,
    this.runUpdates = true,
    this.syncUpdates = true,
    this.readIds = const {},
  });

  final bool notifications;
  final bool runUpdates;
  final bool syncUpdates;
  final Set<String> readIds;

  AppPreferences copyWith({
    bool? notifications,
    bool? runUpdates,
    bool? syncUpdates,
    Set<String>? readIds,
  }) => AppPreferences(
    notifications: notifications ?? this.notifications,
    runUpdates: runUpdates ?? this.runUpdates,
    syncUpdates: syncUpdates ?? this.syncUpdates,
    readIds: readIds ?? this.readIds,
  );

  factory AppPreferences.fromJson(Map<String, dynamic> json) => AppPreferences(
    notifications: json['notifications'] as bool? ?? true,
    runUpdates: json['runUpdates'] as bool? ?? true,
    syncUpdates: json['syncUpdates'] as bool? ?? true,
    readIds: (json['readIds'] as List<dynamic>? ?? []).cast<String>().toSet(),
  );

  Map<String, dynamic> toJson() => {
    'notifications': notifications,
    'runUpdates': runUpdates,
    'syncUpdates': syncUpdates,
    'readIds': readIds.toList(),
  };
}

final preferencesProvider =
    AsyncNotifierProvider<PreferencesController, AppPreferences>(
      PreferencesController.new,
    );

class PreferencesController extends AsyncNotifier<AppPreferences> {
  final _storage = const FlutterSecureStorage();
  Future<void> _writes = Future.value();

  String? get _userId => ref.read(authControllerProvider).value?.id;
  static String storageKey(String id) => 'runova_preferences_$id';

  @override
  Future<AppPreferences> build() async {
    final id = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    if (id == null) return const AppPreferences();
    final saved = await _storage.read(key: storageKey(id));
    return saved == null
        ? const AppPreferences()
        : AppPreferences.fromJson(jsonDecode(saved) as Map<String, dynamic>);
  }

  Future<void> save(AppPreferences Function(AppPreferences) change) {
    final id = _userId;
    final operation = _writes.then((_) async {
      if (!ref.mounted || id == null || id != _userId) return;
      final current = state.value;
      if (current == null || state.isLoading || state.hasError) {
        throw StateError('Preferences are not available yet.');
      }
      final next = change(current);
      await _storage.write(
        key: storageKey(id),
        value: jsonEncode(next.toJson()),
      );
      if (ref.mounted && id == _userId) state = AsyncData(next);
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> markRead(Iterable<String> ids) => save(
    (current) => current.copyWith(readIds: {...current.readIds, ...ids}),
  );
}
