import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';
import 'package:runova/features/history/data/run_history_repository.dart';
import 'package:runova/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:runova/features/profile/presentation/profile_screen.dart';
import 'package:runova/features/run/presentation/run_controller.dart';

class SyncState {
  const SyncState({this.pending = 0, this.busy = false, this.error});
  final int pending;
  final bool busy;
  final String? error;
}

final runSyncProvider = NotifierProvider<RunSync, SyncState>(RunSync.new);

class RunSync extends Notifier<SyncState> {
  bool _busy = false;
  bool _disposed = false;
  @override
  SyncState build() {
    final connection = Connectivity().onConnectivityChanged.listen((
      connections,
    ) {
      if (!connections.contains(ConnectivityResult.none)) unawaited(sync());
    });
    final retry = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(sync()),
    );
    ref.listen(authControllerProvider, (before, after) {
      if (after.value != null) unawaited(sync());
    });
    ref.onDispose(() {
      _disposed = true;
      unawaited(connection.cancel());
      retry.cancel();
    });
    Future.microtask(sync);
    return const SyncState();
  }

  Future<void> sync() async {
    final user = ref.read(authControllerProvider).value;
    if (_busy || _disposed || user == null) return;
    _busy = true;
    var count = state.pending;
    String? error;
    var changed = false;
    try {
      final db = ref.read(localDatabaseProvider);
      final pending = await db.pendingRuns(user.id);
      count = pending.length;
      if (!_disposed) state = SyncState(pending: count, busy: true);
      for (final row in pending) {
        if (_disposed ||
            ref.read(authControllerProvider).value?.id != user.id) {
          break;
        }
        try {
          await ref.read(runRepositoryProvider).syncRun(row);
          count--;
          changed = true;
        } on DioException catch (failure) {
          if (failure.response?.statusCode == 401) break;
          error = 'Sync is waiting for a connection or server response.';
          break;
        }
      }
      if (changed && !_disposed) {
        ref.invalidate(runHistoryProvider);
        ref.invalidate(progressionProvider);
        ref.invalidate(leaderboardProvider);
      }
    } catch (_) {
      error = 'Could not sync stored runs. They remain on this device.';
    } finally {
      _busy = false;
      if (!_disposed) state = SyncState(pending: count, error: error);
    }
  }
}
