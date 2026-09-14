import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../exercise_art.dart';
import '../program.dart';
import '../state.dart';
import '../theme.dart';
import 'how_to.dart';
import 'pain_sheet.dart';

/// Phase 1 is a timer, and so is the flare protocol. Arms alternate inside the
/// rest interval — left hold, right hold, rest — which still leaves each arm
/// the full two minutes between its own efforts and halves the time standing
/// around.

enum _Stage { ready, ramp, hold, rest, done }

class IsoRunnerScreen extends StatefulWidget {
  final IsoBlock block;
  final String label;
  const IsoRunnerScreen({super.key, required this.block, required this.label});

  @override
  State<IsoRunnerScreen> createState() => _IsoRunnerScreenState();
}

class _IsoRunnerScreenState extends State<IsoRunnerScreen> {
  Timer? _timer;
  _Stage _stage = _Stage.ready;
  int _set = 1;
  int _sideIndex = 0;
  double _remaining = 0;
  bool _running = false;

  List<String> _sides = const ['L', 'R'];

  IsoBlock get b => widget.block;
  String get side => _sides[_sideIndex];
  bool get isLastSide => _sideIndex >= _sides.length - 1;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    setState(() {
      _remaining -= 0.1;
      if (_remaining <= 0) _next();
    });
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    _running = true;
  }

  void _pause() {
    _timer?.cancel();
    _running = false;
    setState(() {});
  }

  void _beginRamp() {
    setState(() {
      _stage = _Stage.ramp;
      _remaining = b.rampSeconds.toDouble();
    });
    HapticFeedback.mediumImpact();
    _start();
  }

  void _next() {
    switch (_stage) {
      case _Stage.ramp:
        _stage = _Stage.hold;
        _remaining = b.holdSeconds.toDouble();
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
        break;

      case _Stage.hold:
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
        if (!isLastSide) {
          // Straight into the other arm; its hold is the first half of this
          // arm's rest.
          _sideIndex++;
          _stage = _Stage.ramp;
          _remaining = b.rampSeconds.toDouble();
        } else if (_set >= b.sets) {
          _stage = _Stage.done;
          _timer?.cancel();
          _running = false;
        } else {
          _sideIndex = 0;
          _stage = _Stage.rest;
          _remaining = b.restSeconds.toDouble();
        }
        break;

      case _Stage.rest:
        _set++;
        _stage = _Stage.ramp;
        _remaining = b.rampSeconds.toDouble();
        HapticFeedback.mediumImpact();
        break;

      default:
        break;
    }
  }

  void _skip() {
    setState(() {
      _remaining = 0;
      _next();
    });
  }

  Future<void> _finish() async {
    final model = AppScope.of(context);
    final pain = await showPainSheet(context, _sides);
    if (pain == null) return;

    final now = DateTime.now();
    await model.finishSession(SessionLog(
      id: '${now.microsecondsSinceEpoch}',
      date: ymd(now),
      at: now.toIso8601String(),
      phaseId: model.engine!.phase.id,
      phaseWeek: model.state!.phaseWeek,
      kind: 'iso',
      blockId: b.id,
      label: widget.label,
      painDuring: pain,
      sets: const [],
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    _sides = AppScope.of(context).program!.sides;

    final total = switch (_stage) {
      _Stage.ramp => b.rampSeconds.toDouble(),
      _Stage.hold => b.holdSeconds.toDouble(),
      _Stage.rest => b.restSeconds.toDouble(),
      _ => 1.0,
    };
    final progress = _stage == _Stage.ready || _stage == _Stage.done
        ? 0.0
        : (1 - (_remaining / total)).clamp(0.0, 1.0);

    final (title, color) = switch (_stage) {
      _Stage.ready => ('Ready', Tone.dim),
      _Stage.ramp => ('Build tension', Tone.hold),
      _Stage.hold => ('HOLD', Tone.good),
      _Stage.rest => ('Rest', Tone.accent),
      _Stage.done => ('Done', Tone.good),
    };

    return Scaffold(
      appBar: AppBar(title: Text('${widget.label} · ${b.title}')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Set $_set of ${b.sets}',
                    style: const TextStyle(
                        color: Tone.dim, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                if (_stage != _Stage.done && _stage != _Stage.rest)
                  SideChip(side, size: 26),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: Center(
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Before the timer starts there is no progress to show,
                      // so the ring is just a grey donut in the way of the
                      // thing you actually want: how to hold the position.
                      if (_stage != _Stage.ready)
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 14,
                            backgroundColor: Tone.surfaceHi,
                            valueColor: AlwaysStoppedAnimation(color),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                      if (_stage == _Stage.ready)
                        SizedBox(
                          width: 300,
                          height: 268,
                          child: MovementDemo(
                            movementId: b.id,
                            upSeconds: 0,
                            downSeconds: 0,
                            height: 268,
                          ),
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2)),
                            const SizedBox(height: 4),
                            Text(
                              _stage == _Stage.done
                                  ? '✓'
                                  : _remaining.ceil().toString(),
                              style: const TextStyle(
                                  fontSize: 78,
                                  fontWeight: FontWeight.w200,
                                  height: 1.0,
                                  fontFeatures: [FontFeature.tabularFigures()]),
                            ),
                            if (_stage != _Stage.done)
                              const Text('seconds',
                                  style: TextStyle(
                                      color: Tone.faint, fontSize: 13)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            if (_stage == _Stage.ready) ...[
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              '${b.sets} x ${b.holdSeconds}s at ${b.effort}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                        HowToButton(
                          size: 28,
                          onTap: () => showHowTo(
                            context,
                            movementId: b.id,
                            title: b.title,
                            steps: b.howTo,
                            upSeconds: 0,
                            downSeconds: 0,
                            scheme:
                                '${b.sets} x ${b.holdSeconds}s each arm, ${b.timesPerDay}x daily',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final c in b.cues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('· ', style: TextStyle(color: Tone.faint)),
                            Expanded(
                              child: Text(c,
                                  style: const TextStyle(
                                      color: Tone.dim,
                                      fontSize: 13,
                                      height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_stage == _Stage.done)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Tone.good),
                onPressed: _finish,
                child: const Text('Log it'),
              )
            else if (_stage == _Stage.ready)
              FilledButton(onPressed: _beginRamp, child: const Text('Start'))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _running ? _pause() : _start(),
                      child: Text(_running ? 'Pause' : 'Resume'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _skip,
                      child: const Text('Skip'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
