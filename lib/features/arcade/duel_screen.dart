import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../game/content.dart';
import '../game/game_state.dart';
import 'arcade_widgets.dart';
import 'game_modes.dart';

/// Duel: a 60-second race against a rival matched to your rating. The rival
/// is simulated: it solves at a pace and accuracy set by its rating.
class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

enum _Phase { searching, versus, countdown, playing }

class _DuelScreenState extends State<DuelScreen> {
  static const _length = Duration(seconds: 60);
  static const _color = Color(0xFFF472B6);
  static const _names = [
    'NeonNewton',
    'PiPirate',
    'SigmaSam',
    'DeltaDiya',
    'VectorVik',
    'LimitLara',
    'ThetaTara',
    'CalcKabir',
    'ZetaZoya',
    'MatrixMeera',
  ];

  final _rand = math.Random();
  final _s = gameState.startSession('Duel', 0, mode: 'duel');
  final _watch = Stopwatch();
  late final String _rival = _names[_rand.nextInt(_names.length)];
  late final int _rivalRating = gameState.rating + _rand.nextInt(161) - 80;

  _Phase _phase = _Phase.searching;
  Timer? _tick;
  Timer? _botTimer;
  DateTime? _endsAt;
  bool _ended = false;
  int _botScore = 0;
  bool _botPulse = false;
  int _combo = 0;
  int? _chosen;
  Question _q = gameState.randomQuestion();

  Duration get _left =>
      _endsAt == null ? _length : _endsAt!.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _phase = _Phase.versus);
    });
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _phase = _Phase.countdown);
    });
  }

  void _start() {
    _endsAt = DateTime.now().add(_length);
    _watch.start();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_left <= Duration.zero) {
        _end();
      } else {
        setState(() {});
      }
    });
    _scheduleBot();
    setState(() => _phase = _Phase.playing);
  }

  /// The rival "answers" every few seconds; stronger rivals are faster and
  /// more accurate against a typical question.
  void _scheduleBot() {
    final speed = ((_rivalRating - 1000) / 400).clamp(-0.5, 1.0);
    final ms = (6500 - 2200 * speed + _rand.nextInt(2500) - 1250).round();
    _botTimer = Timer(Duration(milliseconds: math.max(1800, ms)), () {
      if (!mounted || _ended) return;
      final p = 1 / (1 + math.pow(10, (1100 - _rivalRating) / 400));
      if (_rand.nextDouble() < p) {
        setState(() {
          _botScore++;
          _botPulse = true;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _botPulse = false);
        });
      }
      _scheduleBot();
    });
  }

  void _answer(int i) {
    if (_chosen != null || _ended) return;
    final r = gameState.answer(
      question: _q,
      chosen: i,
      taken: _watch.elapsed,
      limit: const Duration(seconds: 8),
      combo: _combo,
      session: _s,
      rated: false,
    );
    _s.total++;
    r.correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    setState(() {
      _chosen = i;
      _combo = r.correct ? _combo + 1 : 0;
      if (_combo > _s.bestCombo) _s.bestCombo = _combo;
    });
    Future.delayed(Duration(milliseconds: r.correct ? 250 : 700), () {
      if (!mounted || _ended) return;
      setState(() {
        _q = gameState.randomQuestion();
        _chosen = null;
      });
      _watch
        ..reset()
        ..start();
    });
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    _tick?.cancel();
    _botTimer?.cancel();
    final me = _s.correct;
    final result = me > _botScore ? 1.0 : (me == _botScore ? 0.5 : 0.0);
    gameState.applyMatchResult(_rivalRating, result);
    _s
      ..score = me
      ..opponent = '$_rival ($_rivalRating) · $_botScore'
      ..outcome = result == 1 ? 'win' : (result == 0.5 ? 'draw' : 'loss');
    gameState.awardXp(
      _s,
      result == 1 ? 40 : (result == 0.5 ? 20 : 10),
      'duel_result',
    );
    endArcadeGame(context, _s);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_phase) {
        _Phase.searching => _Searching(color: _color),
        _Phase.versus => _Versus(
          me: gameState.displayName,
          myRating: gameState.rating,
          rival: _rival,
          rivalRating: _rivalRating,
        ),
        _ => Stack(
          children: [
            _game(),
            if (_phase == _Phase.countdown)
              GameCountdown(color: _color, onDone: _start),
          ],
        ),
      },
    );
  }

  Widget _game() {
    final secs = (_left.inMilliseconds / 1000).ceil().clamp(0, 60);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              children: [
                ArcadeHud(
                  title: 'Duel',
                  color: _color,
                  trailing: [
                    HudChip(
                      icon: Icons.timer_rounded,
                      text: '${secs}s',
                      color: _color,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TimeBar(
                  fraction: _left.inMilliseconds / _length.inMilliseconds,
                ),
                const SizedBox(height: 16),
                _Scoreboard(
                  me: gameState.displayName,
                  myScore: _s.correct,
                  rival: _rival,
                  rivalScore: _botScore,
                  rivalPulse: _botPulse,
                ),
                const Spacer(),
                PromptCard(
                  text: _q.prompt,
                  color: _color,
                  label: conceptById[_q.conceptId]!.name.toUpperCase(),
                ),
                const SizedBox(height: 20),
                OptionGrid(
                  options: _q.options,
                  onTap: _chosen == null && _phase == _Phase.playing
                      ? _answer
                      : null,
                  correct: _chosen == null ? null : _q.answer,
                  chosen: _chosen,
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 72,
            child: CircularProgressIndicator(color: color, strokeWidth: 5),
          ),
          const SizedBox(height: 24),
          const Text(
            'FINDING A RIVAL…',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Matching your rating ${gameState.rating}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Versus extends StatelessWidget {
  const _Versus({
    required this.me,
    required this.myRating,
    required this.rival,
    required this.rivalRating,
  });

  final String me;
  final int myRating;
  final String rival;
  final int rivalRating;

  @override
  Widget build(BuildContext context) {
    Widget player(String name, int rating, Color color, double dir) => Flexible(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (_, t, child) =>
            Transform.translate(offset: Offset(dir * 200 * t, 0), child: child),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: color,
              child: Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              '${tierFor(rating).name} · $rating',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(tierFor(rating).color),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            player(me, myRating, AppColors.secondary, -1),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'VS',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  shadows: [Shadow(color: AppColors.primary, blurRadius: 24)],
                ),
              ),
            ),
            player(rival, rivalRating, const Color(0xFFF472B6), 1),
          ],
        ),
      ),
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    required this.me,
    required this.myScore,
    required this.rival,
    required this.rivalScore,
    required this.rivalPulse,
  });

  final String me;
  final int myScore;
  final String rival;
  final int rivalScore;
  final bool rivalPulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                me,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$myScore',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.secondary,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '—',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            AnimatedScale(
              scale: rivalPulse ? 1.3 : 1,
              duration: const Duration(milliseconds: 150),
              child: Text(
                '$rivalScore',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF472B6),
                ),
              ),
            ),
            Expanded(
              child: Text(
                rival,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: myScore == 0 && rivalScore == 0 ? 1 : myScore,
                  child: const ColoredBox(color: AppColors.secondary),
                ),
                Expanded(
                  flex: myScore == 0 && rivalScore == 0 ? 1 : rivalScore,
                  child: const ColoredBox(color: Color(0xFFF472B6)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
