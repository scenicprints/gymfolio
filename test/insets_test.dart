import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymfolio/app.dart';
import 'package:gymfolio/engine.dart';
import 'package:gymfolio/program.dart';
import 'package:gymfolio/screens/hsr_runner.dart';
import 'package:gymfolio/screens/iso_runner.dart';
import 'package:gymfolio/screens/today.dart';
import 'package:gymfolio/session_hw.dart';
import 'package:gymfolio/state.dart';
import 'package:gymfolio/theme.dart';

import 'test_fonts.dart';

/// Android 15 forces edge-to-edge: the gesture bar is drawn ON TOP of the app.
/// A bottom-anchored button that ignores it is unreachable, and the worst part
/// is that it still looks perfect in a screenshot — which is exactly how it
/// shipped the first time.
///
/// So these tests inject a real gesture inset and assert that nothing you have
/// to press ends up underneath it.

const double kGesture = 48.0; // logical px, roughly a Pixel's gesture bar

void applyGestureInset(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.viewPadding = const FakeViewPadding(bottom: kGesture * 2);
  tester.view.padding = const FakeViewPadding(bottom: kGesture * 2);
  addTearDown(tester.view.reset);
}

Program loadProgram() => Program.fromJson(
      json.decode(
        File('assets/programs/biceps_tendinopathy.json').readAsStringSync(),
      ) as Map,
    );

void stubPlatform() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw =
      File('assets/programs/biceps_tendinopathy.json').readAsBytesSync();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    final key = utf8.decode(message!.buffer.asUint8List());
    if (key == 'assets/programs/biceps_tendinopathy.json') {
      return ByteData.view(raw.buffer);
    }
    return null;
  });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.createTempSync('gymfolio_ins').path,
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

AppState phase2() => AppState(
      programId: 'biceps-tendinopathy-12wk',
      onboarded: true,
      phaseId: 'phase2',
      phaseWeek: 1,
      loads: {
        'incline-curl': {'L': 30, 'R': 25},
        'bar-curl': {'BOTH': 45},
        'screwdriver': {'L': 10, 'R': 7.5},
      },
    );

Widget app(AppModel model, Widget home) => AppScope(
      notifier: model,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: home,
      ),
    );

/// The bottom of [f] must sit above the gesture bar.
void expectClearOfGestureBar(WidgetTester tester, Finder f, String what) {
  final box = tester.getRect(f);
  final limit = tester.view.physicalSize.height / tester.view.devicePixelRatio -
      kGesture;
  expect(
    box.bottom <= limit + 0.5,
    isTrue,
    reason: '$what runs to ${box.bottom.toStringAsFixed(1)}, '
        'which is under the gesture bar starting at $limit',
  );
}

void main() {
  SessionHw.enabled = false;
  setUpAll(loadAppFonts);
  setUp(stubPlatform);

  testWidgets('the nav bar destinations clear the gesture bar', (tester) async {
    applyGestureInset(tester);
    final model = modelWith(phase2()..onboarded = true);
    await tester.pumpWidget(app(model, const _HomeHarness()));
    await tester.pump(const Duration(milliseconds: 50));

    expectClearOfGestureBar(
        tester, find.text('Today').last, 'the Today destination label');

    // ...and the bar's own background must still reach the bottom of the
    // screen, or you get a band of scaffold under it.
    final bar = tester.getRect(find.byType(NavigationBar));
    final container = tester.getRect(
      find.ancestor(
        of: find.byType(NavigationBar),
        matching: find.byType(Container),
      ).first,
    );
    expect(container.bottom, greaterThan(bar.bottom - 0.5),
        reason: 'the coloured container must extend past the bar itself');
  });

  testWidgets('the lifting runner start button clears the gesture bar',
      (tester) async {
    applyGestureInset(tester);
    final model = modelWith(phase2());
    await tester
        .pumpWidget(app(model, const HsrRunnerScreen(label: 'Session A')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Warm-up done — start'));
    await tester.pump(const Duration(milliseconds: 60));

    expectClearOfGestureBar(
        tester, find.widgetWithText(FilledButton, 'Start set'), 'Start set');
  });

  testWidgets('the isometric runner start button clears the gesture bar',
      (tester) async {
    applyGestureInset(tester);
    final p = loadProgram();
    final s = AppState(
        programId: p.id, onboarded: true, phaseId: 'phase1', phaseWeek: 1);
    final model = modelWith(s);
    await tester.pumpWidget(app(
      model,
      IsoRunnerScreen(block: p.isoPhase.blocks.first, label: 'Morning'),
    ));
    await tester.pump(const Duration(milliseconds: 60));

    expectClearOfGestureBar(
        tester, find.widgetWithText(FilledButton, 'Start'), 'Start');
  });

  testWidgets('Today scrolls its last row clear of the gesture bar',
      (tester) async {
    applyGestureInset(tester);
    final model = modelWith(phase2());
    await tester.pumpWidget(app(
      model,
      Scaffold(body: SafeArea(bottom: false, child: const TodayScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 50));

    final list = find.byType(ListView).first;
    final padding = tester.widget<ListView>(list).padding as EdgeInsets;
    expect(padding.bottom, greaterThanOrEqualTo(kGesture),
        reason: 'the scroll view must be able to lift content off the bar');
  });
}

/// The real home shell, minus the launch update check.
class _HomeHarness extends StatelessWidget {
  const _HomeHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SafeArea(bottom: false, child: TodayScreen()),
      bottomNavigationBar: Container(
        color: Tone.surface,
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: 0,
            height: 64,
            onDestinationSelected: (_) {},
            destinations: const [
              NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
              NavigationDestination(
                  icon: Icon(Icons.show_chart), label: 'Progress'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book), label: 'Program'),
              NavigationDestination(
                  icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
