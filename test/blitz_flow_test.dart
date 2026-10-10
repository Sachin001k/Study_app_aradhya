import 'package:aradhya/features/auth/data/auth_repository.dart';
import 'package:aradhya/features/blitz/blitz_screen.dart';
import 'package:aradhya/features/game/content.dart';
import 'package:aradhya/features/game/game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('play a full blitz through to the results screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    gameState.signIn(
      const AppUser(id: 'u', email: 'a@b.co', displayName: 'Asha'),
    );
    final qs = questionsFor('composition');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlitzScreen(title: 'Test', questions: qs),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    for (var i = 0; i < qs.length; i++) {
      await tester.tap(find.text(qs[i].options[qs[i].answer]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Nailed it!'), findsOneWidget);
      await tester.tap(
        find.text(i == qs.length - 1 ? 'SEE RESULTS' : 'CONTINUE'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Great round!'), findsOneWidget);
    expect(find.textContaining('Misconception repaired'), findsOneWidget);
  });
}
