import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../engine.dart';
import '../exercise_art.dart';
import '../program.dart';
import '../session_hw.dart';
import '../state.dart';
import '../theme.dart';
import 'how_to.dart';
import 'pain_sheet.dart';

/// Heavy slow resistance. The tempo is the intervention, not a detail: three
/// seconds up, three seconds down, and a weight you cannot control for three
/// seconds down is the wrong weight. So the metronome runs the set, the rep
/// counter follows it, and the cue is audible — you are not looking at the
/// phone while the weight is moving.

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
  final InProgress? resumeFrom;
  const HsrRunnerScreen({super.key, required this.label, this.resumeFrom});

  @override
  State<HsrRunnerScreen> createState() => _HsrRunnerScreenState();
}

class _HsrRunnerScreenState extends State<HsrRunnerScreen> {
  final List<_Task> _tasks = [];
  List<SetEntry> _logged = [];
  bool _built = false;

  int _index = 0;
  _Stage _stage = _Stage.warmup;

  Timer? _timer;
  bool _running = false;

  double _phaseLeft = 0;
  bool _goingUp = true;
  int _reps = 0;

  double _restLeft = 0;
  int _loggedReps = 0;
  final Map<String, double> _loadOverride = {};

  Tempo _tempo = const Tempo(3, 3);

  @override
  void initState() {
    super.initState();
    SessionHw.keepAwake();
    SessionHw.warmUp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SessionHw.letSleep();
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

    final r = widget.resumeFrom;
    if (r != null && _tasks.isNotEmpty) {
      _logged = List.of(r.sets);
      _index = r.position.clamp(0, _tasks.length - 1);
      _stage = _Stage.ready; // the warm-up is behind you
    }
  }

  _Task get task => _tasks[_index];

  String _loadKey(_Task t) => '${t.exercise.id}|${t.side}';

  double _loadOf(_Task t, AppModel model) =>
      _loadOverride[_loadKey(t)] ?? model.state!.loadFor(t.exercise.id, t.side);

  InProgress _snapshot(AppModel model) => InProgress(
        kind: 'hsr',
        blockId: '',
        label: widget.label,
        phaseId: model.engine!.phase.id,
        phaseWeek: model.state!.phaseWeek,
        startedAt:
            widget.resumeFrom?.startedAt ?? DateTime.now().toIso8601String(),
        position: _index,
        sets: _logged,
      );

  static String _fmt(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // ------------------------------------------------------------- tempo loop

  void _startSet() {
    setState(() {
      _stage = _Stage.lifting;
      _reps = 0;
      _goingUp = true;
      _phaseLeft = _tempo.up.toDouble();
    });
    SessionHw.soft();
    _tick();
  }

  void _tick() {
    _timer?.cancel();
    _running = true;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _phaseLeft -= 0.1;
        if (_phaseLeft <= 0) {
          if (_goingUp) {
            _goingUp = false;
            _phaseLeft = _tempo.down.toDouble();
            SessionHw.turn();
          } else {
            _reps++;
            _goingUp = true;
            _phaseLeft = _tempo.up.toDouble();
            if (_reps >= task.targetReps) {
              _endSet();
            } else {
              SessionHw.rep();
            }
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
    SessionHw.done();
  }

  Future<void> _confirmSet(AppModel model) async {
    _logged = [
      ..._logged,
      SetEntry(
        exerciseId: task.exercise.id,
        setIndex: task.setIndex,
        side: task.side,
        load: _loadOf(task, model),
        reps: _loggedReps,
      ),
    ];

    if (_index >= _tasks.length - 1) {
      setState(() => _stage = _Stage.done);
      await model.saveProgress(_snapshot(model));
      return;
    }

    // Rest only after the final side of a set — going straight from left to
    // right is how the set is done; that is not rest.
    final next = _tasks[_index + 1];
    final sameSet =
        next.exercise.id == task.exercise.id && next.setIndex == task.setIndex;

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

    // Persisted after every set, so a phone call or a crash costs nothing.
    await model.saveProgress(_snapshot(model));
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
          SessionHw.done();
        }
      });
    });
  }

  Future<void> _finish(AppModel model) async {
    final pain = await showPainSheet(context, model.program!.sides);
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

  void _openHowTo(AppModel model, Prescribed p) {
    final b = model.engine!.loadBlock;
    showHowTo(
      context,
      movementId: p.exercise.id,
      title: p.exercise.title,
      steps: p.exercise.howTo,
      note: p.exercise.note,
      cue: p.cue,
      upSeconds: _tempo.up,
      downSeconds: _tempo.down,
      scheme: b == null ? null : '${b.scheme} at your ${b.target}',
    );
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: LinearProgressIndicator(
            value: _stage == _Stage.warmup ? 0 : _index / _tasks.length,
            minHeight: 2,
            backgroundColor: Tone.lineSoft,
            valueColor: const AlwaysStoppedAnimation(Tone.action),
          ),
        ),
        actions: [
          if (_stage != _Stage.warmup && _stage != _Stage.done)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('${_index + 1}/${_tasks.length}',
                    style: display(16, color: Tone.dim)),
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
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const SectionLabel('Warm-up'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < phase.warmup.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}', style: display(16, color: Tone.faint)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(phase.warmup[i],
                            style: const TextStyle(height: 1.45)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('The work'),
        for (final p in model.engine!.prescription())
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              onTap: () => _openHowTo(model, p),
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  MovementThumb(movementId: p.exercise.id, size: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.exercise.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text('${p.sets}x${p.reps}',
                                style: display(19, color: Tone.dim)),
                            const SizedBox(width: 12),
                            for (final side in p.sides) ...[
                              if (side != 'BOTH') ...[
                                SideChip(side, size: 19),
                                const SizedBox(width: 5),
                              ],
                              Text(_fmt(p.loads[side] ?? 0),
                                  style: display(19)),
                              const SizedBox(width: 12),
                            ],
                          ],
                        ),
                        if (p.cue != null) ...[
                          const SizedBox(height: 4),
                          Text(p.cue!,
                              style: const TextStyle(
                                  color: Tone.accent, fontSize: 12.5)),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.help_outline, size: 19, color: Tone.faint),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(phase.tempoNote,
            style: const TextStyle(
                color: Tone.faint, fontSize: 12.5, height: 1.45)),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            setState(() => _stage = _Stage.ready);
            await model.beginSession(_snapshot(model));
          },
          child: const Text('Warm-up done — start'),
        ),
      ],
    );
  }

  Widget _work(AppModel model) {
    final t = task;
    final load = _loadOf(t, model);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
      child: Column(
        children: [
          Panel(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            rail: t.side == 'BOTH' ? Tone.dim : Tone.side(t.side),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(t.exercise.title,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w600)),
                    ),
                    if (t.side != 'BOTH') SideChip(t.side, size: 24),
                    const SizedBox(width: 8),
                    HowToButton(
                      size: 28,
                      onTap: () {
                        final pres = model.engine!
                            .prescription()
                            .firstWhere((x) => x.exercise.id == t.exercise.id);
                        _openHowTo(model, pres);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    'Set ${t.setIndex} of ${t.totalSets} · target ${t.targetReps} reps',
                    style: const TextStyle(color: Tone.dim, fontSize: 13)),
                if (t.cue != null) ...[
                  const SizedBox(height: 3),
                  Text(t.cue!,
                      style:
                          const TextStyle(color: Tone.accent, fontSize: 12.5)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Nudge(
                      icon: Icons.remove,
                      onTap: _stage == _Stage.lifting
                          ? null
                          : () => setState(() => _loadOverride[_loadKey(t)] =
                              (load - 2.5).clamp(0, 999)),
                    ),
                    Expanded(
                      child: Center(
                        child: Readout(
                          label: 'load',
                          value: _fmt(load),
                          unit: t.exercise.unit,
                          size: 42,
                          align: CrossAxisAlignment.center,
                        ),
                      ),
                    ),
                    _Nudge(
                      icon: Icons.add,
                      onTap: _stage == _Stage.lifting
                          ? null
                          : () => setState(
                              () => _loadOverride[_loadKey(t)] = load + 2.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: Center(child: _centre())),
          _controls(model),
        ],
      ),
    );
  }

  Widget _controls(AppModel model) {
    switch (_stage) {
      case _Stage.ready:
        return FilledButton(
            onPressed: _startSet, child: const Text('Start set'));
      case _Stage.lifting:
        return Row(
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
                  onPressed: _endSet, child: const Text('End set')),
            ),
          ],
        );
      case _Stage.logging:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Nudge(
                  icon: Icons.remove,
                  big: true,
                  onTap: () => setState(
                      () => _loggedReps = (_loggedReps - 1).clamp(0, 99)),
                ),
                const SizedBox(width: 20),
                Readout(
                  label: 'reps done',
                  value: '$_loggedReps',
                  size: 46,
                  align: CrossAxisAlignment.center,
                ),
                const SizedBox(width: 20),
                _Nudge(
                  icon: Icons.add,
                  big: true,
                  onTap: () => setState(() => _loggedReps++),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _confirmSet(model),
              child: const Text('Log set'),
            ),
          ],
        );
      case _Stage.resting:
        return Row(
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
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _centre() {
    switch (_stage) {
      case _Stage.lifting:
        final total = (_goingUp ? _tempo.up : _tempo.down).toDouble();
        final p = (1 - (_phaseLeft / total)).clamp(0.0, 1.0);
        final fill = _goingUp ? p : 1 - p;
        final color = _goingUp ? Tone.good : Tone.accent;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$_reps', style: display(92)),
                Text(' / ${task.targetReps}',
                    style: display(28, color: Tone.faint)),
              ],
            ),
            const SizedBox(height: 20),
            // Watch the bar, not the clock: it rises for three seconds and
            // falls for three.
            SizedBox(
              height: 126,
              width: 82,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Tone.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Tone.line),
                    ),
                  ),
                  FractionallySizedBox(
                    heightFactor: fill.clamp(0.02, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(_goingUp ? 'UP' : 'DOWN',
                style: TextStyle(
                    fontFamily: kDisplay,
                    color: color,
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4)),
            const SizedBox(height: 3),
            Text('${_phaseLeft.ceil()}s',
                style: const TextStyle(color: Tone.dim, fontSize: 14)),
          ],
        );

      case _Stage.resting:
        final m = (_restLeft ~/ 60).toString();
        final s = (_restLeft.ceil() % 60).toString().padLeft(2, '0');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('REST', style: stencil(13, color: Tone.dim)),
            const SizedBox(height: 8),
            Text('$m:$s', style: display(84)),
            const SizedBox(height: 14),
            Text('Next: ${task.exercise.title}',
                style: const TextStyle(color: Tone.dim, fontSize: 13.5)),
            if (task.side != 'BOTH') ...[
              const SizedBox(height: 8),
              SideChip(task.side, size: 24),
            ],
          ],
        );

      case _Stage.logging:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Tone.good, size: 54),
            SizedBox(height: 12),
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
            MovementThumb(movementId: task.exercise.id, size: 118),
            const SizedBox(height: 18),
            Text('${_tempo.up}S UP  ·  ${_tempo.down}S DOWN',
                style: stencil(14, color: Tone.dim)),
            const SizedBox(height: 6),
            Text(
              '${task.targetReps} reps is ${task.targetReps * _tempo.repSeconds} seconds under tension',
              style: const TextStyle(color: Tone.faint, fontSize: 13),
            ),
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        const Icon(Icons.check_circle, color: Tone.good, size: 46),
        const SizedBox(height: 10),
        Center(child: Text('SESSION COMPLETE', style: display(30))),
        const SizedBox(height: 22),
        for (final entry in byEx.entries) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.engine!.phase.exercises
                      .firstWhere((e) => e.id == entry.key)
                      .title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 9),
                for (final s in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(children: [
                      SizedBox(
                          width: 28,
                          child: Text('${s.setIndex}',
                              style: display(16, color: Tone.faint))),
                      if (s.side != 'BOTH') SideChip(s.side, size: 18),
                      const SizedBox(width: 8),
                      Text('${_fmt(s.load)} lb', style: display(18)),
                      const Spacer(),
                      Text('${s.reps} reps',
                          style: const TextStyle(color: Tone.dim)),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () => _finish(model),
          child: const Text('Log the session'),
        ),
        const SizedBox(height: 12),
        const Text(
          'The week is decided by tomorrow morning, not by this screen.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Tone.faint, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _Nudge extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool big;
  const _Nudge({required this.icon, this.onTap, this.big = false});

  @override
  Widget build(BuildContext context) {
    final d = big ? 52.0 : 44.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(d),
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Tone.surfaceHi,
          border: Border.all(color: Tone.line),
        ),
        child: Icon(icon,
            size: big ? 26 : 21,
            color: onTap == null ? Tone.faint : Tone.text),
      ),
    );
  }
}
