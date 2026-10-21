import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ads/ad_service.dart';
import '../daily/daily.dart';
import '../engine/level.dart';
import '../game/game_result.dart';
import '../l10n/app_localizations.dart';
import '../storage/progress_store.dart';
import 'result_screens.dart';
import 'theme.dart';
import 'tokens.dart';

/// Daily calendar (wireframe 10): streak card, month calendar (grey =
/// completed, dark = today) and «Play today's». Winning marks the day done;
/// a loss can be retried the same day. Never shows an interstitial
/// (`GameArgs.isDaily = true`, no `maybeShowInterstitial` call). Locked
/// («Unlocks at level 8») until map level 8 is completed.
class DailyScreen extends StatefulWidget {
  const DailyScreen({
    super.key,
    required this.ads,
    required this.pack,
    required this.progress,
    required this.gameBuilder,
    this.store,
    this.clock = DateTime.now,
    this.onRequestRewarded,
  });

  final AdService ads;
  final List<Level> pack;
  final ProgressController progress;
  final GameScreenBuilder gameBuilder;
  final DailyStore? store;
  final DateTime Function() clock;
  final Future<bool> Function()? onRequestRewarded;

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  late final DailyStore _store = widget.store ?? DailyStore();
  DailyState? _state;

  @override
  void initState() {
    super.initState();
    _store.load().then((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  Future<void> _play() async {
    final today = widget.clock();
    final level = dailyLevel(today, widget.pack, widget.progress.progress.stars.keys);
    if (level == null) return;
    final pc = widget.progress;
    while (mounted) {
      final result = await Navigator.of(context).push(
        GameRoute(
          levelId: level.id,
          args: GameArgs(
            level: level,
            ads: widget.ads,
            boosters: Map.unmodifiable(pc.progress.boosters),
            isDaily: true,
            onRequestRewarded: widget.onRequestRewarded,
            onBoosterSpent: (id) => pc.spendBoosters({id: 1}),
          ),
          builder: widget.gameBuilder,
        ),
      );
      if (result == null || !mounted) return;
      if (result.won) {
        final s = await _store.recordWin(today);
        await widget.ads.recordLevelCompleted(isDaily: true);
        if (!mounted) return;
        setState(() => _state = s);
        await Navigator.of(context).push(
          MaterialPageRoute<WinAction>(
            settings: const RouteSettings(name: '/daily-win'),
            builder: (c) => WinScreen(
              levelId: level.id,
              stars: result.starsEarned,
              hasNext: false,
              subtitle: AppLocalizations.of(c).dailyTitle,
            ),
          ),
        );
        // No interstitial in daily, ever.
        return;
      }
      if (!result.retry) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ink = theme.extension<GamePalette>()!;
    final s = _state;
    final today = widget.clock();
    final unlocked = dailyUnlocked(widget.progress.progress.stars.keys);
    return Scaffold(
      appBar: AppBar(title: Text(t.dailyTitle), centerTitle: true),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Tk.l),
              children: [
                Container(
                  key: const Key('dailyStreakCard'),
                  padding: const EdgeInsets.all(Tk.l),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(Tk.rCard),
                    border: Border.all(color: ink.cellBorder, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.dailyStreak(s.streak(today)), style: theme.textTheme.titleLarge),
                      const SizedBox(height: Tk.xs),
                      Text(t.dailyBest(s.best), style: theme.textTheme.bodySmall?.copyWith(color: ink.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: Tk.xl),
                _MonthCalendar(month: today, today: today, state: s),
                const SizedBox(height: Tk.xl),
                SizedBox(
                  height: Tk.button + Tk.s,
                  child: FilledButton(
                    key: const Key('dailyPlay'),
                    onPressed: !unlocked || s.isDone(today) ? null : _play,
                    child: Text(!unlocked ? t.dailyLocked : (s.isDone(today) ? t.dailyDone : t.dailyPlay)),
                  ),
                ),
                const SizedBox(height: Tk.m),
                Text(
                  t.dailyLegend,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: ink.textMuted),
                ),
              ],
            ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.month, required this.today, required this.state});
  final DateTime month, today;
  final DailyState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.extension<GamePalette>()!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final ml = MaterialLocalizations.of(context);
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first
    // narrowWeekdays starts on Sunday.
    final heads = [for (var i = 1; i <= 7; i++) ml.narrowWeekdays[i % 7]];
    final title = DateFormat('LLLL y', locale).format(first);
    return Column(
      children: [
        Text(
          '${title[0].toUpperCase()}${title.substring(1)}',
          key: const Key('dailyMonth'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: Tk.m),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Tk.s,
          crossAxisSpacing: Tk.s,
          children: [
            for (final h in heads)
              Center(
                child: Text(h, style: theme.textTheme.bodySmall?.copyWith(color: ink.textMuted)),
              ),
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var d = 1; d <= days; d++) _day(context, DateTime(month.year, month.month, d)),
          ],
        ),
      ],
    );
  }

  Widget _day(BuildContext context, DateTime d) {
    final theme = Theme.of(context);
    final ink = theme.extension<GamePalette>()!;
    final isToday = dayKey(d) == dayKey(today);
    final done = state.isDone(d);
    final fill = isToday
        ? theme.colorScheme.onSurface
        : (done ? ink.stone.withValues(alpha: .45) : theme.colorScheme.surface);
    final fg = isToday ? theme.colorScheme.surface : theme.colorScheme.onSurface;
    return Container(
      key: Key('day-${dayKey(d)}${done ? '-done' : ''}${isToday ? '-today' : ''}'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: ink.cellBorder, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text('${d.day}', style: theme.textTheme.labelLarge?.copyWith(color: fg)),
    );
  }
}
