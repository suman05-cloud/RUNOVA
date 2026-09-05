import 'package:flutter/material.dart';
import 'package:runova/app/router.dart';
import 'package:runova/core/theme/runova_theme.dart';

class RunovaApp extends StatelessWidget {
  const RunovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Runova',
      debugShowCheckedModeBanner: false,
      theme: RunovaTheme.dark,
      routerConfig: runovaRouter,
    );
  }
}

