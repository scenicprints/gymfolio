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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _Header(),
        const SizedBox(height: 16),

        if (plan.stopped) ...[
          _StoppedCard(),
          const SizedBox(height: 16),
        ] else ...[
          if (plan.needsCheckIn) ...[
            _CheckInPrompt(),
            const SizedBox(height: 12),
          ] else
            _CheckInDone(checkIn: s.checkInOn(ymd(now))!),

          if (plan.inFlare) ...[
            const SizedBox(height: 12),
            _FlareCard(plan: plan),
          ],

          if (!plan.inFlare && plan.readyToAdvancePhase) ...[
            const SizedBox(height: 12),
            _AdvancePhaseCard(),
          ],

          if (!plan.inFlare && plan.needsCalibration) ...[
            const SizedBox(height: 12),
            _CalibrateCard(),
          ],

          const SizedBox(height: 20),
          const SectionLabel('Today'),
          if (plan.items.isEmpty)
            _RestCard(plan: plan)
          else
            ...plan.items.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WorkItem(item: i, blocked: plan.needsCalibration),
                )),
        ],

        const SizedBox(height: 24),
        const SectionLabel('Last 10 mornings'),
        Panel(child: _MorningStrip()),
        const SizedBox(height: 16),
        Text(
          p.governing.notes.first,
          style: const TextStyle(color: Tone.faint, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final e = model.engine!;
    final s = model.state!;
    final phase = e.phase;
    final block = e.loadBlock;
    final day = e.daysSinceStart(DateTime.now()) + 1;

    final badge = switch (s.mode) {
      kModeFlare => ('FLARE', Tone.bad),
      kModeStopped => ('STOPPED', Tone.bad),
      _ => (e.isMaintenance ? 'MAINTENANCE' : 'ON PROGRAM', Tone.good),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Week ${e.docWeek}',
              style: const TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badge.$2.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badge.$2.withValues(alpha: 0.5)),
              ),
              child: Text(badge.$1,
                  style: TextStyle(
                      color: badge.$2,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
            ),
            const Spacer(),
            Text('Day $day',
                style: const TextStyle(color: Tone.faint, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          block == null
              ? phase.title
              : '${phase.title} · ${block.scheme} @ ${block.target}',
          style: const TextStyle(color: Tone.dim, fontSize: 14),
        ),
      ],
    );
  }
}

class _CheckInPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Panel(
      fill: Tone.accent.withValues(alpha: 0.10),
      border: Tone.accent.withValues(alpha: 0.5),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CheckInScreen())),
      child: Row(
        children: [
          const Icon(Icons.wb_twilight, color: Tone.accent, size: 26),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Morning check-in',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Ten seconds. It decides the week.',
                    style: TextStyle(color: Tone.dim, fontSize: 13)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CheckInScreen())),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Tone.good, size: 20),
          const SizedBox(width: 10),
          const Text('Checked in',
              style: TextStyle(fontWeight: FontWeight.w600)),
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

class _VerdictPill extends StatelessWidget {
  final String side;
  final Verdict verdict;
  const _VerdictPill({required this.side, required this.verdict});

  static Color colorOf(Verdict v) => switch (v) {
        Verdict.better => Tone.good,
        Verdict.same => Tone.dim,
        Verdict.worse => Tone.bad,
      };

  static String labelOf(Verdict v) => switch (v) {
        Verdict.better => 'better',
        Verdict.same => 'same',
        Verdict.worse => 'worse',
      };

  @override
  Widget build(BuildContext context) {
    final c = colorOf(verdict);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(side,
            style: TextStyle(
                color: Tone.side(side),
                fontSize: 11,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 5),
        Text(labelOf(verdict),
            style: TextStyle(
                color: c, fontSize: 11.5, fontWeight: FontWeight.w600)),
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
          const Icon(Icons.check_circle, color: Tone.good, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.kind == PlanKind.iso
                  ? '${item.label} · ${item.block!.title}'
                  : item.label,
              style: const TextStyle(color: Tone.dim, fontWeight: FontWeight.w600),
            ),
          ),
          const Text('done',
              style: TextStyle(color: Tone.faint, fontSize: 12)),
        ]),
      );
    }

    final subtitle = item.kind == PlanKind.iso
        ? '${item.block!.sets} x ${item.block!.holdSeconds}s each arm · ${item.block!.effort}'
        : '${e.loadBlock?.scheme ?? ''} · ${e.phase.tempo} · '
            '${e.prescription().length} exercises';

    return Panel(
      fill: Tone.surfaceHi,
      onTap: blocked
          ? null
          : () {
              if (item.kind == PlanKind.iso) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IsoRunnerScreen(
                        block: item.block!, label: item.label),
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
              padding: const EdgeInsets.only(right: 10),
              child: MovementThumb(movementId: item.block!.id, size: 48),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 6),
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
                  item.kind == PlanKind.iso
                      ? '${item.label} · ${item.block!.title}'
                      : item.label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(color: Tone.dim, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: blocked ? Tone.line : Tone.accent,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Icon(Icons.play_arrow_rounded,
                color: blocked ? Tone.faint : Colors.black, size: 26),
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
        when = 'in ${d.inDays}d ${d.inHours % 24}h';
      } else if (d.inHours >= 1) {
        when = 'in ${d.inHours}h ${d.inMinutes % 60}m';
      } else {
        when = 'in ${d.inMinutes}m';
      }
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.hotel_outlined, color: Tone.dim, size: 20),
            const SizedBox(width: 10),
            Text(next != null ? 'Next session $when' : 'Nothing due',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          if (plan.blockedReason != null) ...[
            const SizedBox(height: 8),
            Text(plan.blockedReason!,
                style: const TextStyle(color: Tone.dim, height: 1.4)),
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
      fill: Tone.bad.withValues(alpha: 0.08),
      border: Tone.bad.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.local_fire_department_outlined,
                color: Tone.bad, size: 20),
            const SizedBox(width: 10),
            Text('Flare protocol · day ${plan.flareDay}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Tone.bad)),
          ]),
          const SizedBox(height: 10),
          Text(
            'Back to isometrics, twice daily, until the morning baseline '
            'returns. Hold here at least ${f.minDays} days.',
            style: const TextStyle(color: Tone.dim, height: 1.45),
          ),
          const SizedBox(height: 10),
          Text(f.note,
              style: const TextStyle(color: Tone.faint, fontSize: 12.5, height: 1.4)),
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
                    color: Tone.text, fontSize: 13, height: 1.4),
              ),
            ),
          ],
          if (plan.canResumeFromFlare) ...[
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Tone.good),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: Tone.surface,
                    title: const Text('Resume loading?'),
                    content: Text(
                      'Phase 2 comes back at ${f.resumePct.toStringAsFixed(0)}% of the '
                      'loads you flared on, rebuilt to where you were across the '
                      'next ${f.rebuildSessions} sessions.',
                      style: const TextStyle(color: Tone.dim, height: 1.4),
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
  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final s = model.state!;
    final last = s.checkIns.isEmpty ? null : s.checkIns.last;

    return Panel(
      fill: Tone.bad.withValues(alpha: 0.12),
      border: Tone.bad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.report_outlined, color: Tone.bad, size: 22),
            SizedBox(width: 10),
            Text('Program stopped',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: Tone.bad)),
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
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('• ', style: TextStyle(color: Tone.bad)),
                  Expanded(
                      child: Text(f,
                          style: const TextStyle(
                              color: Tone.dim, height: 1.35, fontSize: 13.5))),
                ]),
              ),
          ],
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: Tone.surface,
                  title: const Text('Clear the stop?'),
                  content: const Text(
                    'Only do this once it has actually been looked at, or if '
                    'you logged it by mistake.',
                    style: TextStyle(color: Tone.dim, height: 1.4),
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
  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final e = model.engine!;
    final next = model.program!.nextPhaseAfter(e.phase.id);
    final criteria = e.phase1Criteria();

    return Panel(
      fill: Tone.good.withValues(alpha: 0.09),
      border: Tone.good.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.trending_up, color: Tone.good, size: 20),
            const SizedBox(width: 10),
            Text('Ready for ${next?.title ?? 'the next phase'}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Tone.good)),
          ]),
          const SizedBox(height: 12),
          for (final c in criteria)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(c.met ? Icons.check_circle : Icons.circle_outlined,
                      size: 17, color: c.met ? Tone.good : Tone.faint),
                  const SizedBox(width: 9),
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
            style: FilledButton.styleFrom(backgroundColor: Tone.good),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: Tone.surface,
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
  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context).engine!;
    final block = e.loadBlock;
    return Panel(
      fill: Tone.hold.withValues(alpha: 0.09),
      border: Tone.hold.withValues(alpha: 0.5),
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
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  'The scheme is ${block?.scheme ?? ''} at your ${block?.target ?? 'rep max'}. '
                  'Pick the weights before you start.',
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
          if (side != sides.last) const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 32),
            for (final d in days) ...[
              Expanded(
                child: Text(
                  '${d.day}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Tone.faint, fontSize: 10),
                ),
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
    final color = v == null
        ? Tone.line
        : switch (v) {
            Verdict.better => Tone.good,
            Verdict.same => Tone.dim,
            Verdict.worse => Tone.bad,
          };
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: v == null ? Colors.transparent : color.withValues(alpha: 0.75),
        border: Border.all(color: v == null ? Tone.line : color),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
