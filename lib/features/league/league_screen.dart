import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../game/game_state.dart';
import '../game/session.dart';

typedef _Player = ({String name, int xp, bool me});

/// Weekly XP league: real players from Supabase, or sample rivals offline.
class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  static const _promote = 3;
  static const _demote = 3;

  /// Zones only make sense once the league has enough players.
  static const _minForZones = 8;

  static const _sampleRivals = <(String, int)>[
    ('Ishaan', 640),
    ('Meera', 585),
    ('Kabir', 512),
    ('Ananya', 470),
    ('Vihaan', 431),
    ('Diya', 388),
    ('Arjun', 342),
    ('Saanvi', 297),
    ('Reyansh', 251),
    ('Myra', 204),
    ('Aarav', 160),
    ('Kiara', 95),
    ('Advait', 48),
    ('Zoya', 20),
  ];

  List<({String id, String name, int xp})>? _remote;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final store = progressStore;
    if (store == null) return;
    setState(() => _loading = true);
    try {
      await store.flush();
      final rows = await store.weeklyLeague();
      if (mounted) {
        setState(() {
          _remote = rows;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('League load failed: $e');
      if (mounted) setState(() => _error = 'Couldn’t load the league.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Player> _players() {
    final me = (name: gameState.displayName, xp: gameState.weeklyXp, me: true);
    final List<_Player> others;
    if (progressStore == null) {
      others = [
        for (final r in _sampleRivals) (name: r.$1, xp: r.$2, me: false),
      ];
    } else {
      others = [
        for (final r in _remote ?? const <({String id, String name, int xp})>[])
          if (r.id != gameState.userId) (name: r.name, xp: r.xp, me: false),
      ];
    }
    return [...others, me]..sort((a, b) => b.xp.compareTo(a.xp));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameState,
      builder: (context, _) {
        final players = _players();
        final zones = players.length >= _minForZones;
        final tier = tierFor(gameState.rating);

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: Color(tier.color),
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tier.name} League',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            progressStore == null
                                ? 'Sample rivals (offline) · ends Sunday'
                                : zones
                                ? 'Top $_promote promote · ends Sunday'
                                : '${players.length} player${players.length == 1 ? '' : 's'} this week · ends Sunday',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (progressStore != null)
                      _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              tooltip: 'Refresh',
                              icon: const Icon(Icons.refresh_rounded),
                              onPressed: _refresh,
                            ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 20),
                for (var i = 0; i < players.length; i++) ...[
                  if (zones && i == _promote)
                    const _ZoneDivider('PROMOTION ZONE ↑', AppColors.mastered),
                  if (zones && i == players.length - _demote)
                    const _ZoneDivider(
                      'DEMOTION ZONE ↓',
                      AppColors.misconception,
                    ),
                  _Row(
                    rank: i + 1,
                    name: players[i].name,
                    xp: players[i].xp,
                    me: players[i].me,
                    zoneColor: !zones
                        ? null
                        : i < _promote
                        ? AppColors.mastered
                        : i >= players.length - _demote
                        ? AppColors.misconception
                        : null,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ZoneDivider extends StatelessWidget {
  const _ZoneDivider(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: color.withValues(alpha: 0.5))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Divider(color: color.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.name,
    required this.xp,
    required this.me,
    this.zoneColor,
  });

  final int rank;
  final String name;
  final int xp;
  final bool me;
  final Color? zoneColor;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: me
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: me ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              medal ?? '$rank',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: zoneColor ?? AppColors.textSecondary,
                fontSize: medal != null ? 20 : 15,
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceHigh,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              me ? '$name (you)' : name,
              style: TextStyle(
                fontWeight: me ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$xp XP',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.xp,
            ),
          ),
        ],
      ),
    );
  }
}
