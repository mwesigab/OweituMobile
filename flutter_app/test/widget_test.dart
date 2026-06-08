import 'package:flutter_test/flutter_test.dart';

import 'package:oweitu_delivery/main.dart';

void main() {
  testWidgets('shows the Oweitu login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const OweituApp());

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Use demo@oweitu.com / 123456'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('can log in and open the order menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OweituApp());

    await tester.tap(find.text('Login'));
    await tester.pump();

    expect(find.text('HOME'), findsWidgets);
    expect(find.text("CJ's!!"), findsOneWidget);

    await tester.tap(find.text('ORDER'));
    await tester.pump();

    expect(find.text('MENU'), findsOneWidget);
    expect(find.text('BIG ON BREAKFAST'), findsOneWidget);
    expect(find.text('DECADENT DESSERTS'), findsOneWidget);
  });
}
