import 'package:aradhya/features/arcade/arcade_screen.dart';
import 'package:aradhya/features/auth/data/auth_repository.dart';
import 'package:aradhya/features/entry/game_entry_screen.dart';
import 'package:aradhya/features/game/game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('after the entry transition, Home is interactive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    gameState.signIn(
      const AppUser(id: 'u', email: 'a@b.co', displayName: 'Asha'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => enterGame(context),
            child: const Text('login'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('login'));
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(GameEntryScreen), findsNothing);

    await tester.tap(find.text('Arcade'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ArcadeScreen is in an IndexedStack; check it became the visible index.
    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, 1);
    expect(find.byType(ArcadeScreen), findsOneWidget);
  });
}
