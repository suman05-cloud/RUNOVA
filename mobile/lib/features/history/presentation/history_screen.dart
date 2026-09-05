import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runova/core/theme/runova_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Run history'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.route_rounded, size: 64, color: RunovaColors.primary),
              SizedBox(height: 18),
              Text(
                'No completed runs',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                'Your verified routes, pace, XP, and territory results will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: RunovaColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

