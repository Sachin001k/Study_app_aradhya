import 'package:aradhya/features/arcade/arcade_widgets.dart';
import 'package:aradhya/features/arcade/game_modes.dart';
import 'package:aradhya/features/auth/data/auth_repository.dart';
import 'package:aradhya/features/game/game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in arcadeModes) {
    testWidgets('${mode.title} starts and accepts input', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      gameState.signIn(
        const AppUser(id: 'u', email: 'a@b.co', displayName: 'Asha'),
      );

      await tester.pumpWidget(
        MaterialApp(theme: ThemeData.dark(), home: mode.builder()),
      );
      // Matchmaking (duel) + 3-2-1-GO countdown.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(GameCountdown), findsNothing);

      // Interact once in a mode-appropriate way.
      final option = find.descendant(
        of: find.byType(OptionGrid),
        matching: find.byType(InkWell),
      );
      if (option.evaluate().isNotEmpty) {
        await tester.tap(option.first);
      } else if (find.text('✓ TRUE').evaluate().isNotEmpty) {
        await tester.tap(find.text('✓ TRUE'));
      } else if (find.text('7').evaluate().isNotEmpty) {
        await tester.tap(find.text('7'));
      } else {
        await tester.tapAt(const Offset(80, 200)); // a memory card
      }
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);

      // Leave the game and let any pending timers run out.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
