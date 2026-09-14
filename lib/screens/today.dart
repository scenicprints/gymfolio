import 'package:flutter/material.dart';

import '../app.dart';
import '../engine.dart';
import '../exercise_art.dart';
import '../state.dart';
import '../theme.dart';
import 'calibrate.dart';
import 'checkin.dart';
import 'hsr_runner.dart';
import 'iso_runner.dart';

/// The front door. The morning check-in comes first because it is the signal
/// the whole program turns on, and it is captured twelve hours away from the
/// gym where a workout app would never think to ask.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final e = model.engine!;
    final s = model.state!;
    final p = model.program!;
    final now = DateTime.now();
    final plan = e.todayPlan(now);
    final resume = e.resumable(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
      children: [
        const _Header(),
        const SizedBox(height: 14),
        const _Cluster(),
        const SizedBox(height: 18),

        if (plan.stopped) ...[
          const _StoppedCard(),
          const SizedBox(height: 16),
        ] else ...[
          if (resume != null) ...[
            _ResumeCard(resume: resume),
            const SizedBox(height: 12),
          ],

          if (plan.needsCheckIn)
            const _CheckInPrompt()
          else
            _CheckInDone(checkIn: s.checkInOn(ymd(now))!),

          if (plan.inFlare) ...[
            const SizedBox(height: 12),
            _FlareCard(plan: plan),
          ],
          if (!plan.inFlare && plan.readyToAdvancePhase) ...[
            const SizedBox(height: 12),
            const _AdvancePhaseCard(),
          ],
          if (!plan.inFlare && plan.needsCalibration) ...[
            const SizedBox(height: 12),
            const _CalibrateCard(),
          ],

          const SizedBox(height: 22),
          const SectionLabel('Today'),
          if (plan.items.isEmpty)
            _RestCard(plan: plan)
          else
            ...plan.items.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WorkItem(item: i, blocked: plan.needsCalibration),
                )),
        ],

        const SizedBox(height: 26),
        const SectionLabel('Last 10 mornings'),
        const Panel(child: _MorningStrip()),
        const SizedBox(height: 16),
        Text(
          p.governing.notes.first,
          style: const TextStyle(color: Tone.faint, fontSize: 12.5, height: 1.45),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final e = model.engine!;
    final s = model.state!;

    final badge = switch (s.mode) {
      kModeFlare => ('flare', Tone.bad),
      kModeStopped => ('stopped', Tone.bad),
      _ => (e.isMaintenance ? 'maintenance' : 'on program', Tone.good),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('WEEK ${e.docWeek}', style: display(44)),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Pill(badge.$1, color: badge.$2),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('DAY ${e.daysSinceStart(DateTime.now()) + 1}',
                  style: stencil(12)),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(e.phase.title,
            style: const TextStyle(color: Tone.dim, fontSize: 14.5)),
      ],
    );
  }
}

/// The readout strip — what this week is made of, at a glance.
class _Cluster extends StatelessWidget {
  const _Cluster();

  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context).engine!;
    final block = e.loadBlock;
    final items = <Widget>[];

    if (e.activePhase.isDaily || e.phase.isDaily) {
      final b = e.activePhase.blocks.isEmpty ? null : e.activePhase.blocks.first;
      if (b != null) {
        items.addAll([
          Readout(label: 'hold', value: '${b.holdSeconds}', unit: 's', size: 26),
          Readout(label: 'rounds', value: '${b.sets}', size: 26),
          Readout(
              label: 'rest',
              value: (b.restSeconds / 60).toStringAsFixed(0),
              unit: 'min',
              size: 26),
          Readout(label: 'daily', value: '${b.timesPerDay}', unit: '×', size: 26),
        ]);
      }
    } else if (block != null) {
      final rest = block.restSeconds;
      items.addAll([
        Readout(label: 'scheme', value: '${block.sets}×${block.reps}', size: 26),
        Readout(
            label: 'rest',
            value: rest % 60 == 0
                ? '${rest ~/ 60}'
                : (rest / 60).toStringAsFixed(1),
            unit: 'min',
            size: 26),
        Readout(
            label: 'tempo',
            value: '${e.phase.tempo.up}/${e.phase.tempo.down}',
            size: 26),
        Readout(label: 'target', value: block.target.split('-').first, unit: 'RM', size: 26),
      ]);
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items,
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final InProgress resume;
  const _ResumeCard({required this.resume});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final done = resume.sets.length;

    return Panel(
      rail: Tone.hold,
      fill: Tone.hold.withValues(alpha: 0.07),
      border: Tone.hold.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline, color: Tone.hold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${resume.label} is unfinished',
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            resume.kind == 'hsr'
                ? '$done ${done == 1 ? 'set' : 'sets'} logged. Pick up where you stopped.'
                : 'Stopped after ${resume.position} of the rounds.',
            style: const TextStyle(color: Tone.dim, fontSize: 13.5),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (resume.kind == 'hsr') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HsrRunnerScreen(
                              label: resume.label, resumeFrom: resume),
                        ),
                      );
                    } else {
                      final block = model.program!.isoPhase.blocks.firstWhere(
                        (b) => b.id == resume.blockId,
                        orElse: () => model.program!.isoPhase.blocks.first,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IsoRunnerScreen(
                            block: block,
                            label: resume.label,
                            resumeFrom: resume,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Resume'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 108,
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Discard it?'),
                        content: Text(
                          done == 0
                              ? 'Nothing has been logged, so nothing is lost.'
                              : 'The $done logged ${done == 1 ? 'set' : 'sets'} '
                                  'will be thrown away.',
                          style: const TextStyle(color: Tone.dim, height: 1.4),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Keep')),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: Tone.bad,
                                foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Discard'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await model.abandonSession();
                  },
                  child: const Text('Discard'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckInPrompt extends StatelessWidget {
  const _CheckInPrompt();

  @override
  Widget build(BuildContext context) {
    return Panel(
      rail: Tone.action,
      fill: Tone.surfaceHi,
      border: Tone.line,
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CheckInScreen())),
      child: Row(
        children: [
          const Icon(Icons.wb_twilight, color: Tone.text, size: 26),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Morning check-in',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('Ten seconds. It decides the week.',
                    style: TextStyle(color: Tone.dim, fontSize: 13.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Tone.dim),
        ],
      ),
    );
  }
}

class _CheckInDone extends StatelessWidget {
  final CheckIn checkIn;
  const _CheckInDone({required this.checkIn});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CheckInScreen())),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Tone.good, size: 19),
          const SizedBox(width: 10),
          Text('CHECKED IN', style: stencil(12, color: Tone.dim)),
          const Spacer(),
          for (final side in checkIn.verdicts.keys) ...[
            _VerdictPill(side: side, verdict: checkIn.verdicts[side]!),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

Color verdictColor(Verdict v) => switch (v) {
      Verdict.better => Tone.good,
      Verdict.same => Tone.dim,
      Verdict.worse => Tone.bad,
    };

class _VerdictPill extends StatelessWidget {
  final String side;
  final Verdict verdict;
  const _VerdictPill({required this.side, required this.verdict});

  @override
  Widget build(BuildContext context) {
    final c = verdictColor(verdict);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(side,
            style: TextStyle(
                fontFamily: kDisplay,
                color: Tone.side(side),
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 5),
        Text(verdict.name,
            style: TextStyle(
                fontFamily: kDisplay,
                color: c,
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _WorkItem extends StatelessWidget {
  final PlannedItem item;
  final bool blocked;
  const _WorkItem({required this.item, required this.blocked});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final e = model.engine!;

    if (item.done) {
      return Panel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          const Icon(Icons.check_circle, color: Tone.good, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.kind == PlanKind.iso
                  ? '${item.label} · ${item.block!.title}'
                  : item.label,
              style:
                  const TextStyle(color: Tone.dim, fontWeight: FontWeight.w500),
            ),
          ),
          Text('DONE', style: stencil(11, color: Tone.good)),
        ]),
      );
    }

    final subtitle = item.kind == PlanKind.iso
        ? '${item.block!.sets} × ${item.block!.holdSeconds}s each arm'
        : '${e.loadBlock?.scheme ?? ''} · ${e.prescription().length} exercises';

    return Panel(
      fill: Tone.surfaceHi,
      border: Tone.line,
      onTap: blocked
          ? null
          : () {
              if (item.kind == PlanKind.iso) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        IsoRunnerScreen(block: item.block!, label: item.label),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HsrRunnerScreen(label: item.label)),
                );
              }
            },
      child: Row(
        children: [
          // What today actually looks like, before you have opened anything.
          if (item.kind == PlanKind.iso)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: MovementThumb(movementId: item.block!.id, size: 50),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final p in e.prescription().take(3))
                    MovementThumb(movementId: p.exercise.id, size: 38),
                ],
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                      fontSize: 16.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: Tone.dim, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: blocked ? Tone.line : Tone.action,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.play_arrow_rounded,
                color: blocked ? Tone.faint : Tone.onAction, size: 26),
          ),
        ],
      ),
    );
  }
}

class _RestCard extends StatelessWidget {
  final TodayPlan plan;
  const _RestCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final next = plan.nextAvailable;
    String when = '';
    if (next != null) {
      final d = next.difference(DateTime.now());
      if (d.inHours >= 24) {
        when = '${d.inDays}d ${d.inHours % 24}h';
      } else if (d.inHours >= 1) {
        when = '${d.inHours}h ${d.inMinutes % 60}m';
      } else {
        when = '${d.inMinutes}m';
      }
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (next != null)
            Readout(label: 'next session in', value: when, size: 34)
          else
            Row(children: [
              const Icon(Icons.hotel_outlined, color: Tone.dim, size: 20),
              const SizedBox(width: 10),
              Text('NOTHING DUE', style: stencil(14, color: Tone.dim)),
            ]),
          if (plan.blockedReason != null) ...[
            const SizedBox(height: 10),
            Text(plan.blockedReason!,
                style: const TextStyle(
                    color: Tone.dim, height: 1.45, fontSize: 13.5)),
          ],
        ],
      ),
    );
  }
}

class _FlareCard extends StatelessWidget {
  final TodayPlan plan;
  const _FlareCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final f = model.program!.flare;

    return Panel(
      rail: Tone.bad,
      fill: Tone.bad.withValues(alpha: 0.07),
      border: Tone.bad.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.local_fire_department_outlined,
                color: Tone.bad, size: 20),
            const SizedBox(width: 10),
            Text('FLARE PROTOCOL', style: stencil(13, color: Tone.bad)),
            const Spacer(),
            Text('DAY ${plan.flareDay}', style: display(20, color: Tone.bad)),
          ]),
          const SizedBox(height: 10),
          Text(
            'Back to isometrics, twice daily, until the morning baseline '
            'returns. Hold here at least ${f.minDays} days.',
            style: const TextStyle(color: Tone.dim, height: 1.45, fontSize: 13.5),
          ),
          const SizedBox(height: 10),
          Text(f.note,
              style: const TextStyle(
                  color: Tone.faint, fontSize: 12.5, height: 1.45)),
          if (plan.flareNeedsExam) ...[
            const SizedBox(height: 12),
            Panel(
              fill: Tone.bad.withValues(alpha: 0.14),
              border: Tone.bad,
              padding: const EdgeInsets.all(12),
              child: Text(
                'This flare has run ${plan.flareDay} days. The program says a '
                'flare that does not settle within a week needs an exam rather '
                'than another cycle of this.',
                style: const TextStyle(
                    color: Tone.text, fontSize: 13, height: 1.45),
              ),
            ),
          ],
          if (plan.canResumeFromFlare) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Resume loading?'),
                    content: Text(
                      'Phase 2 comes back at ${f.resumePct.toStringAsFixed(0)}% of '
                      'the loads you flared on, rebuilt to where you were across '
                      'the next ${f.rebuildSessions} sessions.',
                      style: const TextStyle(color: Tone.dim, height: 1.45),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Not yet')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Resume')),
                    ],
                  ),
                );
                if (ok == true) await model.resumeFromFlare();
              },
              child: const Text('Baseline is back — resume loading'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoppedCard extends StatelessWidget {
  const _StoppedCard();

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final s = model.state!;
    final last = s.checkIns.isEmpty ? null : s.checkIns.last;

    return Panel(
      rail: Tone.bad,
      fill: Tone.bad.withValues(alpha: 0.12),
      border: Tone.bad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.report_outlined, color: Tone.bad, size: 22),
            const SizedBox(width: 10),
            Text('PROGRAM STOPPED', style: display(24, color: Tone.bad)),
          ]),
          const SizedBox(height: 10),
          const Text(
            'You reported something on the red-flag list. The program stays '
            'stopped until someone has looked at it.',
            style: TextStyle(color: Tone.text, height: 1.45),
          ),
          if (last != null && last.redFlags.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final f in last.redFlags)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Tone.bad)),
                      Expanded(
                          child: Text(f,
                              style: const TextStyle(
                                  color: Tone.dim,
                                  height: 1.4,
                                  fontSize: 13.5))),
                    ]),
              ),
          ],
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Clear the stop?'),
                  content: const Text(
                    'Only do this once it has actually been looked at, or if '
                    'you logged it by mistake.',
                    style: TextStyle(color: Tone.dim, height: 1.45),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Clear')),
                  ],
                ),
              );
              if (ok == true) await model.clearStop();
            },
            child: const Text('Clear the stop'),
          ),
        ],
      ),
    );
  }
}

class _AdvancePhaseCard extends StatelessWidget {
  const _AdvancePhaseCard();

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final e = model.engine!;
    final next = model.program!.nextPhaseAfter(e.phase.id);
    final criteria = e.phase1Criteria();

    return Panel(
      rail: Tone.good,
      fill: Tone.good.withValues(alpha: 0.07),
      border: Tone.good.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.trending_up, color: Tone.good, size: 20),
            const SizedBox(width: 10),
            Text('READY FOR ${(next?.title ?? 'THE NEXT PHASE').toUpperCase()}',
                style: stencil(12.5, color: Tone.good)),
          ]),
          const SizedBox(height: 12),
          for (final c in criteria)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(c.met ? Icons.check_circle : Icons.circle_outlined,
                      size: 17, color: c.met ? Tone.good : Tone.faint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.criterion.label,
                            style: const TextStyle(fontSize: 13.5)),
                        if (c.detail.isNotEmpty)
                          Text(c.detail,
                              style: const TextStyle(
                                  color: Tone.faint, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('One call left'),
                  content: const Text(
                    'Is your morning baseline pain genuinely lower than when '
                    'you started? This is the one criterion the app cannot '
                    'work out from the log.',
                    style: TextStyle(color: Tone.dim, height: 1.45),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Not yet')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Yes, it is better')),
                  ],
                ),
              );
              if (ok != true) return;
              await model.confirmBaselineDown(true);
              await model.advancePhase();
            },
            child: Text('Start ${next?.title ?? 'next phase'}'),
          ),
        ],
      ),
    );
  }
}

class _CalibrateCard extends StatelessWidget {
  const _CalibrateCard();

  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context).engine!;
    final block = e.loadBlock;
    return Panel(
      rail: Tone.hold,
      fill: Tone.hold.withValues(alpha: 0.07),
      border: Tone.hold.withValues(alpha: 0.4),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CalibrateScreen())),
      child: Row(
        children: [
          const Icon(Icons.tune, color: Tone.hold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set your working loads',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'The scheme is ${block?.scheme ?? ''} at your ${block?.target ?? 'rep max'}.',
                  style: const TextStyle(color: Tone.dim, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Tone.dim),
        ],
      ),
    );
  }
}

/// Ten days of mornings, both arms. The asymmetry is the story of this
/// program, so it is on the home screen rather than buried in a chart.
class _MorningStrip extends StatelessWidget {
  const _MorningStrip();

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final s = model.state!;
    final sides = model.program!.sides;
    final today = dayOnly(DateTime.now());
    final days = List.generate(10, (i) => today.subtract(Duration(days: 9 - i)));

    return Column(
      children: [
        for (final side in sides) ...[
          Row(
            children: [
              SideChip(side),
              const SizedBox(width: 10),
              for (final d in days) ...[
                Expanded(child: _Dot(checkIn: s.checkInOn(ymd(d)), side: side)),
                const SizedBox(width: 4),
              ],
            ],
          ),
          if (side != sides.last) const SizedBox(height: 7),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 32),
            for (final d in days) ...[
              Expanded(
                child: Text('${d.day}',
                    textAlign: TextAlign.center, style: stencil(10.5)),
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final CheckIn? checkIn;
  final String side;
  const _Dot({required this.checkIn, required this.side});

  @override
  Widget build(BuildContext context) {
    final v = checkIn?.verdicts[side];
    final color = v == null ? Tone.line : verdictColor(v);
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: v == null ? Colors.transparent : color.withValues(alpha: 0.8),
        border: Border.all(color: v == null ? Tone.line : color),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
