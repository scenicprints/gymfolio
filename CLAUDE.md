# GymFolio — working rules

**Start with [ROADMAP.md](ROADMAP.md).** It has the architecture, the settled
decisions, what is shipped and what is next. This file is the short list of
things that will bite you.

## The shape of the app

The **engine decides, the widgets display**. `lib/engine.dart` owns every
progression decision — today's plan, whether the week advanced, when a flare
starts and ends, what the load should be. A screen that works out progression
for itself is a bug. Behaviour changes go in `engine.dart` with a test in
`test/engine_test.dart`.

The **program is data**: `assets/programs/*.json`. Nothing about biceps tendons
is compiled in. If you find yourself writing `if (exerciseId == 'bar-curl')` in
Dart, put it in the JSON instead.

## Before you say it works

- `flutter analyze` clean, `flutter test test/engine_test.dart` green.
- **Look at the screens you changed.** `flutter test test/shots_test.dart`
  writes every screen to `build/shots/*.png` at phone size. Green tests are not
  evidence a screen is usable.
- The shot harness loads a real system font on purpose. `flutter_test`'s own
  font draws every glyph as a box about twice the width of real text and will
  report overflows that do not exist on a phone. If you see a RenderFlex
  overflow only in tests, check the font before you "fix" the layout.
- Never `pumpAndSettle` a runner screen — the tempo metronome and the rest
  clock are periodic timers and it will hang until the test times out.

## Android

`android/` and `web/` are **generated and gitignored**. Recreate with:

```bash
bash tool/prepare_android.sh
```

That script applies the three things the generated project does not have:
release-manifest permissions (Flutter only puts `INTERNET` in the *debug*
manifest, so a release build loses all networking), the `GymFolio` launcher
label, and core-library desugaring, without which
`flutter_local_notifications` fails at dex time. CI runs the same script — if
you need a new permission or gradle change, it goes in there, not in a
committed `android/` file.

## Releasing

Bump `pubspec.yaml`, merge the feature branch `--no-ff`, tag `vX.Y.Z`, push.
CI builds, signs and publishes the APK; the app updates itself off that
Release. **CI fails if the tag and `pubspec.yaml` disagree** — that mismatch
leaves the phone permanently offered an update it already has.

Releases are **batched**: one tag with real notes, never a tag per fix.

The signing key is irreplaceable. Android refuses an in-app update across a
changed signature, and reinstalling erases the log. Do not rotate it.

## Things that are settled

Prescribes rather than records. Shared timeline, per-arm loads. Morning
check-in is better/same/worse. The barbell curl is one load gated by the right
arm. The written routine is followed as written — extra features are not
smuggled in as "improvements" to it. See the table in ROADMAP.md.

## Tone

Plain output. No clutter on screen, no decoration for its own sake. Copy in the
app says the true thing directly — "the week is decided by tomorrow morning,
not by this screen" — and never cheerleads. Expect flares; the program says
two or three are normal, so nothing in the UI may treat one as failure.
