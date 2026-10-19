import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/src/services/mobile_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AirpadMobileApp renders and shows monochrome elements', (WidgetTester tester) async {
    final services = MobileServices();
    await tester.pumpWidget(AirpadMobileApp(services: services));

    // The app starts by showing AIRPAD loading state
    expect(find.text('AIRPAD'), findsWidgets);

    // Verify monochrome: background is black
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, equals(const Color(0xFF000000)));
  });
}
