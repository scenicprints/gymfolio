import 'package:flutter/material.dart';

import '../app.dart';
import '../state.dart';
import '../theme.dart';

/// The record, in the order it matters: where you are in the block, what the
/// loads have done, and then the session log itself — which is the table the
/// written program asks you to keep, and the thing worth handing to a physio.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final e = model.engine!;
    final s = model.state!;
    final p = model.program!;

    final totalWeeks = p.phases.fold<int>(0, (a, ph) => a + ph.nominalWeeks);
    final sessions = s.sessions.reversed.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const SectionLabel('The block'),
        Panel(child: _WeekLadder(totalWeeks: totalWeeks)),
        const SizedBox(height: 20),

        if (e.phase.exercises.isNotEmpty) ...[
          const SectionLabel('Loads'),
          for (final ex in e.phase.exercises) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (final side in ex.sidesFor(p.sides))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LoadRow(
                        exerciseId: ex.id,
                        side: side,
                        unit: ex.unit,
                      ),
                    ),
                  if (!ex.unilateral)
                    const Text(
                      'One bar, one load — the right arm gates this lift.',
                      style: TextStyle(color: Tone.faint, fontSize: 11.5),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
        ],

        const SectionLabel('Session log'),
        if (sessions.isEmpty)
          const Panel(
            child: Text('Nothing logged yet.',
                style: TextStyle(color: Tone.dim)),
          )
        else
          for (final sess in sessions.take(60))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SessionRow(session: sess),
            ),
      ],
    );
  }
}

class _WeekLadder extends StatelessWidget {
  final int totalWeeks;
  const _WeekLadder({required this.totalWeeks});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final e = model.engine!;
    final s = model.state!;
    final current = e.docWeek;

    final flareWeeks = <int>{};
    for (final f in s.flares) {
      flareWeeks.add(f.phaseWeek + e.phase.weekOffset);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var w = 1; w <= totalWeeks; w++)
              _WeekChip(
                week: w,
                state: w < current
                    ? _WeekState.done
                    : w == current
                        ? _WeekState.current
                        : _WeekState.future,
                flared: flareWeeks.contains(w),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.phase.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    'Started ${s.startDate} · day ${e.daysSinceStart(DateTime.now()) + 1}',
                    style: const TextStyle(color: Tone.faint, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (s.flares.isNotEmpty)
              Text('${s.flares.length} flare${s.flares.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Tone.bad, fontSize: 12.5)),
          ],
        ),
      ],
    );
  }
}

enum _WeekState { done, current, future }

class _WeekChip extends StatelessWidget {
  final int week;
  final _WeekState state;
  final bool flared;
  const _WeekChip(
      {required this.week, required this.state, required this.flared});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (state) {
      _WeekState.done => (Tone.good.withValues(alpha: 0.18), Tone.good, Tone.good.withValues(alpha: 0.4)),
      _WeekState.current => (Tone.accent, Colors.black, Tone.accent),
      _WeekState.future => (Colors.transparent, Tone.faint, Tone.line),
    };
    return Stack(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Text('$week',
              style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ),
        if (flared)
          Positioned(
            right: 3,
            top: 3,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: Tone.bad, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}

class _LoadRow extends StatelessWidget {
  final String exerciseId;
  final String side;
  final String unit;
  const _LoadRow(
      {required this.exerciseId, required this.side, required this.unit});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final e = model.engine!;
    final history = e.loadHistory(exerciseId, side);
    final current = model.state!.loadFor(exerciseId, side);
    final first = history.isEmpty ? current : history.first.load;
    final delta = current - first;

    return Row(
      children: [
        if (side == 'BOTH')
          const SizedBox(
            width: 30,
            child: Text('BAR',
                style: TextStyle(
                    color: Tone.faint, fontSize: 10, fontWeight: FontWeight.w800)),
          )
        else
          SizedBox(width: 30, child: SideChip(side)),
        const SizedBox(width: 6),
        SizedBox(
          width: 66,
          child: Text(
            current > 0
                ? '${current.toStringAsFixed(current % 1 == 0 ? 0 : 1)} $unit'
                : '—',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 30,
            child: CustomPaint(
              painter: _Spark(
                values: history.map((h) => h.load).toList(),
                color: side == 'BOTH' ? Tone.dim : Tone.side(side),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(
            history.length < 2
                ? ''
                : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(delta % 1 == 0 ? 0 : 1)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: delta > 0 ? Tone.good : (delta < 0 ? Tone.bad : Tone.faint),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Spark extends CustomPainter {
  final List<double> values;
  final Color color;
  _Spark({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).abs() < 0.01 ? 1.0 : hi - lo;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - lo) / span) * (size.height - 6) - 3;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Spark old) => old.values != values;
}

class _SessionRow extends StatelessWidget {
  final SessionLog session;
  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final after = model.engine!.morningAfter(session);

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(session.date,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(width: 8),
              Text(session.label,
                  style: const TextStyle(color: Tone.dim, fontSize: 13)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Tone.surfaceHi,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(session.kind == 'iso' ? 'ISO' : 'HSR',
                    style: const TextStyle(
                        color: Tone.faint,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Pain ',
                  style: TextStyle(color: Tone.faint, fontSize: 12)),
              for (final entry in session.painDuring.entries) ...[
                SideChip(entry.key, size: 17),
                const SizedBox(width: 4),
                Text('${entry.value.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: entry.value <= 4 ? Tone.text : Tone.bad,
                    )),
                const SizedBox(width: 12),
              ],
              const Spacer(),
              if (after == null)
                const Text('next morning pending',
                    style: TextStyle(color: Tone.faint, fontSize: 11.5))
              else
                Row(children: [
                  const Text('24h ',
                      style: TextStyle(color: Tone.faint, fontSize: 11.5)),
                  for (final v in after.verdicts.entries) ...[
                    Container(
                      margin: const EdgeInsets.only(left: 3),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (v.value) {
                          Verdict.better => Tone.good,
                          Verdict.same => Tone.dim,
                          Verdict.worse => Tone.bad,
                        },
                      ),
                    ),
                  ],
                ]),
            ],
          ),
          if (session.sets.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _summarise(session),
              style: const TextStyle(color: Tone.dim, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  String _summarise(SessionLog s) {
    final byEx = <String, List<SetEntry>>{};
    for (final e in s.sets) {
      (byEx[e.exerciseId] ??= []).add(e);
    }
    return byEx.entries.map((e) {
      final loads = e.value.map((x) => x.load).toSet().toList()..sort();
      return '${e.key} ${loads.map((l) => l.toStringAsFixed(l % 1 == 0 ? 0 : 1)).join('/')}';
    }).join(' · ');
  }
}
