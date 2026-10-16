import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/data/auth_repository.dart';
import 'content.dart';
import 'game_state.dart';
import 'progress_codec.dart';

/// Loads a player's progress from Supabase on login and auto-saves it
/// shortly after every change.
class SupabaseProgressStore {
  SupabaseProgressStore(this._db);

  final SupabaseClient _db;
  GameState? _game;
  DateTime? _missionDay;
  Timer? _debounce;
  AppLifecycleListener? _lifecycle;
  bool _saving = false;
  bool _saveAgain = false;

  Future<void> attach(GameState game, AppUser user) async {
    await detach();
    final now = DateTime.now();
    final today = ProgressCodec.day(now);
    final (profile, progressRows, missionRow) = await (
      _db.from('profiles').select().eq('id', user.id).maybeSingle(),
      _db.from('concept_progress').select().eq('user_id', user.id),
      _db
          .from('missions')
          .select()
          .eq('user_id', user.id)
          .eq('day', today)
          .maybeSingle(),
    ).wait;

    game.restore(() {
      if (profile != null) {
        ProgressCodec.applyProfile(game, profile, now);
      } else {
        // Account created before the schema existed.
        game.onboarded = false;
      }
      game.progress.clear();
      for (final row in progressRows) {
        final id = row['concept_id'] as String;
        if (conceptById.containsKey(id)) {
          game.progress[id] = ProgressCodec.progressFromRow(row);
        }
      }
      if (missionRow != null) {
        game
          ..mission = ProgressCodec.tasksFromJson(missionRow['tasks'] as List)
          ..missionBonusClaimed = missionRow['bonus_claimed'] as bool? ?? false;
      } else {
        game
          ..mission = game.buildMission()
          ..missionBonusClaimed = false;
      }
    });

    _game = game;
    _missionDay = now;
    game
      ..addListener(_scheduleSave)
      ..onAttempt = _logAttempt;
    _lifecycle = AppLifecycleListener(onHide: flush);
  }

  /// Saves anything pending and stops syncing.
  Future<void> detach() async {
    await flush();
    _game?.removeListener(_scheduleSave);
    _game?.onAttempt = null;
    _game = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

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
      final progress = [
        for (final e in game.progress.entries)
          if (e.value.attempts > 0 || e.value.misconception != null)
            ProgressCodec.progressRow(uid, e.key, e.value, now),
      ];
      await Future.wait([
        _db.from('profiles').upsert(ProgressCodec.profileRow(game, now)),
        if (progress.isNotEmpty) _db.from('concept_progress').upsert(progress),
        _db.from('missions').upsert({
          'user_id': uid,
          'day': ProgressCodec.day(_missionDay ?? now),
          'tasks': ProgressCodec.tasksToJson(game.mission),
          'bonus_claimed': game.missionBonusClaimed,
          'updated_at': now.toUtc().toIso8601String(),
        }),
      ]);
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

  void _logAttempt(Question q, int chosen, bool correct, Duration taken) {
    final uid = _game?.userId;
    if (uid == null) return;
    _db
        .from('attempts')
        .insert({
          'user_id': uid,
          'question_id': q.id,
          'concept_id': q.conceptId,
          'chosen': chosen,
          'correct': correct,
          'time_ms': taken.inMilliseconds,
        })
        .catchError((Object e) => debugPrint('Attempt log failed: $e'));
  }

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
