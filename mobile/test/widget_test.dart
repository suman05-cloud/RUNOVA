import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runova/app/runova_app.dart';

void main() {
  testWidgets('shows the Runova development login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RunovaApp()));
    await tester.pumpAndSettle();

    expect(find.text('RUNOVA'), findsOneWidget);
    expect(find.text('Create your runner profile'), findsOneWidget);
    expect(find.byKey(const Key('direct-login-button')), findsOneWidget);
  });
}
