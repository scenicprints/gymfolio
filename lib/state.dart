import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the app knows, in one JSON file. Small, local, and written
/// atomically — a corrupt read must never present as "you have no history".

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseYmd(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysBetween(String a, String b) =>
    parseYmd(b).difference(parseYmd(a)).inDays;

enum Verdict { better, same, worse }

Verdict verdictFrom(String s) => Verdict.values.firstWhere(
      (v) => v.name == s,
      orElse: () => Verdict.same,
    );

/// The morning check-in. Two arms, three answers, and — only when you say
/// worse — the one follow-up that separates "back off a week" from "flare".
class CheckIn {
  final String date;
  final Map<String, Verdict> verdicts; // side -> verdict
  final bool flare;
  final List<String> redFlags;
  final String note;

  const CheckIn({
    required this.date,
    required this.verdicts,
    this.flare = false,
    this.redFlags = const [],
    this.note = '',
  });

  bool get anyWorse => verdicts.values.any((v) => v == Verdict.worse);
  bool get allBetter => verdicts.values.every((v) => v == Verdict.better);
  bool get clean => !anyWorse;

  Map<String, dynamic> toJson() => {
        'date': date,
        'verdicts': verdicts.map((k, v) => MapEntry(k, v.name)),
        'flare': flare,
        'redFlags': redFlags,
        'note': note,
      };

  factory CheckIn.fromJson(Map j) => CheckIn(
        date: '${j['date']}',
        verdicts: ((j['verdicts'] as Map?) ?? {})
            .map((k, v) => MapEntry('$k', verdictFrom('$v'))),
        flare: j['flare'] == true,
        redFlags: ((j['redFlags'] as List?) ?? const []).map((e) => '$e').toList(),
        note: '${j['note'] ?? ''}',
      );
}

/// One logged set. Deliberately general — exercise, set number, side, load,
/// reps. This is the row a lifting log needs too.
class SetEntry {
  final String exerciseId;
  final int setIndex;
  final String side; // 'L' | 'R' | 'BOTH'
  final double load;
  final int reps;
  final bool done;

  const SetEntry({
    required this.exerciseId,
    required this.setIndex,
    required this.side,
    required this.load,
    required this.reps,
    this.done = true,
  });

  SetEntry copyWith({double? load, int? reps, bool? done}) => SetEntry(
        exerciseId: exerciseId,
        setIndex: setIndex,
        side: side,
        load: load ?? this.load,
        reps: reps ?? this.reps,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'setIndex': setIndex,
        'side': side,
        'load': load,
        'reps': reps,
        'done': done,
      };

  factory SetEntry.fromJson(Map j) => SetEntry(
        exerciseId: '${j['exerciseId']}',
        setIndex: (j['setIndex'] as num?)?.toInt() ?? 1,
        side: '${j['side']}',
        load: (j['load'] as num?)?.toDouble() ?? 0,
        reps: (j['reps'] as num?)?.toInt() ?? 0,
        done: j['done'] != false,
      );
}

class SessionLog {
  final String id;
  final String date; // yyyy-MM-dd
  final String at; // full ISO timestamp
  final String phaseId;
  final int phaseWeek;
  final String kind; // 'iso' | 'hsr'
  final String blockId; // iso block id, or '' for hsr
  final String label; // 'Morning' / 'Session A'
  final Map<String, double> painDuring; // side -> 0..10
  final List<SetEntry> sets;
  final String note;

  const SessionLog({
    required this.id,
    required this.date,
    required this.at,
    required this.phaseId,
    required this.phaseWeek,
    required this.kind,
    required this.blockId,
    required this.label,
    required this.painDuring,
    required this.sets,
    this.note = '',
  });

  double get worstPain =>
      painDuring.values.isEmpty ? 0 : painDuring.values.reduce((a, b) => a > b ? a : b);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'at': at,
        'phaseId': phaseId,
        'phaseWeek': phaseWeek,
        'kind': kind,
        'blockId': blockId,
        'label': label,
        'painDuring': painDuring,
        'sets': sets.map((s) => s.toJson()).toList(),
        'note': note,
      };

  factory SessionLog.fromJson(Map j) => SessionLog(
        id: '${j['id']}',
        date: '${j['date']}',
        at: '${j['at']}',
        phaseId: '${j['phaseId']}',
        phaseWeek: (j['phaseWeek'] as num?)?.toInt() ?? 1,
        kind: '${j['kind']}',
        blockId: '${j['blockId'] ?? ''}',
        label: '${j['label'] ?? ''}',
        painDuring: ((j['painDuring'] as Map?) ?? {})
            .map((k, v) => MapEntry('$k', (v as num).toDouble())),
        sets: ((j['sets'] as List?) ?? const [])
            .map((e) => SetEntry.fromJson(e as Map))
            .toList(),
        note: '${j['note'] ?? ''}',
      );
}

class FlareRecord {
  final String startedOn;
  final String? endedOn;
  final int phaseWeek;
  const FlareRecord(this.startedOn, this.endedOn, this.phaseWeek);

  Map<String, dynamic> toJson() =>
      {'startedOn': startedOn, 'endedOn': endedOn, 'phaseWeek': phaseWeek};
  factory FlareRecord.fromJson(Map j) => FlareRecord(
        '${j['startedOn']}',
        j['endedOn'] == null ? null : '${j['endedOn']}',
        (j['phaseWeek'] as num?)?.toInt() ?? 0,
      );
}

class Reminders {
  bool enabled;
  int checkInHour;
  int checkInMinute;
  int trainHour;
  int trainMinute;
  int eveningHour;
  int eveningMinute;

  Reminders({
    this.enabled = true,
    this.checkInHour = 7,
    this.checkInMinute = 0,
    this.trainHour = 8,
    this.trainMinute = 0,
    this.eveningHour = 19,
    this.eveningMinute = 30,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'checkInHour': checkInHour,
        'checkInMinute': checkInMinute,
        'trainHour': trainHour,
        'trainMinute': trainMinute,
        'eveningHour': eveningHour,
        'eveningMinute': eveningMinute,
      };

  factory Reminders.fromJson(Map j) => Reminders(
        enabled: j['enabled'] != false,
        checkInHour: (j['checkInHour'] as num?)?.toInt() ?? 7,
        checkInMinute: (j['checkInMinute'] as num?)?.toInt() ?? 0,
        trainHour: (j['trainHour'] as num?)?.toInt() ?? 8,
        trainMinute: (j['trainMinute'] as num?)?.toInt() ?? 0,
        eveningHour: (j['eveningHour'] as num?)?.toInt() ?? 19,
        eveningMinute: (j['eveningMinute'] as num?)?.toInt() ?? 30,
      );
}

typedef LoadMap = Map<String, Map<String, double>>; // exerciseId -> side -> load

LoadMap _loads(dynamic j) => ((j as Map?) ?? {}).map(
      (k, v) => MapEntry(
        '$k',
        ((v as Map?) ?? {}).map((s, l) => MapEntry('$s', (l as num).toDouble())),
      ),
    );

LoadMap cloneLoads(LoadMap m) =>
    m.map((k, v) => MapEntry(k, Map<String, double>.from(v)));

const kModeNormal = 'normal';
const kModeFlare = 'flare';
const kModeStopped = 'stopped';

class AppState {
  String programId;
  bool onboarded;
  String startDate;
  String baselineNote;

  String phaseId;
  int phaseWeek;
  String weekStart;

  String mode;
  String? flareStart;
  LoadMap flareLoads;
  LoadMap rebuildTarget;
  int rebuildSessionsLeft;

  /// Set when the rep scheme changes and the working loads must be re-picked
  /// rather than nudged 5%.
  bool needsRecalibration;

  LoadMap loads;
  bool baselineDownConfirmed;

  List<CheckIn> checkIns;
  List<SessionLog> sessions;
  List<FlareRecord> flares;
  Reminders reminders;

  AppState({
    required this.programId,
    this.onboarded = false,
    String? startDate,
    this.baselineNote = '',
    this.phaseId = '',
    this.phaseWeek = 1,
    String? weekStart,
    this.mode = kModeNormal,
    this.flareStart,
    LoadMap? flareLoads,
    LoadMap? rebuildTarget,
    this.rebuildSessionsLeft = 0,
    this.needsRecalibration = false,
    LoadMap? loads,
    this.baselineDownConfirmed = false,
    List<CheckIn>? checkIns,
    List<SessionLog>? sessions,
    List<FlareRecord>? flares,
    Reminders? reminders,
  })  : startDate = startDate ?? ymd(DateTime.now()),
        weekStart = weekStart ?? ymd(DateTime.now()),
        flareLoads = flareLoads ?? {},
        rebuildTarget = rebuildTarget ?? {},
        loads = loads ?? {},
        checkIns = checkIns ?? [],
        sessions = sessions ?? [],
        flares = flares ?? [],
        reminders = reminders ?? Reminders();

  CheckIn? checkInOn(String date) {
    for (final c in checkIns) {
      if (c.date == date) return c;
    }
    return null;
  }

  List<SessionLog> sessionsOn(String date) =>
      sessions.where((s) => s.date == date).toList();

  double loadFor(String exerciseId, String side) =>
      loads[exerciseId]?[side] ?? 0;

  void setLoad(String exerciseId, String side, double v) {
    (loads[exerciseId] ??= {})[side] = v;
  }

  Map<String, dynamic> toJson() => {
        'schema': 1,
        'programId': programId,
        'onboarded': onboarded,
        'startDate': startDate,
        'baselineNote': baselineNote,
        'phaseId': phaseId,
        'phaseWeek': phaseWeek,
        'weekStart': weekStart,
        'mode': mode,
        'flareStart': flareStart,
        'flareLoads': flareLoads,
        'rebuildTarget': rebuildTarget,
        'rebuildSessionsLeft': rebuildSessionsLeft,
        'needsRecalibration': needsRecalibration,
        'loads': loads,
        'baselineDownConfirmed': baselineDownConfirmed,
        'checkIns': checkIns.map((c) => c.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'flares': flares.map((f) => f.toJson()).toList(),
        'reminders': reminders.toJson(),
      };

  factory AppState.fromJson(Map j) => AppState(
        programId: '${j['programId'] ?? ''}',
        onboarded: j['onboarded'] == true,
        startDate: '${j['startDate'] ?? ymd(DateTime.now())}',
        baselineNote: '${j['baselineNote'] ?? ''}',
        phaseId: '${j['phaseId'] ?? ''}',
        phaseWeek: (j['phaseWeek'] as num?)?.toInt() ?? 1,
        weekStart: '${j['weekStart'] ?? ymd(DateTime.now())}',
        mode: '${j['mode'] ?? kModeNormal}',
        flareStart: j['flareStart'] == null ? null : '${j['flareStart']}',
        flareLoads: _loads(j['flareLoads']),
        rebuildTarget: _loads(j['rebuildTarget']),
        rebuildSessionsLeft: (j['rebuildSessionsLeft'] as num?)?.toInt() ?? 0,
        needsRecalibration: j['needsRecalibration'] == true,
        loads: _loads(j['loads']),
        baselineDownConfirmed: j['baselineDownConfirmed'] == true,
        checkIns: ((j['checkIns'] as List?) ?? const [])
            .map((e) => CheckIn.fromJson(e as Map))
            .toList(),
        sessions: ((j['sessions'] as List?) ?? const [])
            .map((e) => SessionLog.fromJson(e as Map))
            .toList(),
        flares: ((j['flares'] as List?) ?? const [])
            .map((e) => FlareRecord.fromJson(e as Map))
            .toList(),
        reminders: Reminders.fromJson((j['reminders'] as Map?) ?? const {}),
      );

  String export() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Local store. File on Android/desktop, SharedPreferences on web so the
/// browser preview behaves the same as the phone.
class Store {
  static const _prefsKey = 'gymfolio_state_v1';
  static const _fileName = 'gymfolio_state.json';

  File? _file;

  Future<File> _resolve() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    return _file = File('${dir.path}/$_fileName');
  }

  Future<AppState?> load() async {
    try {
      if (kIsWeb) {
        final p = await SharedPreferences.getInstance();
        final raw = p.getString(_prefsKey);
        if (raw == null || raw.isEmpty) return null;
        return AppState.fromJson(json.decode(raw) as Map);
      }
      final f = await _resolve();
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return null;
      return AppState.fromJson(json.decode(raw) as Map);
    } catch (e) {
      // A corrupt or unreadable file must not look like a fresh install.
      debugPrint('GymFolio: state load failed: $e');
      rethrow;
    }
  }

  Future<void> save(AppState s) async {
    final raw = json.encode(s.toJson());
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, raw);
      return;
    }
    final f = await _resolve();
    // Write to a sibling then rename, so a kill mid-write cannot truncate the log.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(raw, flush: true);
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }
}
