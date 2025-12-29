// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventory_system/firebase_options.dart';

import 'package:inventory_system/main.dart';

void main() {
  testWidgets('App shows login screen when not authenticated', (WidgetTester tester) async {
    // Build our app with a fake auth state stream and wait for streams to settle.
    await tester.pumpWidget(const InventoryApp(authStateChanges: Stream.empty()));
    await tester.pumpAndSettle();

    // Verify that the login form is shown (check for email label).
    expect(find.text('อีเมล'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
  });
}
