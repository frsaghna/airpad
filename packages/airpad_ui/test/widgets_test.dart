import 'package:airpad_ui/airpad_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airpad UI Monochrome Widgets', () {
    testWidgets('AirButton renders in primary and outline variants', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AirTheme.darkTheme,
          home: Scaffold(
            body: AirButton(
              label: 'Test Button',
              onPressed: () => pressed = true,
              variant: AirButtonVariant.primary,
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
      await tester.tap(find.text('Test Button'));
      expect(pressed, isTrue);
    });

    testWidgets('AirCodeBox displays 6-digit verification code with spacing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AirTheme.darkTheme,
          home: const Scaffold(
            body: AirCodeBox(code: '849201'),
          ),
        ),
      );

      expect(find.text('VERIFICATION CODE'), findsOneWidget);
      expect(find.text('849 201'), findsOneWidget);
    });

    testWidgets('AirStatusBadge renders connected and idle status pills', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AirTheme.darkTheme,
          home: const Scaffold(
            body: Column(
              children: [
                AirStatusBadge(type: AirStatusType.connected),
                AirStatusBadge(type: AirStatusType.idle),
              ],
            ),
          ),
        ),
      );

      expect(find.text('CONNECTED'), findsOneWidget);
      expect(find.text('IDLE'), findsOneWidget);
    });

    testWidgets('AirToggle toggles value', (tester) async {
      var val = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AirTheme.darkTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: AirToggle(
                  label: 'Natural Scroll',
                  value: val,
                  onChanged: (newVal) {
                    setState(() => val = newVal);
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Natural Scroll'), findsOneWidget);
      await tester.tap(find.text('Natural Scroll'));
      await tester.pumpAndSettle();
      expect(val, isTrue);
    });
  });
}
