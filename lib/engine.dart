import 'program.dart';
import 'state.dart';

/// The progression engine.
///
/// Every decision in the written program is deterministic given the log, and
/// this is where those decisions live: what to do today, whether the week was
/// earned, when a flare starts and ends, and what the bar should weigh.
///
/// The gate is the only genuinely program-specific rule in here. Swap the gate
/// and the same engine runs an ordinary lifting block.

double roundLoad(double v) => (v * 2).round() / 2.0;

enum PlanKind { iso, hsr }

class PlannedItem {
  final PlanKind kind;
  final IsoBlock? block;
  final String label;
  final int slotIndex;
  final bool done;

  const PlannedItem({
    required this.kind,
    this.block,
    required this.label,
    required this.slotIndex,
    required this.done,
  });
}

class CriterionStatus {
  final Criterion criterion;
  final bool met;
  final String detail;
  const CriterionStatus(this.criterion, this.met, this.detail);
}

class TodayPlan {
  final bool needsCheckIn;
  final List<PlannedItem> items;
  final DateTime? nextAvailable;
  final String? blockedReason;
  final bool readyToAdvancePhase;
  final bool needsCalibration;
  final bool stopped;
  final bool inFlare;
  final int flareDay;
  final bool canResumeFromFlare;
  final bool flareNeedsExam;

  const TodayPlan({
    required this.needsCheckIn,
    required this.items,
    this.nextAvailable,
    this.blockedReason,
    this.readyToAdvancePhase = false,
    this.needsCalibration = false,
    this.stopped = false,
    this.inFlare = false,
    this.flareDay = 0,
    this.canResumeFromFlare = false,
    this.flareNeedsExam = false,
  });

  bool get hasWork => items.any((i) => !i.done);
  bool get allDone => items.isNotEmpty && items.every((i) => i.done);
}

/// One exercise as prescribed for right now: the load per side, the scheme,
/// the rest, and the cue that has come into effect by this week.
class Prescribed {
  final Exercise exercise;
  final List<String> sides;
  final Map<String, double> loads;
  final int sets;
  final int reps;
  final int restSeconds;
  final String? cue;

  const Prescribed({
    required this.exercise,
    required this.sides,
    required this.loads,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.cue,
  });
}

class Engine {
  final Program program;
  final AppState state;

  Engine(this.program, this.state);

  // ---------------------------------------------------------------- position

  Phase get phase => program.phaseById(
      state.phaseId.isEmpty ? program.phases.first.id : state.phaseId);

  /// During a flare the prescription comes from the isometric phase, whatever
  /// phase you were in when it hit.
  Phase get activePhase => state.mode == kModeFlare ? program.isoPhase : phase;

  int get phaseWeek => state.phaseWeek;

  int get docWeek => phase.docWeek(state.phaseWeek);

  LoadBlock? get loadBlock => phase.blockFor(state.phaseWeek);

  bool get isMaintenance => phase.isMaintenance(state.phaseWeek);

  int daysSinceStart(DateTime now) =>
      dayOnly(now).difference(parseYmd(state.startDate)).inDays;

  // ------------------------------------------------------------------- today

  List<SessionLog> get sessionsThisWeek => state.sessions
      .where((s) =>
          s.kind == 'hsr' &&
          s.phaseId == phase.id &&
          daysBetween(state.weekStart, s.date) >= 0)
      .toList();

  DateTime? get lastHsrAt {
    DateTime? out;
    for (final s in state.sessions) {
      if (s.kind != 'hsr') continue;
      final t = DateTime.tryParse(s.at);
      if (t == null) continue;
      if (out == null || t.isAfter(out)) out = t;
    }
    return out;
  }

  DateTime? nextHsrAvailableAt() {
    final last = lastHsrAt;
    if (last == null) return null;
    return last.add(Duration(hours: phase.minHoursBetweenSessions));
  }

  /// Loads have never been set (first Phase 2 session) or the rep scheme just
  /// changed, so a 5% nudge would be meaningless.
  bool get needsCalibration {
    if (activePhase.exercises.isEmpty) return false;
    if (state.needsRecalibration) return true;
    for (final e in activePhase.exercises) {
      for (final side in e.sidesFor(program.sides)) {
        if (state.loadFor(e.id, side) <= 0) return true;
      }
    }
    return false;
  }

  TodayPlan todayPlan(DateTime now) {
    final today = ymd(now);
    final needsCheckIn = state.checkInOn(today) == null;

    if (state.mode == kModeStopped) {
      return TodayPlan(
          needsCheckIn: false, items: const [], stopped: true);
    }

    if (state.mode == kModeFlare) {
      final day = daysBetween(state.flareStart ?? today, today) + 1;
      final todayCheck = state.checkInOn(today);
      final items = _isoItems(today, onlyFirstBlock: true);
      return TodayPlan(
        needsCheckIn: needsCheckIn,
        items: items,
        inFlare: true,
        flareDay: day,
        canResumeFromFlare: day >= program.flare.minDays &&
            todayCheck != null &&
            todayCheck.clean,
        flareNeedsExam: day >= program.flare.seeSomeoneAfterDays,
      );
    }

    if (phase.isDaily) {
      return TodayPlan(
        needsCheckIn: needsCheckIn,
        items: _isoItems(today),
        readyToAdvancePhase: phase1Ready(now),
      );
    }

    // Weekly phase (heavy slow resistance).
    final done = sessionsThisWeek;
    final perWeek = phase.sessionsPerWeek;
    final labels = phase.sessionLabels;

    if (done.length >= perWeek) {
      return TodayPlan(
        needsCheckIn: needsCheckIn,
        items: const [],
        blockedReason:
            'All $perWeek sessions done this week. The week closes once the morning after each one is logged.',
        needsCalibration: false,
      );
    }

    final next = nextHsrAvailableAt();
    if (next != null && now.isBefore(next)) {
      return TodayPlan(
        needsCheckIn: needsCheckIn,
        items: const [],
        nextAvailable: next,
        blockedReason:
            '${phase.minHoursBetweenSessions} hours between sessions loading the same tissue. Not negotiable.',
      );
    }

    final label = done.length < labels.length
        ? labels[done.length]
        : 'Session ${done.length + 1}';

    return TodayPlan(
      needsCheckIn: needsCheckIn,
      items: [
        PlannedItem(
          kind: PlanKind.hsr,
          label: label,
          slotIndex: done.length,
          done: false,
        )
      ],
      needsCalibration: needsCalibration,
    );
  }

  List<PlannedItem> _isoItems(String today, {bool onlyFirstBlock = false}) {
    final blocks = onlyFirstBlock
        ? (program.isoPhase.blocks.isEmpty
            ? <IsoBlock>[]
            : [program.isoPhase.blocks.first])
        : program.isoPhase.blocks;
    final logged = state.sessionsOn(today);
    final out = <PlannedItem>[];
    for (final b in blocks) {
      for (var i = 0; i < b.timesPerDay; i++) {
        final label = b.slotLabel(i);
        final done = logged.any((s) => s.blockId == b.id && s.label == label);
        out.add(PlannedItem(
          kind: PlanKind.iso,
          block: b,
          label: label,
          slotIndex: i,
          done: done,
        ));
      }
    }
    return out;
  }

  // --------------------------------------------------------- prescription

  List<Prescribed> prescription() {
    final p = phase;
    final b = loadBlock;
    if (b == null) return const [];
    return p.exercises.map((e) {
      final sides = e.sidesFor(program.sides);
      return Prescribed(
        exercise: e,
        sides: sides,
        loads: {for (final s in sides) s: state.loadFor(e.id, s)},
        sets: b.sets,
        reps: b.reps,
        restSeconds: b.restSeconds,
        cue: e.cueFor(state.phaseWeek),
      );
    }).toList();
  }

  // ------------------------------------------------------ Phase 1 criteria

  /// Consecutive days, counting back from the most recent check-in, on which
  /// the next morning was not worse.
  int cleanStreak([DateTime? now]) {
    final start = dayOnly(now ?? DateTime.now());
    var streak = 0;
    for (var i = 0; i < 60; i++) {
      final d = ymd(start.subtract(Duration(days: i)));
      final c = state.checkInOn(d);
      if (c == null) {
        // Today not logged yet is not a break in the streak; a gap is.
        if (i == 0) continue;
        break;
      }
      if (!c.clean) break;
      streak++;
    }
    return streak;
  }

  /// Worst pain reported during an isometric hold in the recent window.
  double? recentHoldPain({int windowDays = 7, DateTime? now}) {
    final cutoff = dayOnly(now ?? DateTime.now()).subtract(Duration(days: windowDays));
    double? worst;
    for (final s in state.sessions) {
      if (s.kind != 'iso') continue;
      if (parseYmd(s.date).isBefore(cutoff)) continue;
      final w = s.worstPain;
      if (worst == null || w > worst) worst = w;
    }
    return worst;
  }

  List<CriterionStatus> phase1Criteria([DateTime? now]) {
    final a = phase.advance;
    final out = <CriterionStatus>[];
    for (final c in a.criteria) {
      switch (c.id) {
        case 'clean4':
          final s = cleanStreak(now);
          out.add(CriterionStatus(c, s >= a.cleanDays,
              '$s of ${a.cleanDays} consecutive clean mornings'));
          break;
        case 'holds3':
          final p = recentHoldPain(now: now);
          out.add(CriterionStatus(
            c,
            p != null && p <= a.holdPainMax,
            p == null
                ? 'No holds logged yet'
                : 'Worst hold in the last 7 days: ${p.toStringAsFixed(0)}/10',
          ));
          break;
        case 'baselineDown':
          out.add(CriterionStatus(c, state.baselineDownConfirmed,
              state.baselineDownConfirmed ? 'Confirmed' : 'Your call'));
          break;
        default:
          out.add(CriterionStatus(c, false, ''));
      }
    }
    return out;
  }

  /// True when everything the engine can decide for itself is satisfied. The
  /// remaining judgment call is put to you at the moment you advance.
  bool phase1Ready([DateTime? now]) {
    if (!phase.isDaily) return false;
    final a = phase.advance;
    if (state.phaseWeek < a.minWeeks) return false;
    for (final s in phase1Criteria(now)) {
      if (s.criterion.kind == 'computed' && !s.met) return false;
    }
    return true;
  }

  // ------------------------------------------------------------- mutations

  void applyCheckIn(CheckIn c) {
    state.checkIns.removeWhere((e) => e.date == c.date);
    state.checkIns.add(c);
    state.checkIns.sort((a, b) => a.date.compareTo(b.date));

    if (c.redFlags.isNotEmpty) {
      state.mode = kModeStopped;
      return;
    }
    if (c.flare && state.mode == kModeNormal) {
      _enterFlare(c.date);
      return;
    }
    _evaluateWeek(c.date);
  }

  void _enterFlare(String date) {
    state.mode = kModeFlare;
    state.flareStart = date;
    state.flareLoads = cloneLoads(state.loads);
    state.flares.add(FlareRecord(date, null, state.phaseWeek));
  }

  /// Back to loading after a flare: 70% of what you flared on, rebuilt to the
  /// old load across the next six sessions.
  void resumeFromFlare(DateTime now) {
    final today = ymd(now);
    if (state.flares.isNotEmpty && state.flares.last.endedOn == null) {
      final f = state.flares.removeLast();
      state.flares.add(FlareRecord(f.startedOn, today, f.phaseWeek));
    }
    state.mode = kModeNormal;
    state.flareStart = null;

    if (!phase.isDaily && state.flareLoads.isNotEmpty) {
      final pct = program.flare.resumePct / 100.0;
      final target = cloneLoads(state.flareLoads);
      state.loads = target.map((ex, sides) => MapEntry(
            ex,
            sides.map((s, v) => MapEntry(s, roundLoad(v * pct))),
          ));
      state.rebuildTarget = target;
      state.rebuildSessionsLeft = program.flare.rebuildSessions;
    }
    state.flareLoads = {};
    state.weekStart = today;
  }

  void clearStop() {
    state.mode = kModeNormal;
  }

  void completeSession(SessionLog s) {
    state.sessions.add(s);
    state.sessions.sort((a, b) => a.at.compareTo(b.at));
    state.inProgress = null;
    if (s.kind == 'hsr') _stepRebuild();
    _evaluateWeek(s.date);
  }

  /// Correct a logged session. Pain feeds the Phase 1 gate and the loads feed
  /// the progress chart, so a mistyped number is worth being able to fix.
  ///
  /// Deliberately does NOT rewind weeks already earned — the week you were
  /// given, you keep. It re-evaluates the current week only.
  void updateSession(SessionLog updated) {
    final i = state.sessions.indexWhere((x) => x.id == updated.id);
    if (i < 0) return;
    state.sessions[i] = updated;
    state.sessions.sort((a, b) => a.at.compareTo(b.at));
    _evaluateWeek(ymd(DateTime.now()));
  }

  void deleteSession(String id) {
    state.sessions.removeWhere((x) => x.id == id);
    _evaluateWeek(ymd(DateTime.now()));
  }

  // ------------------------------------------------------- session resume

  void beginSession(InProgress p) => state.inProgress = p;

  void updateProgress(InProgress p) => state.inProgress = p;

  void abandonSession() => state.inProgress = null;

  /// The half-finished session worth offering to resume, if there is one.
  InProgress? resumable(DateTime now) {
    final p = state.inProgress;
    if (p == null) return null;
    if (p.isStale(now)) return null;
    return p;
  }

  /// Walk the load back up toward where it was before the flare, one session
  /// at a time, so the last rebuild session lands exactly on the old number.
  void _stepRebuild() {
    if (state.rebuildSessionsLeft <= 0) return;
    final left = state.rebuildSessionsLeft;
    state.rebuildTarget.forEach((ex, sides) {
      sides.forEach((side, target) {
        final cur = state.loadFor(ex, side);
        final next = cur + (target - cur) / left;
        state.setLoad(ex, side, roundLoad(next));
      });
    });
    state.rebuildSessionsLeft = left - 1;
    if (state.rebuildSessionsLeft == 0) {
      state.loads = cloneLoads(state.rebuildTarget);
      state.rebuildTarget = {};
    }
  }

  /// The week closes only when every session in it has a next morning on
  /// record. One "worse" anywhere repeats the week at the same load.
  void _evaluateWeek(String onDate) {
    if (state.mode != kModeNormal) return;
    if (phase.isDaily) return;

    final need = phase.advance.requireSessions;
    if (need <= 0) return;
    final week = sessionsThisWeek;
    if (week.length < need) return;

    var worse = false;
    for (final s in week) {
      final morningAfter = ymd(parseYmd(s.date).add(const Duration(days: 1)));
      final c = state.checkInOn(morningAfter);
      if (c == null) return; // still waiting on the deciding signal
      if (!c.clean) worse = true;
    }

    if (worse) {
      _repeatWeek(onDate);
    } else {
      _advanceWeek(onDate);
    }
  }

  void _repeatWeek(String onDate) {
    state.weekStart = onDate;
    // Loads deliberately untouched.
  }

  void _advanceWeek(String onDate) {
    final p = phase;
    final nextWeek = state.phaseWeek + 1;

    if (nextWeek > p.nominalWeeks) {
      final next = program.nextPhaseAfter(p.id);
      if (next != null) {
        state.phaseId = next.id;
        state.phaseWeek = 1;
        state.weekStart = onDate;
        state.needsRecalibration = next.loadBlocks.isNotEmpty &&
            (next.blockFor(1)?.reps != p.blockFor(state.phaseWeek)?.reps);
        return;
      }
      // No phase after this one: maintenance runs on indefinitely.
    }

    final oldBlock = p.blockFor(state.phaseWeek);
    final newBlock = p.blockFor(nextWeek);
    state.phaseWeek = nextWeek;
    state.weekStart = onDate;

    if (state.rebuildSessionsLeft > 0) return; // rebuilding; no weekly bump

    if (oldBlock != null && newBlock != null && oldBlock.reps != newBlock.reps) {
      _scaleLoads(p.recalibrateBumpPct);
      state.needsRecalibration = true;
    } else if (p.weeklyIncreasePct > 0) {
      _scaleLoads(p.weeklyIncreasePct);
    }
  }

  void _scaleLoads(double pct) {
    if (pct == 0) return;
    state.loads = state.loads.map((ex, sides) => MapEntry(
          ex,
          sides.map((s, v) => MapEntry(s, v <= 0 ? v : roundLoad(v * (1 + pct / 100)))),
        ));
  }

  /// Phase 1 -> Phase 2, once the criteria are met and you have confirmed the
  /// one call the app cannot make for you.
  void advancePhase(DateTime now) {
    final next = program.nextPhaseAfter(phase.id);
    if (next == null) return;
    state.phaseId = next.id;
    state.phaseWeek = 1;
    state.weekStart = ymd(now);
    state.needsRecalibration = next.loadBlocks.isNotEmpty;
  }

  void applyCalibration(Map<String, Map<String, double>> loads) {
    loads.forEach((ex, sides) {
      sides.forEach((s, v) => state.setLoad(ex, s, roundLoad(v)));
    });
    state.needsRecalibration = false;
  }

  // ------------------------------------------------------------- reporting

  /// Verdict recorded the morning after a session, if it has been logged.
  CheckIn? morningAfter(SessionLog s) =>
      state.checkInOn(ymd(parseYmd(s.date).add(const Duration(days: 1))));

  /// Load history for one exercise/side, oldest first, for the progress chart.
  List<({String date, double load})> loadHistory(String exerciseId, String side) {
    final out = <({String date, double load})>[];
    for (final s in state.sessions) {
      for (final e in s.sets) {
        if (e.exerciseId == exerciseId && e.side == side) {
          if (out.isEmpty || out.last.date != s.date) {
            out.add((date: s.date, load: e.load));
          }
          break;
        }
      }
    }
    return out;
  }
}
