@Tags(['shots'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymfolio/app.dart';
import 'package:gymfolio/engine.dart';
import 'package:gymfolio/program.dart';
import 'package:gymfolio/screens/calibrate.dart';
import 'package:gymfolio/screens/hsr_runner.dart';
import 'package:gymfolio/screens/progress.dart';
import 'package:gymfolio/screens/today.dart';
import 'package:gymfolio/state.dart';
import 'package:gymfolio/theme.dart';

/// A screenshot harness. Green tests are not evidence that a screen is usable,
/// so this renders the real widgets at phone size and writes PNGs to
/// build/shots/ where they can actually be looked at.
///
///   flutter test test/shots_test.dart
///
/// Not part of the normal run — see dart_test.yaml.

const _size = Size(390, 844);

Future<void> shoot(WidgetTester tester, String name) async {
  // Bounded pumps, never pumpAndSettle: the tempo metronome and the rest clock
  // are periodic timers, and a settle would wait for them forever.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  // toImage needs the real event loop; inside the fake-async test zone its
  // future never completes.
  final bytes = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final dir = Directory('build/shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!);
}

Program loadProgram() => Program.fromJson(
      json.decode(
        File('assets/programs/biceps_tendinopathy.json').readAsStringSync(),
      ) as Map,
    );

/// Serve the program asset to rootBundle so widgets under test load the real
/// document rather than a stub.
void stubAssets() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw =
      File('assets/programs/biceps_tendinopathy.json').readAsBytesSync();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == 'assets/programs/biceps_tendinopathy.json') {
        return ByteData.view(Uint8List.fromList(raw).buffer);
      }
      return null;
    },
  );
}

AppModel modelWith(AppState s) {
  final p = loadProgram();
  final m = AppModel();
  m.program = p;
  m.state = s;
  m.engine = Engine(p, s);
  m.loading = false;
  return m;
}

Widget host(AppModel model, Widget child) => AppScope(
      notifier: model,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme().copyWith(
          textTheme: buildTheme().textTheme.apply(fontFamily: 'Roboto'),
        ),
        home: Scaffold(body: SafeArea(child: child)),
      ),
    );

AppState phase1State() {
  final today = DateTime.now();
  final s = AppState(
    programId: 'biceps-tendinopathy-12wk',
    onboarded: true,
    phaseId: 'phase1',
    phaseWeek: 2,
    startDate: ymd(today.subtract(const Duration(days: 8))),
    baselineNote: 'Right aches lifting a full kettle. Left only after pressing.',
  );
  for (var i = 8; i >= 1; i--) {
    final d = today.subtract(Duration(days: i));
    s.checkIns.add(CheckIn(
      date: ymd(d),
      verdicts: {
        'L': i > 5 ? Verdict.same : Verdict.better,
        'R': i == 4 ? Verdict.worse : Verdict.same,
      },
    ));
    s.sessions.add(SessionLog(
      id: '$i',
      date: ymd(d),
      at: d.toIso8601String(),
      phaseId: 'phase1',
      phaseWeek: 2,
      kind: 'iso',
      blockId: 'iso-flexion',
      label: 'Morning',
      painDuring: const {'L': 2, 'R': 3},
      sets: const [],
    ));
  }
  return s;
}

AppState phase2State() {
  final today = DateTime.now();
  final s = AppState(
    programId: 'biceps-tendinopathy-12wk',
    onboarded: true,
    phaseId: 'phase2',
    phaseWeek: 3,
    startDate: ymd(today.subtract(const Duration(days: 35))),
    weekStart: ymd(today.subtract(const Duration(days: 2))),
    loads: {
      'incline-curl': {'L': 32.5, 'R': 27.5},
      'bar-curl': {'BOTH': 47.5},
      'screwdriver': {'L': 12.5, 'R': 10},
    },
  );
  s.flares.add(FlareRecord(
      ymd(today.subtract(const Duration(days: 18))),
      ymd(today.subtract(const Duration(days: 14))),
      2));
  for (var i = 30; i >= 2; i -= 3) {
    final d = today.subtract(Duration(days: i));
    s.sessions.add(SessionLog(
      id: '$i',
      date: ymd(d),
      at: d.toIso8601String(),
      phaseId: 'phase2',
      phaseWeek: 3,
      kind: 'hsr',
      blockId: '',
      label: 'Session A',
      painDuring: const {'L': 3, 'R': 4},
      sets: [
        SetEntry(
            exerciseId: 'incline-curl',
            setIndex: 1,
            side: 'L',
            load: 32.5 - i * 0.2,
            reps: 15),
        SetEntry(
            exerciseId: 'incline-curl',
            setIndex: 1,
            side: 'R',
            load: 27.5 - i * 0.2,
            reps: 15),
        SetEntry(
            exerciseId: 'bar-curl',
            setIndex: 1,
            side: 'BOTH',
            load: 47.5 - i * 0.3,
            reps: 15),
      ],
    ));
    s.checkIns.add(CheckIn(
      date: ymd(d.add(const Duration(days: 1))),
      verdicts: const {'L': Verdict.better, 'R': Verdict.same},
    ));
  }
  return s;
}

/// flutter_test ships a placeholder font that draws every glyph as a solid
/// box roughly twice the width of real text, which invents overflows that do
/// not exist on a phone. Register a real face so the geometry in these shots
/// is the geometry you will actually get.
Future<void> loadRealFont() async {
  for (final path in const [
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fontsrial.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ]) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final bytes = f.readAsBytesSync();
    for (final family in const ['Roboto', 'packages/gymfolio/Roboto']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
      await loader.load();
    }
    return;
  }
}

void main() {
  setUp(stubAssets);
  setUpAll(loadRealFont);

  testWidgets('today - phase 1', (tester) async {
    tester.view.physicalSize = _size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(modelWith(phase1State()), const TodayScreen()));
    await shoot(tester, '01-today-phase1');
  });

  testWidgets('today - phase 2 with a session due', (tester) async {
    tester.view.physicalSize = _size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(modelWith(phase2State()), const TodayScreen()));
    await shoot(tester, '02-today-phase2');
  });

  testWidgets('today - mid flare', (tester) async {
    tester.view.physicalSize = _size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final s = phase2State();
    s.mode = kModeFlare;
    s.flareStart = ymd(DateTime.now().subtract(const Duration(days: 3)));
    s.checkIns.add(CheckIn(
      date: ymd(DateTime.now()),
      verdicts: const {'L': Verdict.same, 'R': Verdict.same},
    ));
    await tester.pumpWidget(host(modelWith(s), const TodayScreen()));
    await shoot(tester, '03-today-flare');
  });

  testWidgets('today - stopped on a red flag', (tester) async {
    tester.view.physicalSize = _size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final s = phase2State();
    s.mode = kModeStopped;
    s.checkIns.add(CheckIn(
      date: ymd(DateTime.now()),
      verdicts: const {'L': Verdict.same, 'R': Verdict.worse},
      redFlags: const ['Numbness or tingling into the forearm or hand'],
    ));
    await tester.pumpWidget(host(modelWith(s), const TodayScreen()));
    await shoot(tester, '04-today-stopped');
  });

  testWidgets('session - warm-up and prescription', (tester) async {
    tester.view.physicalSize = _size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        host(modelWith(phase2State()), const HsrRunnerScreen(label: 'Session B')));
    await shoot(tester, '05-session-warmup');
  });

  testWidgets('session - tempo metronome mid-rep', (tester) async {
    tester.view.physicalSize = _size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        host(modelWith(phase2State()), const HsrRunnerScreen(label: 'Session B')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Warm-up done — start'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Start set'));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 100));
    await shoot(tester, '06-session-tempo');
  });

  testWidgets('progress', (tester) async {
    tester.view.physicalSize = _size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(host(modelWith(phase2State()), const ProgressScreen()));
    await shoot(tester, '07-progress');
  });

  testWidgets('calibrate', (tester) async {
    tester.view.physicalSize = _size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final s = phase2State();
    s.needsRecalibration = true;
    await tester.pumpWidget(host(modelWith(s), const CalibrateScreen()));
    await shoot(tester, '08-calibrate');
  });
}
