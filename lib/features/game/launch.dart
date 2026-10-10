import 'package:flutter/material.dart';

import '../blitz/blitz_screen.dart';
import '../learn/explain_screen.dart';
import '../learn/lesson_screen.dart';
import 'content.dart';
import 'game_state.dart';

/// Opens the right activity for a mission task.
void launchTask(BuildContext context, MissionTask task) {
  final concept = conceptById[task.conceptIds.first]!;
  final Widget screen = switch (task.type) {
    TaskType.learn => LessonScreen(concept: concept, task: task),
    TaskType.explain => ExplainScreen(concept: concept, task: task),
    _ => BlitzScreen(
      title: task.title,
      questions: gameState.questionsForTask(task),
      task: task,
      xpMultiplier: task.type == TaskType.boss ? 2 : 1,
    ),
  };
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

void launchPractice(BuildContext context, Concept concept) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BlitzScreen(
        title: concept.name,
        questions: questionsFor(concept.id)..shuffle(),
      ),
    ),
  );
}

void launchLesson(BuildContext context, Concept concept) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => LessonScreen(concept: concept)));
}

/// Five random questions from concepts the player has already met.
void launchQuickBlitz(BuildContext context) {
  final seen = concepts
      .where((c) => gameState.progressOf(c.id).attempts > 0)
      .map((c) => c.id)
      .toSet();
  final pool =
      questions
          .where((q) => seen.isEmpty || seen.contains(q.conceptId))
          .toList()
        ..shuffle();
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          BlitzScreen(title: 'Quick blitz', questions: pool.take(5).toList()),
    ),
  );
}
