import 'package:flutter_test/flutter_test.dart';

import 'package:esp32_photoframe_app/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PhotoFrameApp());
    await tester.pump();
    expect(find.text('ESP Frame'), findsOneWidget);
    // Drain the splash screen timer
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
