import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../exercise_art.dart';
import '../program.dart';
import '../session_hw.dart';
import '../state.dart';
import '../theme.dart';
import 'how_to.dart';
import 'pain_sheet.dart';

/// Phase 1 is a timer, and so is the flare protocol. Arms alternate inside the
/// rest interval — left hold, right hold, rest — which still leaves each arm
/// its full two minutes between its own efforts and halves the time standing
/// around.

enum _Stage { ready, ramp, hold, rest, done }

class IsoRunnerScreen extends StatefulWidget {
  final IsoBlock block;
  final String label;
  final InProgress? resumeFrom;

  const IsoRunnerScreen({
    super.key,
    required this.block,
    required this.label,
    this.resumeFrom,
  });

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
  void initState() {
    super.initState();
    SessionHw.keepAwake();
    SessionHw.warmUp();
    final r = widget.resumeFrom;
    if (r != null) _set = (r.position + 1).clamp(1, b.sets);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SessionHw.letSleep();
    super.dispose();
  }

  InProgress _snapshot(AppModel model) => InProgress(
        kind: 'iso',
        blockId: b.id,
        label: widget.label,
        phaseId: model.engine!.phase.id,
        phaseWeek: model.state!.phaseWeek,
        startedAt:
            widget.resumeFrom?.startedAt ?? DateTime.now().toIso8601String(),
        position: _set - 1,
        sets: const [],
      );

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

  Future<void> _beginRamp(AppModel model) async {
    setState(() {
      _stage = _Stage.ramp;
      _remaining = b.rampSeconds.toDouble();
    });
    SessionHw.soft();
    _start();
    await model.beginSession(_snapshot(model));
  }

  void _next() {
    switch (_stage) {
      case _Stage.ramp:
        _stage = _Stage.hold;
        _remaining = b.holdSeconds.toDouble();
        SessionHw.rep();
        break;

      case _Stage.hold:
        SessionHw.done();
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
        SessionHw.soft();
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

  Future<void> _finish(AppModel model) async {
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
    final model = AppScope.of(context);
    _sides = model.program!.sides;

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
      _Stage.ready => ('READY', Tone.dim),
      _Stage.ramp => ('BUILD TENSION', Tone.hold),
      _Stage.hold => ('HOLD', Tone.good),
      _Stage.rest => ('REST', Tone.accent),
      _Stage.done => ('DONE', Tone.good),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$_set/${b.sets}',
                  style: display(16, color: Tone.dim)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('SET $_set OF ${b.sets}', style: stencil(13, color: Tone.dim)),
                if (_stage != _Stage.done && _stage != _Stage.rest) ...[
                  const SizedBox(width: 12),
                  SideChip(side, size: 26),
                ],
              ],
            ),
            const SizedBox(height: 18),

            Expanded(
              child: Center(
                child: _stage == _Stage.ready
                    ? SizedBox(
                        height: 280,
                        child: MovementDemo(
                          movementId: b.id,
                          upSeconds: 0,
                          downSeconds: 0,
                          height: 280,
                        ),
                      )
                    : SizedBox(
                        width: 268,
                        height: 268,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 268,
                              height: 268,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 12,
                                backgroundColor: Tone.surface,
                                valueColor: AlwaysStoppedAnimation(color),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(title, style: stencil(13, color: color)),
                                const SizedBox(height: 6),
                                Text(
                                  _stage == _Stage.done
                                      ? '✓'
                                      : _remaining.ceil().toString(),
                                  style: display(96),
                                ),
                                if (_stage != _Stage.done)
                                  Text('SECONDS', style: stencil(11)),
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
                            '${b.sets} × ${b.holdSeconds}s at ${b.effort}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
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
                                '${b.sets} × ${b.holdSeconds}s each arm, ${b.timesPerDay}× daily',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final c in b.cues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('· ',
                                style: TextStyle(color: Tone.faint)),
                            Expanded(
                              child: Text(c,
                                  style: const TextStyle(
                                      color: Tone.dim,
                                      fontSize: 13,
                                      height: 1.4)),
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
                onPressed: () => _finish(model),
                child: const Text('Log it'),
              )
            else if (_stage == _Stage.ready)
              FilledButton(
                onPressed: () => _beginRamp(model),
                child: Text(_set > 1 ? 'Resume at set $_set' : 'Start'),
              )
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
