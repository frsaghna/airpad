import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/main.dart';

void main() {
  testWidgets('AirpadDesktopApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AirpadDesktopApp());

    // Verify title and monochrome elements render
    expect(find.text('AIRPAD'), findsOneWidget);
    expect(find.text('RECEIVER'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
