import 'package:flutter_test/flutter_test.dart';

import 'package:clowndeck/main.dart';

void main() {
  testWidgets('Dashboard tampil', (WidgetTester tester) async {
    await tester.pumpWidget(const ClownDeckApp());
    await tester.pump();

    expect(find.text('CLOWNDECK'), findsOneWidget);
    expect(find.text('BELUM ADA FITUR'), findsOneWidget);
  });
}
