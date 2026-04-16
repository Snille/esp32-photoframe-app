import 'package:flutter_test/flutter_test.dart';

import 'package:esp32_photoframe_app/main.dart';

void main() {
  testWidgets('App renders discovery screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PhotoFrameApp());
    expect(find.text('Connect to PhotoFrame'), findsOneWidget);
  });
}
