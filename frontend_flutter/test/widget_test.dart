import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/main.dart';

void main() {
  testWidgets('App loads and shows inbox title', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Verify app title is shown
    expect(find.text('📬 AI Student Inbox'), findsOneWidget);
  });
}
