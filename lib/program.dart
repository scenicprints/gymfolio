import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// The program is DATA, not code. Nothing about biceps tendons is compiled into
/// this app — the engine reads whatever program document it is handed. That is
/// what lets a physio's modifications be a JSON edit, and what lets GymFolio
/// become a general lifting log later without a rewrite.

double _d(dynamic v, [double or = 0]) =>
    v == null ? or : (v is num ? v.toDouble() : double.tryParse('$v') ?? or);
int _i(dynamic v, [int or = 0]) =>
    v == null ? or : (v is num ? v.toInt() : int.tryParse('$v') ?? or);
String _s(dynamic v, [String or = '']) => v == null ? or : '$v';
List<String> _sl(dynamic v) =>
    (v as List?)?.map((e) => '$e').toList() ?? const <String>[];

class Tempo {
  final int up;
  final int down;
  const Tempo(this.up, this.down);
  factory Tempo.from(dynamic j) =>
      j == null ? const Tempo(0, 0) : Tempo(_i(j['up']), _i(j['down']));

  bool get isSet => up > 0 || down > 0;
  int get repSeconds => up + down;
  @override
  String toString() => '${up}s up / ${down}s down';
}

class WeekCue {
  final int fromPhaseWeek;
  final String text;
  const WeekCue(this.fromPhaseWeek, this.text);
}

class Exercise {
  final String id;
  final String title;

  /// False means one bar, one load — the weaker arm gates the lift. The barbell
  /// curl is the reason this flag exists.
  final bool unilateral;
  final String unit;
  final String note;
  final List<WeekCue> weekCues;

  const Exercise({
    required this.id,
    required this.title,
    required this.unilateral,
    required this.unit,
    required this.note,
    required this.weekCues,
  });

  factory Exercise.from(Map j) => Exercise(
        id: _s(j['id']),
        title: _s(j['title']),
        unilateral: j['unilateral'] == true,
        unit: _s(j['unit'], 'lb'),
        note: _s(j['note']),
        weekCues: ((j['weekCues'] as List?) ?? const [])
            .map((e) => WeekCue(_i(e['fromPhaseWeek'], 1), _s(e['text'])))
            .toList(),
      );

  /// Sides this exercise carries a load for, at this program's laterality.
  List<String> sidesFor(List<String> programSides) =>
      unilateral ? programSides : const ['BOTH'];

  /// The latest cue that has come into effect by [phaseWeek].
  String? cueFor(int phaseWeek) {
    String? out;
    for (final c in weekCues) {
      if (phaseWeek >= c.fromPhaseWeek) out = c.text;
    }
    return out;
  }
}

class LoadBlock {
  final int fromWeek;
  final int toWeek;
  final String docWeeks;
  final int sets;
  final int reps;
  final int restSeconds;
  final String target;

  const LoadBlock({
    required this.fromWeek,
    required this.toWeek,
    required this.docWeeks,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.target,
  });

  factory LoadBlock.from(Map j) {
    final w = (j['phaseWeeks'] as List?) ?? const [1, 1];
    return LoadBlock(
      fromWeek: _i(w.first, 1),
      toWeek: _i(w.last, 1),
      docWeeks: _s(j['docWeeks']),
      sets: _i(j['sets'], 4),
      reps: _i(j['reps'], 10),
      restSeconds: _i(j['restSeconds'], 120),
      target: _s(j['target']),
    );
  }

  bool covers(int phaseWeek) => phaseWeek >= fromWeek && phaseWeek <= toWeek;
  String get scheme => '$sets x $reps';
}

/// A timed isometric block — Phase 1's whole content, and where the flare
/// protocol sends you back to.
class IsoBlock {
  final String id;
  final String title;
  final int timesPerDay;
  final List<String> slots;
  final bool perSide;
  final int sets;
  final int holdSeconds;
  final int rampSeconds;
  final int restSeconds;
  final String effort;
  final List<String> cues;

  const IsoBlock({
    required this.id,
    required this.title,
    required this.timesPerDay,
    required this.slots,
    required this.perSide,
    required this.sets,
    required this.holdSeconds,
    required this.rampSeconds,
    required this.restSeconds,
    required this.effort,
    required this.cues,
  });

  factory IsoBlock.from(Map j) => IsoBlock(
        id: _s(j['id']),
        title: _s(j['title']),
        timesPerDay: _i(j['timesPerDay'], 1),
        slots: _sl(j['slots']),
        perSide: j['perSide'] == true,
        sets: _i(j['sets'], 5),
        holdSeconds: _i(j['holdSeconds'], 45),
        rampSeconds: _i(j['rampSeconds'], 2),
        restSeconds: _i(j['restSeconds'], 120),
        effort: _s(j['effort']),
        cues: _sl(j['cues']),
      );

  String slotLabel(int index) =>
      index < slots.length ? slots[index] : 'Round ${index + 1}';
}

class Criterion {
  final String id;
  final String label;

  /// 'computed' criteria the engine decides from the log; 'confirm' criteria
  /// are the judgment calls only you can make.
  final String kind;
  const Criterion(this.id, this.label, this.kind);
}

class PhaseAdvance {
  final int minWeeks;
  final int cleanDays;
  final int holdPainMax;
  final int requireSessions;
  final List<Criterion> criteria;
  final String note;

  const PhaseAdvance({
    required this.minWeeks,
    required this.cleanDays,
    required this.holdPainMax,
    required this.requireSessions,
    required this.criteria,
    required this.note,
  });

  factory PhaseAdvance.from(dynamic j) {
    j ??= const {};
    return PhaseAdvance(
      minWeeks: _i(j['minWeeks'], 1),
      cleanDays: _i(j['cleanDays'], 0),
      holdPainMax: _i(j['holdPainMax'], 10),
      requireSessions: _i(j['requireSessions'], 0),
      criteria: ((j['criteria'] as List?) ?? const [])
          .map((e) => Criterion(_s(e['id']), _s(e['label']), _s(e['kind'])))
          .toList(),
      note: _s(j['note']),
    );
  }
}

class Phase {
  final String id;
  final String title;
  final String purpose;
  final String cadence; // 'daily' | 'perWeek'
  final int weekOffset;
  final int nominalWeeks;
  final int sessionsPerWeek;
  final List<String> sessionLabels;
  final int minHoursBetweenSessions;
  final List<IsoBlock> blocks;
  final Tempo tempo;
  final String tempoNote;
  final List<String> warmup;
  final List<Exercise> exercises;
  final List<LoadBlock> loadBlocks;
  final String repMaxNote;
  final double weeklyIncreasePct;
  final double recalibrateBumpPct;
  final PhaseAdvance advance;
  final int? maintenanceFromPhaseWeek;
  final String maintenanceNote;
  final List<String> reintroduction;
  final List<String> permanentChanges;

  const Phase({
    required this.id,
    required this.title,
    required this.purpose,
    required this.cadence,
    required this.weekOffset,
    required this.nominalWeeks,
    required this.sessionsPerWeek,
    required this.sessionLabels,
    required this.minHoursBetweenSessions,
    required this.blocks,
    required this.tempo,
    required this.tempoNote,
    required this.warmup,
    required this.exercises,
    required this.loadBlocks,
    required this.repMaxNote,
    required this.weeklyIncreasePct,
    required this.recalibrateBumpPct,
    required this.advance,
    required this.maintenanceFromPhaseWeek,
    required this.maintenanceNote,
    required this.reintroduction,
    required this.permanentChanges,
  });

  factory Phase.from(Map j) => Phase(
        id: _s(j['id']),
        title: _s(j['title']),
        purpose: _s(j['purpose']),
        cadence: _s(j['cadence'], 'perWeek'),
        weekOffset: _i(j['weekOffset']),
        nominalWeeks: _i(j['nominalWeeks'], 1),
        sessionsPerWeek: _i(j['sessionsPerWeek']),
        sessionLabels: _sl(j['sessionLabels']),
        minHoursBetweenSessions: _i(j['minHoursBetweenSessions']),
        blocks: ((j['blocks'] as List?) ?? const [])
            .map((e) => IsoBlock.from(e as Map))
            .toList(),
        tempo: Tempo.from(j['tempo']),
        tempoNote: _s(j['tempoNote']),
        warmup: _sl(j['warmup']),
        exercises: ((j['exercises'] as List?) ?? const [])
            .map((e) => Exercise.from(e as Map))
            .toList(),
        loadBlocks: ((j['loadBlocks'] as List?) ?? const [])
            .map((e) => LoadBlock.from(e as Map))
            .toList(),
        repMaxNote: _s(j['repMaxNote']),
        weeklyIncreasePct: _d(j['weeklyIncreasePct']),
        recalibrateBumpPct: _d(j['recalibrateBumpPct']),
        advance: PhaseAdvance.from(j['advance']),
        maintenanceFromPhaseWeek: j['maintenanceFromPhaseWeek'] == null
            ? null
            : _i(j['maintenanceFromPhaseWeek']),
        maintenanceNote: _s(j['maintenanceNote']),
        reintroduction: _sl(j['reintroduction']),
        permanentChanges: _sl(j['permanentChanges']),
      );

  bool get isDaily => cadence == 'daily';

  /// The week number as the written program calls it, so the app and the paper
  /// document always agree.
  int docWeek(int phaseWeek) => weekOffset + phaseWeek;

  LoadBlock? blockFor(int phaseWeek) {
    for (final b in loadBlocks) {
      if (b.covers(phaseWeek)) return b;
    }
    return loadBlocks.isEmpty ? null : loadBlocks.last;
  }

  bool isMaintenance(int phaseWeek) =>
      maintenanceFromPhaseWeek != null && phaseWeek >= maintenanceFromPhaseWeek!;
}

class FlareSpec {
  final String definition;
  final int minDays;
  final int maxDays;
  final int seeSomeoneAfterDays;
  final double resumePct;
  final int rebuildSessions;
  final List<String> steps;
  final String note;

  const FlareSpec({
    required this.definition,
    required this.minDays,
    required this.maxDays,
    required this.seeSomeoneAfterDays,
    required this.resumePct,
    required this.rebuildSessions,
    required this.steps,
    required this.note,
  });

  factory FlareSpec.from(dynamic j) {
    j ??= const {};
    return FlareSpec(
      definition: _s(j['definition']),
      minDays: _i(j['minDays'], 3),
      maxDays: _i(j['maxDays'], 5),
      seeSomeoneAfterDays: _i(j['seeSomeoneAfterDays'], 7),
      resumePct: _d(j['resumePct'], 70),
      rebuildSessions: _i(j['rebuildSessions'], 6),
      steps: _sl(j['steps']),
      note: _s(j['note']),
    );
  }
}

class Restriction {
  final String part;
  final String status;
  const Restriction(this.part, this.status);
}

class TitledNote {
  final String title;
  final String text;
  const TitledNote(this.title, this.text);
}

class GoverningRule {
  final String headline;
  final List<List<String>> rows;
  final List<String> notes;
  const GoverningRule(this.headline, this.rows, this.notes);

  factory GoverningRule.from(dynamic j) {
    j ??= const {};
    return GoverningRule(
      _s(j['headline']),
      ((j['rows'] as List?) ?? const [])
          .map((r) => (r as List).map((e) => '$e').toList())
          .toList(),
      _sl(j['notes']),
    );
  }
}

class Program {
  final String id;
  final String name;
  final String subtitle;
  final List<String> sides;
  final GoverningRule governing;
  final List<Phase> phases;
  final FlareSpec flare;
  final List<Restriction> restrictions;
  final List<TitledNote> whatNotToDo;
  final List<String> redFlags;
  final List<List<String>> timeline;
  final String timelineNote;
  final String beforeStarting;

  const Program({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.sides,
    required this.governing,
    required this.phases,
    required this.flare,
    required this.restrictions,
    required this.whatNotToDo,
    required this.redFlags,
    required this.timeline,
    required this.timelineNote,
    required this.beforeStarting,
  });

  factory Program.fromJson(Map j) => Program(
        id: _s(j['id']),
        name: _s(j['name']),
        subtitle: _s(j['subtitle']),
        sides: _sl(j['sides']).isEmpty ? const ['L', 'R'] : _sl(j['sides']),
        governing: GoverningRule.from(j['governingRule']),
        phases: ((j['phases'] as List?) ?? const [])
            .map((e) => Phase.from(e as Map))
            .toList(),
        flare: FlareSpec.from(j['flare']),
        restrictions: ((j['restrictions'] as List?) ?? const [])
            .map((e) => Restriction(_s(e['part']), _s(e['status'])))
            .toList(),
        whatNotToDo: ((j['whatNotToDo'] as List?) ?? const [])
            .map((e) => TitledNote(_s(e['title']), _s(e['text'])))
            .toList(),
        redFlags: _sl(j['redFlags']),
        timeline: ((j['timeline'] as List?) ?? const [])
            .map((r) => (r as List).map((e) => '$e').toList())
            .toList(),
        timelineNote: _s(j['timelineNote']),
        beforeStarting: _s(j['beforeStarting']),
      );

  static Future<Program> load(String asset) async {
    final raw = await rootBundle.loadString(asset);
    return Program.fromJson(json.decode(raw) as Map);
  }

  Phase phaseById(String id) =>
      phases.firstWhere((p) => p.id == id, orElse: () => phases.first);

  Phase? nextPhaseAfter(String id) {
    final i = phases.indexWhere((p) => p.id == id);
    return (i < 0 || i + 1 >= phases.length) ? null : phases[i + 1];
  }

  /// The phase the flare protocol sends you back to — the first daily/isometric
  /// phase in the document.
  Phase get isoPhase =>
      phases.firstWhere((p) => p.isDaily, orElse: () => phases.first);
}
