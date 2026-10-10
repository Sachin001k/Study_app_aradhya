import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_button.dart';
import '../game/content.dart';
import '../game/game_state.dart';
import '../game/launch.dart';

Color statusColor(ConceptStatus s) => switch (s) {
  ConceptStatus.mastered => AppColors.mastered,
  ConceptStatus.weak => AppColors.weak,
  ConceptStatus.misconception => AppColors.misconception,
  ConceptStatus.notStudied => AppColors.notStudied,
};

String statusLabel(ConceptStatus s) => switch (s) {
  ConceptStatus.mastered => 'Mastered',
  ConceptStatus.weak => 'Weak',
  ConceptStatus.misconception => 'Misconception',
  ConceptStatus.notStudied => 'Not studied',
};

/// Personal knowledge graph: concepts laid out by prerequisite depth.
class GraphScreen extends StatelessWidget {
  const GraphScreen({super.key});

  static const _rowHeight = 112.0;
  static const _nodeSize = 52.0;

  /// Longest prerequisite chain to each concept = its row.
  static final Map<String, int> _depth = () {
    final depth = <String, int>{};
    int visit(String id) => depth[id] ??= conceptById[id]!.prereqs.isEmpty
        ? 0
        : 1 +
              conceptById[id]!.prereqs
                  .map(visit)
                  .reduce((a, b) => a > b ? a : b);
    for (final c in concepts) {
      visit(c.id);
    }
    return depth;
  }();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameState,
      builder: (context, _) {
        final now = DateTime.now();
        final counts = <ConceptStatus, int>{};
        for (final c in concepts) {
          final s = gameState.progressOf(c.id).status;
          counts[s] = (counts[s] ?? 0) + 1;
        }
        final fading = concepts
            .where((c) => gameState.progressOf(c.id).isFading(now))
            .length;

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Knowledge map',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      subjectName,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        for (final s in ConceptStatus.values)
                          _Legend(
                            color: statusColor(s),
                            label: '${statusLabel(s)} ${counts[s] ?? 0}',
                          ),
                        _Legend(
                          color: AppColors.mastered.withValues(alpha: 0.35),
                          label: 'Fading $fading',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.clamp(340.0, 640.0);
                    final rows =
                        _depth.values.reduce((a, b) => a > b ? a : b) + 1;
                    final height = rows * _rowHeight + 40;
                    final pos = _layout(width);
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Center(
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(painter: _EdgePainter(pos)),
                              ),
                              for (final c in concepts)
                                Positioned(
                                  left: pos[c.id]!.dx - 50,
                                  top: pos[c.id]!.dy - _nodeSize / 2,
                                  width: 100,
                                  child: _Node(
                                    concept: c,
                                    progress: gameState.progressOf(c.id),
                                    now: now,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, Offset> _layout(double width) {
    final byRow = <int, List<Concept>>{};
    for (final c in concepts) {
      byRow.putIfAbsent(_depth[c.id]!, () => []).add(c);
    }
    return {
      for (final MapEntry(key: row, value: list) in byRow.entries)
        for (var i = 0; i < list.length; i++)
          list[i].id: Offset(
            width * (i + 0.5) / list.length,
            40 + row * _rowHeight,
          ),
    };
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.pos);

  final Map<String, Offset> pos;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final c in concepts) {
      for (final p in c.prereqs) {
        final a = pos[p]!, b = pos[c.id]!;
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(
            a.dx,
            (a.dy + b.dy) / 2,
            b.dx,
            (a.dy + b.dy) / 2,
            b.dx,
            b.dy,
          );
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.pos != pos;
}

class _Node extends StatelessWidget {
  const _Node({
    required this.concept,
    required this.progress,
    required this.now,
  });

  final Concept concept;
  final ConceptProgress progress;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = progress.status;
    final color = statusColor(status);
    final fading = progress.isFading(now);
    // Fading memories literally fade on the map.
    final opacity = status == ConceptStatus.notStudied
        ? 1.0
        : (0.35 + 0.65 * progress.recall(now)).clamp(0.35, 1.0);

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Column(
        children: [
          Opacity(
            opacity: opacity,
            child: Container(
              width: GraphScreen._nodeSize,
              height: GraphScreen._nodeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  if (status != ConceptStatus.notStudied)
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 14,
                    ),
                ],
              ),
              child: Icon(switch (status) {
                ConceptStatus.mastered =>
                  fading ? Icons.hourglass_bottom_rounded : Icons.check_rounded,
                ConceptStatus.weak => Icons.trending_up_rounded,
                ConceptStatus.misconception => Icons.priority_high_rounded,
                ConceptStatus.notStudied => Icons.lock_open_rounded,
              }, color: color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            concept.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final status = progress.status;
    final color = statusColor(status);
    final prereqNames = concept.prereqs
        .map((p) => conceptById[p]!.name)
        .join(', ');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      concept.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _Legend(color: color, label: statusLabel(status)),
                ],
              ),
              if (prereqNames.isNotEmpty)
                Text(
                  'Builds on: $prereqNames',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 16),
              if (status != ConceptStatus.notStudied) ...[
                _Meter(label: 'Mastery', value: progress.mastery, color: color),
                const SizedBox(height: 10),
                _Meter(
                  label: 'Recall today',
                  value: progress.recall(now),
                  color: AppColors.secondary,
                ),
              ],
              if (progress.misconception != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.misconception.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '⚠️ ${progress.misconception!}\nGet 2 in a row right to repair it.',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GameButton.secondary(
                      label: 'Learn',
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        launchLesson(context, concept);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GameButton(
                      label: status == ConceptStatus.misconception
                          ? 'Repair'
                          : 'Practice',
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        launchPractice(context, concept);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              color: color,
              backgroundColor: AppColors.surfaceHigh,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
