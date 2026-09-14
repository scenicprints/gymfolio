import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymfolio/engine.dart';
import 'package:gymfolio/program.dart';
import 'package:gymfolio/state.dart';

/// These tests are the reason the engine is separate from the widgets: the
/// progression rules decide what weight goes on a bar attached to a sore
/// tendon, so they get asserted rather than eyeballed.

Program loadProgram() {
  final raw =
      File('assets/programs/biceps_tendinopathy.json').readAsStringSync();
  return Program.fromJson(json.decode(raw) as Map);
}

String d(DateTime x) => ymd(x);

/// A state parked at the start of Phase 2 with known loads.
({Program p, AppState s, Engine e}) atPhase2(
    {DateTime? start, Map<String, Map<String, double>>? loads}) {
  final p = loadProgram();
  final today = start ?? DateTime(2026, 1, 5);
  final s = AppState(
    programId: p.id,
    onboarded: true,
    startDate: d(today),
    phaseId: 'phase2',
    phaseWeek: 1,
    weekStart: d(today),
    loads: loads ??
        {
          'incline-curl': {'L': 30, 'R': 25},
          'bar-curl': {'BOTH': 45},
          'screwdriver': {'L': 10, 'R': 7.5},
        },
  );
  return (p: p, s: s, e: Engine(p, s));
}

SessionLog hsr(DateTime at, String label, AppState s) => SessionLog(
      id: '${at.microsecondsSinceEpoch}',
      date: d(at),
      at: at.toIso8601String(),
      phaseId: s.phaseId,
      phaseWeek: s.phaseWeek,
      kind: 'hsr',
      blockId: '',
      label: label,
      painDuring: const {'L': 3, 'R': 4},
      sets: const [],
    );

CheckIn morning(DateTime day,
        {Verdict l = Verdict.same,
        Verdict r = Verdict.same,
        bool flare = false,
        List<String> redFlags = const []}) =>
    CheckIn(
      date: d(day),
      verdicts: {'L': l, 'R': r},
      flare: flare,
      redFlags: redFlags,
    );

void main() {
  group('program document', () {
    test('parses the phases, exercises and laterality', () {
      final p = loadProgram();
      expect(p.phases.length, 3);

      final phase2 = p.phaseById('phase2');
      expect(phase2.exercises.length, 3);

      // The barbell is the whole reason the unilateral flag exists: one bar,
      // one load, gated by the weaker arm.
      final bar = phase2.exercises.firstWhere((e) => e.id == 'bar-curl');
      expect(bar.unilateral, isFalse);
      expect(bar.sidesFor(p.sides), ['BOTH']);

      final incline = phase2.exercises.firstWhere((e) => e.id == 'incline-curl');
      expect(incline.unilateral, isTrue);
      expect(incline.sidesFor(p.sides), ['L', 'R']);
    });

    test('load blocks follow the written rep ladder', () {
      final phase2 = loadProgram().phaseById('phase2');
      expect(phase2.blockFor(1)!.reps, 15);
      expect(phase2.blockFor(3)!.reps, 12);
      expect(phase2.blockFor(5)!.reps, 10);
      expect(phase2.blockFor(7)!.reps, 8);
      expect(phase2.blockFor(9)!.reps, 6);
    });

    test('doc week numbering matches the paper program', () {
      final p = loadProgram();
      expect(p.phaseById('phase1').docWeek(1), 1);
      expect(p.phaseById('phase2').docWeek(1), 3);
      expect(p.phaseById('phase3').docWeek(1), 13);
    });
  });

  group('phase 1', () {
    test('prescribes both isometric blocks, flexion twice a day', () {
      final p = loadProgram();
      final s = AppState(
          programId: p.id, onboarded: true, phaseId: 'phase1', phaseWeek: 1);
      final e = Engine(p, s);
      final plan = e.todayPlan(DateTime(2026, 1, 5));
      // 2 flexion rounds + 1 supination round.
      expect(plan.items.length, 3);
      expect(plan.items.where((i) => i.block!.id == 'iso-flexion').length, 2);
      expect(plan.needsCheckIn, isTrue);
    });

    test('a logged round drops out of the day plan', () {
      final p = loadProgram();
      final now = DateTime(2026, 1, 5, 8);
      final s = AppState(
          programId: p.id, onboarded: true, phaseId: 'phase1', phaseWeek: 1);
      s.sessions.add(SessionLog(
        id: '1',
        date: d(now),
        at: now.toIso8601String(),
        phaseId: 'phase1',
        phaseWeek: 1,
        kind: 'iso',
        blockId: 'iso-flexion',
        label: 'Morning',
        painDuring: const {'L': 2, 'R': 3},
        sets: const [],
      ));
      final plan = Engine(p, s).todayPlan(now);
      expect(plan.items.where((i) => i.done).length, 1);
      expect(plan.hasWork, isTrue);
    });

    test('will not advance before the minimum two weeks', () {
      final p = loadProgram();
      final today = DateTime(2026, 1, 12);
      final s = AppState(
          programId: p.id, onboarded: true, phaseId: 'phase1', phaseWeek: 1);
      final e = Engine(p, s);
      for (var i = 0; i < 6; i++) {
        final day = today.subtract(Duration(days: i));
        s.checkIns.add(morning(day, l: Verdict.better, r: Verdict.better));
        s.sessions.add(SessionLog(
          id: '$i',
          date: d(day),
          at: day.toIso8601String(),
          phaseId: 'phase1',
          phaseWeek: 1,
          kind: 'iso',
          blockId: 'iso-flexion',
          label: 'Morning',
          painDuring: const {'L': 2, 'R': 2},
          sets: const [],
        ));
      }
      expect(e.cleanStreak(today), greaterThanOrEqualTo(4));
      expect(e.phase1Ready(today), isFalse, reason: 'phaseWeek 1 < minWeeks 2');

      s.phaseWeek = 2;
      expect(e.phase1Ready(today), isTrue);
    });

    test('a hold above 3/10 blocks the phase gate', () {
      final p = loadProgram();
      final today = DateTime(2026, 1, 19);
      final s = AppState(
          programId: p.id, onboarded: true, phaseId: 'phase1', phaseWeek: 2);
      final e = Engine(p, s);
      for (var i = 0; i < 5; i++) {
        final day = today.subtract(Duration(days: i));
        s.checkIns.add(morning(day, l: Verdict.better, r: Verdict.same));
        s.sessions.add(SessionLog(
          id: '$i',
          date: d(day),
          at: day.toIso8601String(),
          phaseId: 'phase1',
          phaseWeek: 2,
          kind: 'iso',
          blockId: 'iso-flexion',
          label: 'Morning',
          painDuring: {'L': 2, 'R': i == 0 ? 6 : 2},
          sets: const [],
        ));
      }
      expect(e.phase1Ready(today), isFalse);
      final holds =
          e.phase1Criteria(today).firstWhere((c) => c.criterion.id == 'holds3');
      expect(holds.met, isFalse);
    });

    test('a worse morning breaks the clean streak', () {
      final p = loadProgram();
      final today = DateTime(2026, 1, 19);
      final s = AppState(
          programId: p.id, onboarded: true, phaseId: 'phase1', phaseWeek: 2);
      s.checkIns
          .add(morning(today.subtract(const Duration(days: 3)), l: Verdict.better));
      s.checkIns
          .add(morning(today.subtract(const Duration(days: 2)), l: Verdict.worse));
      s.checkIns
          .add(morning(today.subtract(const Duration(days: 1)), l: Verdict.same));
      s.checkIns.add(morning(today, l: Verdict.same));
      expect(Engine(p, s).cleanStreak(today), 2);
    });
  });

  group('phase 2 scheduling', () {
    test('72 hours between sessions is enforced', () {
      final ctx = atPhase2();
      final first = DateTime(2026, 1, 5, 18);
      ctx.e.completeSession(hsr(first, 'Session A', ctx.s));

      final nextDay = ctx.e.todayPlan(first.add(const Duration(hours: 24)));
      expect(nextDay.items, isEmpty);
      expect(nextDay.nextAvailable, isNotNull);
      expect(nextDay.blockedReason, contains('72 hours'));

      final after72 = ctx.e.todayPlan(first.add(const Duration(hours: 73)));
      expect(after72.items.length, 1);
      expect(after72.items.first.label, 'Session B');
    });

    test('session labels run A, B, C across the week', () {
      final ctx = atPhase2();
      var t = DateTime(2026, 1, 5, 18);
      expect(ctx.e.todayPlan(t).items.first.label, 'Session A');
      ctx.e.completeSession(hsr(t, 'Session A', ctx.s));
      t = t.add(const Duration(hours: 73));
      expect(ctx.e.todayPlan(t).items.first.label, 'Session B');
    });
  });

  group('the 24-hour rule', () {
    test('three clean sessions advance the week and add 5%', () {
      final ctx = atPhase2();
      var t = DateTime(2026, 1, 5, 18);
      for (var i = 0; i < 3; i++) {
        ctx.e.completeSession(hsr(t, 'Session ${String.fromCharCode(65 + i)}', ctx.s));
        ctx.e.applyCheckIn(morning(t.add(const Duration(days: 1))));
        t = t.add(const Duration(hours: 73));
      }
      expect(ctx.s.phaseWeek, 2, reason: 'week earned');
      // 30 -> 31.5, 25 -> 26, 45 -> 47.5, rounded to the nearest half pound.
      expect(ctx.s.loadFor('incline-curl', 'L'), 31.5);
      expect(ctx.s.loadFor('incline-curl', 'R'), 26.5);
      expect(ctx.s.loadFor('bar-curl', 'BOTH'), 47.5);
    });

    test('one worse morning repeats the week at the same load', () {
      final ctx = atPhase2();
      var t = DateTime(2026, 1, 5, 18);
      for (var i = 0; i < 3; i++) {
        ctx.e.completeSession(hsr(t, 'S$i', ctx.s));
        ctx.e.applyCheckIn(morning(
          t.add(const Duration(days: 1)),
          r: i == 1 ? Verdict.worse : Verdict.same,
        ));
        t = t.add(const Duration(hours: 73));
      }
      expect(ctx.s.phaseWeek, 1, reason: 'week repeated, not advanced');
      expect(ctx.s.loadFor('incline-curl', 'L'), 30);
      expect(ctx.s.loadFor('bar-curl', 'BOTH'), 45);
    });

    test('the week does not close until every morning after is logged', () {
      final ctx = atPhase2();
      var t = DateTime(2026, 1, 5, 18);
      for (var i = 0; i < 3; i++) {
        ctx.e.completeSession(hsr(t, 'S$i', ctx.s));
        if (i < 2) ctx.e.applyCheckIn(morning(t.add(const Duration(days: 1))));
        t = t.add(const Duration(hours: 73));
      }
      expect(ctx.s.phaseWeek, 1, reason: 'still waiting on the last morning');

      ctx.e.applyCheckIn(morning(
          DateTime(2026, 1, 11, 18).add(const Duration(days: 1))));
      expect(ctx.s.phaseWeek, 2);
    });

    test('crossing into a new rep scheme asks for a recalibration', () {
      final ctx = atPhase2();
      ctx.s.phaseWeek = 2; // last week of the 4x15 block
      var t = DateTime(2026, 1, 5, 18);
      for (var i = 0; i < 3; i++) {
        ctx.e.completeSession(hsr(t, 'S$i', ctx.s));
        ctx.e.applyCheckIn(morning(t.add(const Duration(days: 1))));
        t = t.add(const Duration(hours: 73));
      }
      expect(ctx.s.phaseWeek, 3);
      expect(ctx.e.loadBlock!.reps, 12);
      expect(ctx.s.needsRecalibration, isTrue);
      expect(ctx.e.needsCalibration, isTrue);
    });

    test('phase 2 rolls into phase 3 after its last week', () {
      final ctx = atPhase2();
      ctx.s.phaseWeek = 10;
      var t = DateTime(2026, 1, 5, 18);
      for (var i = 0; i < 3; i++) {
        ctx.e.completeSession(hsr(t, 'S$i', ctx.s));
        ctx.e.applyCheckIn(morning(t.add(const Duration(days: 1))));
        t = t.add(const Duration(hours: 73));
      }
      expect(ctx.s.phaseId, 'phase3');
      expect(ctx.s.phaseWeek, 1);
      expect(ctx.e.docWeek, 13);
    });
  });

  group('flare protocol', () {
    test('a flare check-in switches the prescription to isometrics', () {
      final ctx = atPhase2();
      final day = DateTime(2026, 1, 8);
      ctx.e.applyCheckIn(morning(day, r: Verdict.worse, flare: true));

      expect(ctx.s.mode, kModeFlare);
      expect(ctx.s.flares.length, 1);
      final plan = ctx.e.todayPlan(day);
      expect(plan.inFlare, isTrue);
      // Only the flexion hold, twice daily — that is what the protocol says.
      expect(plan.items.length, 2);
      expect(plan.items.every((i) => i.block!.id == 'iso-flexion'), isTrue);
    });

    test('cannot resume before the minimum hold, then can once clean', () {
      final ctx = atPhase2();
      final day1 = DateTime(2026, 1, 8);
      ctx.e.applyCheckIn(morning(day1, r: Verdict.worse, flare: true));
      expect(ctx.e.todayPlan(day1).canResumeFromFlare, isFalse);

      final day2 = day1.add(const Duration(days: 1));
      ctx.e.applyCheckIn(morning(day2, r: Verdict.same));
      expect(ctx.e.todayPlan(day2).canResumeFromFlare, isFalse);

      final day3 = day1.add(const Duration(days: 2));
      ctx.e.applyCheckIn(morning(day3, r: Verdict.same));
      expect(ctx.e.todayPlan(day3).canResumeFromFlare, isTrue);
    });

    test('resuming drops to 70% and rebuilds to the old load in six sessions',
        () {
      final ctx = atPhase2();
      final day1 = DateTime(2026, 1, 8);
      ctx.e.applyCheckIn(morning(day1, r: Verdict.worse, flare: true));
      final day3 = day1.add(const Duration(days: 2));
      ctx.e.applyCheckIn(morning(day3, r: Verdict.same));
      ctx.e.resumeFromFlare(day3);

      expect(ctx.s.mode, kModeNormal);
      expect(ctx.s.loadFor('incline-curl', 'L'), 21.0); // 70% of 30
      expect(ctx.s.loadFor('bar-curl', 'BOTH'), 31.5); // 70% of 45
      expect(ctx.s.rebuildSessionsLeft, 6);
      expect(ctx.s.flares.single.endedOn, d(day3));

      var t = day3.add(const Duration(hours: 24));
      for (var i = 0; i < 6; i++) {
        ctx.e.completeSession(hsr(t, 'S$i', ctx.s));
        t = t.add(const Duration(hours: 73));
      }
      expect(ctx.s.rebuildSessionsLeft, 0);
      expect(ctx.s.loadFor('incline-curl', 'L'), 30.0);
      expect(ctx.s.loadFor('bar-curl', 'BOTH'), 45.0);
    });

    test('a long flare tells you to get it looked at', () {
      final ctx = atPhase2();
      final day1 = DateTime(2026, 1, 8);
      ctx.e.applyCheckIn(morning(day1, r: Verdict.worse, flare: true));
      final day8 = day1.add(const Duration(days: 7));
      expect(ctx.e.todayPlan(day8).flareNeedsExam, isTrue);
    });

    test('a plain worse morning is not a flare', () {
      final ctx = atPhase2();
      ctx.e.applyCheckIn(morning(DateTime(2026, 1, 8), r: Verdict.worse));
      expect(ctx.s.mode, kModeNormal);
      expect(ctx.s.flares, isEmpty);
    });
  });

  group('red flags', () {
    test('stop the program until it is cleared', () {
      final ctx = atPhase2();
      final day = DateTime(2026, 1, 8);
      ctx.e.applyCheckIn(morning(day,
          redFlags: ['Numbness or tingling into the forearm or hand']));

      expect(ctx.s.mode, kModeStopped);
      final plan = ctx.e.todayPlan(day);
      expect(plan.stopped, isTrue);
      expect(plan.items, isEmpty);

      ctx.e.clearStop();
      expect(ctx.e.todayPlan(day).stopped, isFalse);
    });
  });

  group('calibration', () {
    test('missing loads block the session until they are set', () {
      final ctx = atPhase2(loads: {});
      expect(ctx.e.needsCalibration, isTrue);
      expect(ctx.e.todayPlan(DateTime(2026, 1, 5)).needsCalibration, isTrue);

      ctx.e.applyCalibration({
        'incline-curl': {'L': 30, 'R': 25},
        'bar-curl': {'BOTH': 45},
        'screwdriver': {'L': 10, 'R': 7.5},
      });
      expect(ctx.e.needsCalibration, isFalse);
    });

    test('prescription carries one load for the bar and two for dumbbells', () {
      final ctx = atPhase2();
      final pres = ctx.e.prescription();
      final bar = pres.firstWhere((p) => p.exercise.id == 'bar-curl');
      expect(bar.loads.keys.toList(), ['BOTH']);
      final incline = pres.firstWhere((p) => p.exercise.id == 'incline-curl');
      expect(incline.loads['L'], 30);
      expect(incline.loads['R'], 25);
      expect(incline.sets, 4);
      expect(incline.reps, 15);
    });

    test('week 5 swaps the incline cue to a supinated grip', () {
      final ctx = atPhase2();
      ctx.s.phaseWeek = 1;
      expect(
          ctx.e
              .prescription()
              .firstWhere((p) => p.exercise.id == 'incline-curl')
              .cue,
          contains('neutral'));
      ctx.s.phaseWeek = 3; // doc week 5
      expect(
          ctx.e
              .prescription()
              .firstWhere((p) => p.exercise.id == 'incline-curl')
              .cue,
          contains('supinated'));
    });
  });

  group('persistence', () {
    test('a full state round-trips through JSON', () {
      final ctx = atPhase2();
      ctx.e.completeSession(SessionLog(
        id: 'x',
        date: '2026-01-05',
        at: '2026-01-05T18:00:00.000',
        phaseId: 'phase2',
        phaseWeek: 1,
        kind: 'hsr',
        blockId: '',
        label: 'Session A',
        painDuring: const {'L': 3, 'R': 4},
        sets: const [
          SetEntry(
              exerciseId: 'incline-curl',
              setIndex: 1,
              side: 'L',
              load: 30,
              reps: 15),
          SetEntry(
              exerciseId: 'bar-curl',
              setIndex: 1,
              side: 'BOTH',
              load: 45,
              reps: 15),
        ],
      ));
      ctx.e.applyCheckIn(morning(DateTime(2026, 1, 6)));

      final round = AppState.fromJson(
          json.decode(json.encode(ctx.s.toJson())) as Map);
      expect(round.sessions.length, 1);
      expect(round.sessions.first.sets.length, 2);
      expect(round.sessions.first.sets[1].side, 'BOTH');
      expect(round.checkIns.length, 1);
      expect(round.checkIns.first.verdicts['L'], Verdict.same);
      expect(round.loadFor('incline-curl', 'R'), 25);
    });
  });
}
