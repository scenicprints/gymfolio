import 'package:flutter/material.dart';

import 'engine.dart';
import 'notifications.dart';
import 'program.dart';
import 'session_hw.dart';
import 'state.dart';

const kProgramAsset = 'assets/programs/biceps_tendinopathy.json';

/// One model holding the program document, the log, and the engine that reads
/// both. Every mutation goes through here so nothing can change the log without
/// it being saved and the progression re-evaluated.
class AppModel extends ChangeNotifier {
  final Store store = Store();

  Program? program;
  AppState? state;
  Engine? engine;

  bool loading = true;
  Object? loadError;

  bool get ready => program != null && state != null && engine != null;

  Future<void> boot() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final p = await Program.load(kProgramAsset);
      AppState? s;
      try {
        s = await store.load();
      } catch (e) {
        // Surface it rather than silently starting a fresh log over the top of
        // one that exists but could not be read.
        loadError = e;
        loading = false;
        program = p;
        notifyListeners();
        return;
      }
      s ??= AppState(programId: p.id, phaseId: p.phases.first.id);
      if (s.phaseId.isEmpty) s.phaseId = p.phases.first.id;
      program = p;
      state = s;
      engine = Engine(p, s);
      SessionHw.muted = !s.soundOn;
      loading = false;
      notifyListeners();
      await Nudges.sync(this);
    } catch (e, st) {
      debugPrint('GymFolio boot failed: $e\n$st');
      loadError = e;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> persist() async {
    final s = state;
    if (s == null) return;
    await store.save(s);
    notifyListeners();
    await Nudges.sync(this);
  }

  // ------------------------------------------------------------- actions

  Future<void> startProgram({required String baselineNote}) async {
    final s = state!;
    s.onboarded = true;
    s.baselineNote = baselineNote;
    s.startDate = ymd(DateTime.now());
    s.weekStart = ymd(DateTime.now());
    s.phaseId = program!.phases.first.id;
    s.phaseWeek = 1;
    await persist();
  }

  Future<void> submitCheckIn(CheckIn c) async {
    engine!.applyCheckIn(c);
    await persist();
  }

  Future<void> finishSession(SessionLog s) async {
    engine!.completeSession(s);
    await persist();
  }

  Future<void> editSession(SessionLog s) async {
    engine!.updateSession(s);
    await persist();
  }

  Future<void> removeSession(String id) async {
    engine!.deleteSession(id);
    await persist();
  }

  Future<void> beginSession(InProgress p) async {
    engine!.beginSession(p);
    await persist();
  }

  /// Called after every logged set. Saves without a full notify storm.
  Future<void> saveProgress(InProgress p) async {
    engine!.updateProgress(p);
    await store.save(state!);
  }

  Future<void> abandonSession() async {
    engine!.abandonSession();
    await persist();
  }

  Future<void> confirmBaselineDown(bool v) async {
    state!.baselineDownConfirmed = v;
    await persist();
  }

  Future<void> advancePhase() async {
    engine!.advancePhase(DateTime.now());
    await persist();
  }

  Future<void> resumeFromFlare() async {
    engine!.resumeFromFlare(DateTime.now());
    await persist();
  }

  Future<void> clearStop() async {
    engine!.clearStop();
    await persist();
  }

  Future<void> calibrate(Map<String, Map<String, double>> loads) async {
    engine!.applyCalibration(loads);
    await persist();
  }

  Future<void> setLoad(String exerciseId, String side, double v) async {
    state!.setLoad(exerciseId, side, roundLoad(v));
    await persist();
  }

  Future<void> setSoundOn(bool v) async {
    state!.soundOn = v;
    SessionHw.muted = !v;
    await persist();
  }

  Future<void> saveReminders(Reminders r) async {
    state!.reminders = r;
    await persist();
  }

  Future<void> resetEverything() async {
    final p = program!;
    state = AppState(programId: p.id, phaseId: p.phases.first.id);
    engine = Engine(p, state!);
    await persist();
  }
}

/// Plumbing so any screen can reach the model without a package.
class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({super.key, required AppModel super.notifier, required super.child});

  static AppModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope?.notifier != null, 'AppScope missing above this widget');
    return scope!.notifier!;
  }
}
