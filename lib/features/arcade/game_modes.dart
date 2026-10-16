import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../blitz/results_screen.dart';
import '../game/game_state.dart';
import 'crunch_screen.dart';
import 'duel_screen.dart';
import 'memory_screen.dart';
import 'rush_screen.dart';
import 'survival_screen.dart';
import 'true_false_screen.dart';

class GameMode {
  const GameMode({
    required this.id,
    required this.title,
    required this.tagline,
    required this.rules,
    required this.emoji,
    required this.color,
    required this.builder,
  });

  final String id;
  final String title;
  final String tagline;
  final String rules;
  final String emoji;
  final Color color;
  final Widget Function() builder;
}

final arcadeModes = <GameMode>[
  GameMode(
    id: 'duel',
    title: 'Duel',
    tagline: '1v1 vs a rated rival',
    rules: '60 seconds. Solve more than your opponent. Win to gain rating.',
    emoji: '🤺',
    color: const Color(0xFFF472B6),
    builder: DuelScreen.new,
  ),
  GameMode(
    id: 'rush',
    title: 'Speed Rush',
    tagline: '60 seconds, go go go',
    rules: 'Answer as many as you can in 60 seconds. Combos boost XP.',
    emoji: '⚡',
    color: AppColors.xp,
    builder: RushScreen.new,
  ),
  GameMode(
    id: 'survival',
    title: 'Survival',
    tagline: '3 lives, rising difficulty',
    rules:
        '15 seconds per question. Every 4 correct, it gets harder. 3 mistakes and you’re out.',
    emoji: '🛡️',
    color: AppColors.misconception,
    builder: SurvivalScreen.new,
  ),
  GameMode(
    id: 'truefalse',
    title: 'True or False',
    tagline: 'Spot the trap',
    rules: '45 seconds. Is the statement right? Traps are common mistakes.',
    emoji: '🕵️',
    color: AppColors.secondary,
    builder: TrueFalseScreen.new,
  ),
  GameMode(
    id: 'crunch',
    title: 'Number Crunch',
    tagline: 'Mental maths sprint',
    rules:
        'Type the answer — it checks itself. Gets harder as you go. 60 seconds.',
    emoji: '🧮',
    color: AppColors.primary,
    builder: CrunchScreen.new,
  ),
  GameMode(
    id: 'memory',
    title: 'Memory Match',
    tagline: 'Pair expressions & results',
    rules:
        'Flip two cards to match an expression with its result. Fewer moves = higher score.',
    emoji: '🧠',
    color: AppColors.mastered,
    builder: MemoryScreen.new,
  ),
];

GameMode modeById(String id) => arcadeModes.firstWhere((m) => m.id == id);

/// Records the finished game and shows the results with a replay button.
void endArcadeGame(BuildContext context, SessionSummary session) {
  gameState.finishSession(session);
  final mode = modeById(session.mode);
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => ResultsScreen(session: session, replay: mode.builder),
    ),
  );
}
