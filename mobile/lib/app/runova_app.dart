import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runova/app/router.dart';
import 'package:runova/core/theme/runova_theme.dart';
import 'package:runova/core/theme/appearance_controller.dart';
import 'package:runova/features/run/data/run_sync.dart';

class RunovaApp extends ConsumerWidget {
  const RunovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(runSyncProvider);
    return MaterialApp.router(
      title: 'Runova',
      debugShowCheckedModeBanner: false,
      theme: RunovaTheme.light,
      darkTheme: RunovaTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(runovaRouterProvider),
    );
  }
}
