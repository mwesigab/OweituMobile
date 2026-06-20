import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oweitu_delivery/main.dart';

void main() {
  testWidgets('opens home for guest users', (WidgetTester tester) async {
    await tester.pumpWidget(const OweituApp());

    expect(find.text('HOME'), findsWidgets);
    expect(find.text('View Menu'), findsOneWidget);
    expect(find.text('SIGN IN'), findsNothing);
  });

  testWidgets('guest users can open the menu', (WidgetTester tester) async {
    await tester.pumpWidget(const OweituApp());

    await tester.tap(find.text('View Menu'));
    await tester.pumpAndSettle();

    expect(find.text('MENU'), findsWidgets);
    expect(find.text('SNACKS & MAINS'), findsOneWidget);
    expect(find.text('BIG BREAKFAST'), findsOneWidget);
  });

  testWidgets('home popular picks open the selected menu item', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OweituApp());

    await tester.tap(find.text('Chips, 2 Pcs of Chicken and a Soda'));
    await tester.pumpAndSettle();

    expect(find.text('Special Instructions'), findsOneWidget);
    expect(find.text('Add • UGX 17,000'), findsOneWidget);
  });

  testWidgets('guest checkout redirects to login', (WidgetTester tester) async {
    final state = AppState()..addToCart(snacks.first);

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          state: state,
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          AppScope(state: state, child: const CartSheet()),
                    );
                  },
                  child: const Text('Open Cart'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Cart'));
    await tester.pumpAndSettle();

    expect(find.text('Proceed to Checkout'), findsOneWidget);

    await tester.tap(find.text('Proceed to Checkout'));
    await tester.pumpAndSettle();

    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('SIGN UP'), findsOneWidget);
  });
}
