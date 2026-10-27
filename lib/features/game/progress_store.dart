import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/data/auth_repository.dart';
import 'content.dart';
import 'game_state.dart';
import 'progress_codec.dart';

/// Syncs one player's game with Supabase:
/// * loads every table on login,
/// * upserts state tables (profile, stats, progress, mission…) shortly after
///   any change,
/// * appends event rows (answers, XP, badges, sessions…) as they happen,
///   retrying any that fail on the next save.
class SupabaseProgressStore implements GameEventSink {
  SupabaseProgressStore(this._db);

  final SupabaseClient _db;
  GameState? _game;
  DateTime? _missionDay;
  Set<String> _savedSubjects = {};
  Timer? _debounce;
  AppLifecycleListener? _lifecycle;
  bool _saving = false;
  bool _saveAgain = false;
  final List<(String, Map<String, dynamic>)> _pending = [];

  String? get _uid => _game?.userId;

  // ---------------------------------------------------------------- loading

  Future<void> attach(GameState game, AppUser user) async {
    await detach();
    final uid = user.id;
    final now = DateTime.now();
    final today = ProgressCodec.day(now);

    final (
      profile,
      stats,
      progress,
      mission,
      tasks,
      subjects,
      badges,
      bests,
      daily,
    ) = await (
      _db.from('profiles').select().eq('id', uid).maybeSingle(),
      _db.from('player_stats').select().eq('user_id', uid).maybeSingle(),
      _db.from('concept_progress').select().eq('user_id', uid),
      _db
          .from('missions')
          .select()
          .eq('user_id', uid)
          .eq('day', today)
          .maybeSingle(),
      _db.from('mission_tasks').select().eq('user_id', uid).eq('day', today),
      _db.from('user_subjects').select('subject').eq('user_id', uid),
      _db.from('user_badges').select('badge_id').eq('user_id', uid),
      _db.from('personal_bests').select('mode, best_score').eq('user_id', uid),
      _db
          .from('daily_activity')
          .select()
          .eq('user_id', uid)
          .eq('day', today)
          .maybeSingle(),
    ).wait;

    game.restore(() {
      if (profile != null) {
        ProgressCodec.applyProfile(game, profile);
      } else {
        game.onboarded = false; // account created before the schema existed
      }
      if (stats != null) ProgressCodec.applyStats(game, stats, now);
      if (daily != null) ProgressCodec.applyDaily(game, daily);

      game.subjects = {for (final r in subjects) r['subject'] as String};
      if (game.subjects.isEmpty) game.subjects = {'Maths'};

      game.badges
        ..clear()
        ..addAll(badges.map((r) => r['badge_id'] as String));
      game.personalBests
        ..clear()
        ..addEntries(
          bests.map(
            (r) => MapEntry(r['mode'] as String, r['best_score'] as int),
          ),
        );

      game.progress.clear();
      for (final row in progress) {
        final id = row['concept_id'] as String;
        if (conceptById.containsKey(id)) {
          game.progress[id] = ProgressCodec.progressFromRow(row);
        }
      }

      final restored = ProgressCodec.tasksFromRows(tasks);
      if (mission != null && restored.isNotEmpty) {
        game
          ..mission = restored
          ..missionBonusClaimed = mission['bonus_claimed'] as bool? ?? false;
      } else {
        game
          ..mission = game.buildMission()
          ..missionBonusClaimed = false;
      }
    });

    _game = game;
    _missionDay = now;
    _savedSubjects = subjects.map((r) => r['subject'] as String).toSet();
    game
      ..addListener(_scheduleSave)
      ..events = this;
    _lifecycle = AppLifecycleListener(onHide: flush);
  }

  /// Saves anything pending and stops syncing.
  Future<void> detach() async {
    // flush() returns early while a save is in flight, so wait for that save
    // (bounded) before the final one; otherwise the last answers are lost.
    _debounce?.cancel();
    for (var i = 0; _saving && i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await flush();
    // Failed rows belong to this user; retrying them as the next one fails RLS.
    _pending.clear();
    _game?.removeListener(_scheduleSave);
    _game?.events = null;
    _game = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  // ----------------------------------------------------------------- saving

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), flush);
  }

  Future<void> flush() async {
    _debounce?.cancel();
    final game = _game;
    final uid = game?.userId;
    if (game == null || uid == null) return;
    if (_saving) {
      _saveAgain = true;
      return;
    }
    _saving = true;
    try {
      final now = DateTime.now();
      final day = _missionDay ?? now;
      final progress = [
        for (final e in game.progress.entries)
          if (e.value.attempts > 0 || e.value.misconception != null)
            ProgressCodec.progressRow(uid, e.key, e.value, now),
      ];
      final tasks = ProgressCodec.taskRows(uid, day, game.mission, now);

      await Future.wait([
        _db.from('profiles').upsert(ProgressCodec.profileRow(game, now)),
        _db.from('player_stats').upsert(ProgressCodec.statsRow(game, now)),
        _db.from('daily_activity').upsert(ProgressCodec.dailyRow(game, now)),
        if (progress.isNotEmpty) _db.from('concept_progress').upsert(progress),
        _saveSubjects(uid, game.subjects),
      ]);
      // Tasks reference their mission row, so save it first.
      await _db
          .from('missions')
          .upsert(ProgressCodec.missionRow(game, day, now));
      if (tasks.isNotEmpty) await _db.from('mission_tasks').upsert(tasks);
      await _db
          .from('mission_tasks')
          .delete()
          .eq('user_id', uid)
          .eq('day', ProgressCodec.day(day))
          .gte('position', tasks.length);

      await _retryPending();
    } catch (e) {
      debugPrint('Progress save failed: $e');
    } finally {
      _saving = false;
      if (_saveAgain) {
        _saveAgain = false;
        unawaited(flush());
      }
    }
  }

  Future<void> _saveSubjects(String uid, Set<String> subjects) async {
    if (subjects.length == _savedSubjects.length &&
        subjects.containsAll(_savedSubjects)) {
      return;
    }
    await _db.from('user_subjects').delete().eq('user_id', uid);
    await _db.from('user_subjects').insert([
      for (final s in subjects) {'user_id': uid, 'subject': s},
    ]);
    _savedSubjects = {...subjects};
  }

  // ------------------------------------------------------------ event rows

  void _insert(String table, Map<String, dynamic> row, {bool upsert = false}) {
    final q = upsert
        ? _db.from(table).upsert(row)
        : _db.from(table).insert(row);
    q.then<void>((_) {}).catchError((Object e) {
      debugPrint('$table insert failed, will retry: $e');
      _pending.add((upsert ? '$table|upsert' : table, row));
    });
  }

  Future<void> _retryPending() async {
    if (_pending.isEmpty) return;
    final batch = [..._pending];
    _pending.clear();
    for (final (key, row) in batch) {
      final [table, ...mode] = key.split('|');
      try {
        mode.isEmpty
            ? await _db.from(table).insert(row)
            : await _db.from(table).upsert(row);
      } catch (_) {
        _pending.add((key, row));
      }
    }
  }

  @override
  void onAttempt(
    SessionSummary session,
    Question question,
    int chosen,
    bool correct,
    Duration taken,
    int ratingDelta,
  ) {
    final uid = _uid;
    if (uid == null) return;
    _insert(
      'attempts',
      ProgressCodec.attemptRow(
        uid,
        session,
        question,
        chosen,
        correct,
        taken,
        ratingDelta,
      ),
    );
  }

  @override
  void onArithmetic(
    SessionSummary session,
    String prompt,
    int answer,
    int? given,
    bool correct,
    Duration taken,
  ) {
    final uid = _uid;
    if (uid == null) return;
    _insert('attempts', {
      'user_id': uid,
      'session_id': session.id,
      'mode': session.mode,
      'question_id': 'crunch',
      'concept_id': 'arithmetic',
      'prompt': prompt,
      'correct_answer': '$answer',
      'given_answer': given?.toString(),
      'correct': correct,
      'time_ms': taken.inMilliseconds,
    });
  }

  @override
  void onXp(SessionSummary? session, int amount, String source) {
    final uid = _uid;
    if (uid == null) return;
    _insert('xp_events', {
      'user_id': uid,
      'session_id': session?.id,
      'amount': amount,
      'source': source,
    });
  }

  @override
  void onMisconception(SessionSummary session, Diagnosis d) {
    final uid = _uid;
    if (uid == null) return;
    _insert('misconception_events', {
      'user_id': uid,
      'session_id': session.id,
      'kind': 'detected',
      'question_id': d.question.id,
      'concept_id': d.question.conceptId,
      'root_cause': d.rootCause.id,
      'explanation': d.explanation,
    });
  }

  @override
  void onRepaired(SessionSummary session, Concept concept) {
    final uid = _uid;
    if (uid == null) return;
    _insert('misconception_events', {
      'user_id': uid,
      'session_id': session.id,
      'kind': 'repaired',
      'concept_id': concept.id,
      'root_cause': concept.id,
    });
  }

  @override
  void onBadge(SessionSummary? session, GameBadge badge) {
    final uid = _uid;
    if (uid == null) return;
    _insert('user_badges', {
      'user_id': uid,
      'badge_id': badge.id,
      'session_id': session?.id,
    }, upsert: true);
  }

  @override
  void onSessionFinished(SessionSummary session, MissionTask? task) {
    final uid = _uid;
    if (uid == null) return;
    final now = DateTime.now();
    _insert('game_sessions', ProgressCodec.sessionRow(uid, session, task, now));

    final after = session.ratingAfter ?? session.ratingBefore;
    if (after != session.ratingBefore) {
      _insert('rating_history', {
        'user_id': uid,
        'session_id': session.id,
        'mode': session.mode,
        'rating_before': session.ratingBefore,
        'rating_after': after,
        'delta': after - session.ratingBefore,
      });
    }

    final score = session.score;
    if (score != null && _game?.personalBests[session.mode] == score) {
      _insert('personal_bests', {
        'user_id': uid,
        'mode': session.mode,
        'best_score': score,
        'session_id': session.id,
        'achieved_at': now.toUtc().toIso8601String(),
      }, upsert: true);
    }
  }

  @override
  void onFocus(
    String kind, {
    String? conceptId,
    Map<String, Object?> data = const {},
  }) {
    final uid = _uid;
    if (uid == null) return;
    _insert('focus_events', {
      'user_id': uid,
      'kind': kind,
      'concept_id': conceptId,
      'data': data,
    });
  }

  @override
  void onExplanation(
    SessionSummary session,
    String conceptId,
    int seconds,
    int covered,
    int total,
  ) {
    final uid = _uid;
    if (uid == null) return;
    _insert('explanations', {
      'user_id': uid,
      'session_id': session.id,
      'concept_id': conceptId,
      'seconds': seconds,
      'points_covered': covered,
      'points_total': total,
    });
  }

  // ----------------------------------------------------------------- league

  /// Top players this week: (id, name, weekly XP).
  Future<List<({String id, String name, int xp})>> weeklyLeague() async {
    final rows = await _db.rpc<List<dynamic>>('weekly_league');
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        (
          id: r['id'] as String,
          name: r['display_name'] as String,
          xp: r['weekly_xp'] as int,
        ),
    ];
  }
}
