import 'package:aradhya/features/arcade/arcade_screen.dart';
import 'package:aradhya/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('typed email login → transition → tabs respond', (tester) async {
    tester.view.physicalSize = const Size(1800, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const LoginScreen()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'asha@aradhya.app',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('LOG IN'));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Arcade'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
    expect(find.byType(ArcadeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
