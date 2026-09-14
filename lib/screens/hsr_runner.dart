import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../program.dart';
import '../state.dart';
import '../theme.dart';
import 'pain_sheet.dart';

/// Heavy slow resistance. The tempo is the intervention, not a detail: three
/// seconds up, three seconds down, and a weight you cannot control for three
/// seconds down is the wrong weight. So the metronome runs the set and the
/// rep counter follows it.

class _Task {
  final Exercise exercise;
  final int setIndex;
  final int totalSets;
  final String side;
  final int targetReps;
  final int restSeconds;
  final String? cue;

  const _Task({
    required this.exercise,
    required this.setIndex,
    required this.totalSets,
    required this.side,
    required this.targetReps,
    required this.restSeconds,
    this.cue,
  });
}

enum _Stage { warmup, ready, lifting, logging, resting, done }

class HsrRunnerScreen extends StatefulWidget {
  final String label;
  const HsrRunnerScreen({super.key, required this.label});

  @override
  State<HsrRunnerScreen> createState() => _HsrRunnerScreenState();
}

class _HsrRunnerScreenState extends State<HsrRunnerScreen> {
  final List<_Task> _tasks = [];
  final List<SetEntry> _logged = [];
  bool _built = false;

  int _index = 0;
  _Stage _stage = _Stage.warmup;

  Timer? _timer;
  bool _running = false;

  // Tempo state
  double _phaseLeft = 0;
  bool _goingUp = true;
  int _reps = 0;

  // Rest state
  double _restLeft = 0;

  int _loggedReps = 0;
  final Map<String, double> _loadOverride = {};

  Tempo _tempo = const Tempo(3, 3);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _build(AppModel model) {
    if (_built) return;
    _built = true;
    final e = model.engine!;
    _tempo = e.phase.tempo;
    for (final p in e.prescription()) {
      for (var s = 1; s <= p.sets; s++) {
        for (final side in p.sides) {
          _tasks.add(_Task(
            exercise: p.exercise,
            setIndex: s,
            totalSets: p.sets,
            side: side,
            targetReps: p.reps,
            restSeconds: p.restSeconds,
            cue: p.cue,
          ));
        }
      }
    }
  }

  _Task get task => _tasks[_index];

  String _loadKey(_Task t) => '${t.exercise.id}|${t.side}';

  double _loadOf(_Task t, AppModel model) =>
      _loadOverride[_loadKey(t)] ?? model.state!.loadFor(t.exercise.id, t.side);

  // ------------------------------------------------------------- tempo loop

  void _startSet() {
    setState(() {
      _stage = _Stage.lifting;
      _reps = 0;
      _goingUp = true;
      _phaseLeft = _tempo.up.toDouble();
    });
    HapticFeedback.mediumImpact();
    _tick(start: true);
  }

  void _tick({bool start = false}) {
    _timer?.cancel();
    _running = true;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _phaseLeft -= 0.1;
        if (_phaseLeft <= 0) {
          if (_goingUp) {
            _goingUp = false;
            _phaseLeft = _tempo.down.toDouble();
            HapticFeedback.lightImpact();
          } else {
            _reps++;
            _goingUp = true;
            _phaseLeft = _tempo.up.toDouble();
            HapticFeedback.heavyImpact();
            SystemSound.play(SystemSoundType.click);
            if (_reps >= task.targetReps) _endSet();
          }
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _endSet() {
    _timer?.cancel();
    _running = false;
    setState(() {
      _loggedReps = _reps;
      _stage = _Stage.logging;
    });
    HapticFeedback.heavyImpact();
  }

  void _confirmSet(AppModel model) {
    _logged.add(SetEntry(
      exerciseId: task.exercise.id,
      setIndex: task.setIndex,
      side: task.side,
      load: _loadOf(task, model),
      reps: _loggedReps,
    ));

    final last = _index >= _tasks.length - 1;
    if (last) {
      setState(() => _stage = _Stage.done);
      return;
    }

    // Rest only after the final side of a set — the other arm's work is not
    // rest, but going straight from left to right is how the set is done.
    final next = _tasks[_index + 1];
    final sameSet = next.exercise.id == task.exercise.id &&
        next.setIndex == task.setIndex;

    setState(() {
      _index++;
      if (sameSet) {
        _stage = _Stage.ready;
      } else {
        _stage = _Stage.resting;
        _restLeft = task.restSeconds.toDouble();
        _startRest();
      }
    });
  }

  void _startRest() {
    _timer?.cancel();
    _running = true;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _restLeft -= 0.1;
        if (_restLeft <= 0) {
          _timer?.cancel();
          _running = false;
          _stage = _Stage.ready;
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.click);
        }
      });
    });
  }

  Future<void> _finish(AppModel model) async {
    final sides = model.program!.sides;
    final pain = await showPainSheet(context, sides);
    if (pain == null) return;
    final now = DateTime.now();
    await model.finishSession(SessionLog(
      id: '${now.microsecondsSinceEpoch}',
      date: ymd(now),
      at: now.toIso8601String(),
      phaseId: model.engine!.phase.id,
      phaseWeek: model.state!.phaseWeek,
      kind: 'hsr',
      blockId: '',
      label: widget.label,
      painDuring: pain,
      sets: List.of(_logged),
    ));
    if (mounted) Navigator.pop(context);
  }

  // ------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    _build(model);

    if (_tasks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.label)),
        body: const Center(child: Text('No exercises prescribed.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.label),
        actions: [
          if (_stage != _Stage.warmup && _stage != _Stage.done)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Text('${_index + 1}/${_tasks.length}',
                    style: const TextStyle(color: Tone.dim, fontSize: 13)),
              ),
            ),
        ],
      ),
      body: switch (_stage) {
        _Stage.warmup => _warmup(model),
        _Stage.done => _done(model),
        _ => _work(model),
      },
    );
  }

  Widget _warmup(AppModel model) {
    final phase = model.engine!.phase;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const SectionLabel('Warm-up'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < phase.warmup.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}. ',
                          style: const TextStyle(
                              color: Tone.faint, fontWeight: FontWeight.w700)),
                      Expanded(
                        child: Text(phase.warmup[i],
                            style: const TextStyle(height: 1.4, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Today'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in model.engine!.prescription()) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(p.exercise.title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text('${p.sets} x ${p.reps}',
                        style: const TextStyle(color: Tone.dim)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final side in p.sides) ...[
                      if (side == 'BOTH')
                        Text('${p.loads[side]?.toStringAsFixed(1) ?? '—'} ${p.exercise.unit}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700))
                      else ...[
                        SideChip(side, size: 20),
                        const SizedBox(width: 6),
                        Text('${p.loads[side]?.toStringAsFixed(1) ?? '—'}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 14),
                      ],
                    ],
                  ],
                ),
                if (p.cue != null) ...[
                  const SizedBox(height: 4),
                  Text(p.cue!,
                      style: const TextStyle(color: Tone.accent, fontSize: 12.5)),
                ],
                const SizedBox(height: 14),
              ],
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(model.engine!.phase.tempoNote,
                  style: const TextStyle(
                      color: Tone.dim, fontSize: 12.5, height: 1.45)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => setState(() => _stage = _Stage.ready),
          child: const Text('Warm-up done — start'),
        ),
      ],
    );
  }

  Widget _work(AppModel model) {
    final t = task;
    final load = _loadOf(t, model);
    final unit = t.exercise.unit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          Panel(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(t.exercise.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    if (t.side != 'BOTH') SideChip(t.side, size: 24),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Set ${t.setIndex} of ${t.totalSets} · target ${t.targetReps} reps',
                    style: const TextStyle(color: Tone.dim, fontSize: 13)),
                if (t.cue != null) ...[
                  const SizedBox(height: 4),
                  Text(t.cue!,
                      style:
                          const TextStyle(color: Tone.accent, fontSize: 12.5)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: _stage == _Stage.lifting
                          ? null
                          : () => setState(() => _loadOverride[_loadKey(t)] =
                              (load - 2.5).clamp(0, 999)),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Tone.dim,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${load.toStringAsFixed(load % 1 == 0 ? 0 : 1)} $unit',
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _stage == _Stage.lifting
                          ? null
                          : () => setState(() =>
                              _loadOverride[_loadKey(t)] = load + 2.5),
                      icon: const Icon(Icons.add_circle_outline),
                      color: Tone.dim,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(child: Center(child: _centre(model))),

          if (_stage == _Stage.ready)
            FilledButton(onPressed: _startSet, child: const Text('Start set'))
          else if (_stage == _Stage.lifting)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _running ? _pause() : _tick(),
                    child: Text(_running ? 'Pause' : 'Resume'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _endSet,
                    child: const Text('End set'),
                  ),
                ),
              ],
            )
          else if (_stage == _Stage.logging)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => setState(
                          () => _loggedReps = (_loggedReps - 1).clamp(0, 99)),
                      icon: const Icon(Icons.remove_circle_outline, size: 30),
                      color: Tone.dim,
                    ),
                    const SizedBox(width: 8),
                    Column(children: [
                      Text('$_loggedReps',
                          style: const TextStyle(
                              fontSize: 40, fontWeight: FontWeight.w800)),
                      const Text('reps',
                          style: TextStyle(color: Tone.faint, fontSize: 12)),
                    ]),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _loggedReps++),
                      icon: const Icon(Icons.add_circle_outline, size: 30),
                      color: Tone.dim,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => _confirmSet(model),
                  child: const Text('Log set'),
                ),
              ],
            )
          else if (_stage == _Stage.resting)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _restLeft += 30),
                    child: const Text('+30s'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      _timer?.cancel();
                      setState(() => _stage = _Stage.ready);
                    },
                    child: const Text('Skip rest'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _centre(AppModel model) {
    switch (_stage) {
      case _Stage.lifting:
        final total = (_goingUp ? _tempo.up : _tempo.down).toDouble();
        final p = (1 - (_phaseLeft / total)).clamp(0.0, 1.0);
        final fill = _goingUp ? p : 1 - p;
        final color = _goingUp ? Tone.good : Tone.accent;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_reps',
                style: const TextStyle(
                    fontSize: 92, fontWeight: FontWeight.w200, height: 1)),
            Text('of ${task.targetReps} reps',
                style: const TextStyle(color: Tone.faint, fontSize: 13)),
            const SizedBox(height: 30),
            // A bar that rises for three seconds and falls for three. Watch
            // the bar, not the clock.
            SizedBox(
              height: 150,
              width: 90,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Tone.surfaceHi,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Tone.line),
                    ),
                  ),
                  FractionallySizedBox(
                    heightFactor: fill.clamp(0.02, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(_goingUp ? 'UP' : 'DOWN',
                style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3)),
            Text('${_phaseLeft.ceil()}s',
                style: const TextStyle(color: Tone.dim, fontSize: 15)),
          ],
        );

      case _Stage.resting:
        final m = (_restLeft ~/ 60).toString();
        final s = (_restLeft.ceil() % 60).toString().padLeft(2, '0');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('REST',
                style: TextStyle(
                    color: Tone.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
            const SizedBox(height: 8),
            Text('$m:$s',
                style: const TextStyle(
                    fontSize: 76,
                    fontWeight: FontWeight.w200,
                    fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 8),
            Text('Next: ${task.exercise.title}',
                style: const TextStyle(color: Tone.dim, fontSize: 13)),
          ],
        );

      case _Stage.logging:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Tone.good, size: 54),
            SizedBox(height: 10),
            Text('Set done', style: TextStyle(fontSize: 17)),
            SizedBox(height: 4),
            Text('Adjust if you stopped early or squeezed one more out.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Tone.faint, fontSize: 12.5)),
          ],
        );

      default:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_tempo.up}s up · ${_tempo.down}s down',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${task.targetReps} reps is ${task.targetReps * _tempo.repSeconds} seconds under tension',
                style: const TextStyle(color: Tone.dim, fontSize: 13)),
          ],
        );
    }
  }

  Widget _done(AppModel model) {
    final byEx = <String, List<SetEntry>>{};
    for (final s in _logged) {
      (byEx[s.exerciseId] ??= []).add(s);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const Icon(Icons.check_circle, color: Tone.good, size: 48),
        const SizedBox(height: 12),
        const Center(
          child: Text('Session complete',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 20),
        for (final entry in byEx.entries) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.engine!.phase.exercises
                      .firstWhere((e) => e.id == entry.key)
                      .title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final s in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      SizedBox(
                          width: 46,
                          child: Text('Set ${s.setIndex}',
                              style: const TextStyle(
                                  color: Tone.faint, fontSize: 12.5))),
                      if (s.side != 'BOTH') SideChip(s.side, size: 18),
                      const SizedBox(width: 8),
                      Text('${s.load.toStringAsFixed(s.load % 1 == 0 ? 0 : 1)} lb',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${s.reps} reps',
                          style: const TextStyle(color: Tone.dim)),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Tone.good),
          onPressed: () => _finish(model),
          child: const Text('Log the session'),
        ),
        const SizedBox(height: 10),
        const Text(
          'The week is decided by tomorrow morning, not by this screen.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Tone.faint, fontSize: 12),
        ),
      ],
    );
  }
}
