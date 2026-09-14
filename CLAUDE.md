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

## Exercise art

`lib/exercise_art.dart` draws every movement. Two rules:

- **Pick the view that can show the thing.** Supination is invisible from the
  side, so those movements are drawn end-on down the forearm. An isometric hold
  has nothing to animate, so the force arrows pulse instead of the limb.
- **`simplified: true` is thumbnail mode** and must stay cheap to read: no
  scenery, no path arcs, no inset diagrams. If you add a decorative element,
  guard it.

The demo widget animates at the movement's real tempo. Isometrics are passed a
zero tempo — guard any division by the up/down total, or you get a NaN curve
assertion at runtime.

## Look and feel

`theme.dart` is the whole design system. Use `display()` for numbers,
`stencil()` for small-caps labels, and the `Readout` / `Pill` / `Panel(rail:)`
primitives rather than rolling one-off styles.

`Panel` is a `Material`, deliberately. Ink splashes paint on the nearest
Material ancestor, so a plain decorated `Container` silently eats the tap
feedback of every `ListTile` inside it. Do not "simplify" it back.

**The colour rule is not decorative:** blue means the left arm and coral means
the right arm, everywhere. Do not use either for anything else — that is why
the primary action is near-white. If you need a new highlight, take it from the
semantic set (good / hold / bad) or `accent`.

Fonts are bundled from `assets/fonts` under the SIL OFL. Keep `OFL.txt` with
them.

## Session hardware

`session_hw.dart` owns the wake lock and the audio cues. Two things to know:

- **Everything is guarded and lazy.** Constructing an `AudioPlayer` eagerly
  spins up the plugin's global scope, which throws where there is no platform
  side — widget tests most obviously — *before* any try/catch can help. Keep
  the players behind `_prepare()`.
- **`SessionHw.enabled = false`** turns the whole subsystem into a no-op. The
  shot harness sets it; so should anything else without a platform side.

## Android

`android/` and `web/` are **generated and gitignored**. Recreate with:

```bash
bash tool/prepare_android.sh
```

That script applies the four things the generated project does not have:
release-manifest permissions (Flutter only puts `INTERNET` in the *debug*
manifest, so a release build loses all networking), the `GymFolio` launcher
label, core-library desugaring (without which `flutter_local_notifications`
fails at dex time), and the launcher icon — which must run after `android/`
exists, since that is where the mipmaps are written.

Regenerating the icon: `python tool/make_icon.py`. Judge it from
`assets/icon/_launcher_preview.png`, never `icon.png` — the generated adaptive
XML insets the foreground a further 16% on top of your artwork, and the preview
simulates that.

CI runs the same script, so if you need a new permission or a gradle change it
goes in there, not in a committed `android/` file.

## The updater

`update_checker.dart`. Two rules learned the hard way:

- **`OpenFilex.open` returns a failure, it does not throw.** Ignoring the
  result is how a denied "Install unknown apps" permission becomes silence.
  Handle every `ResultType`.
- **Never hand the installer an unverified file.** Check the HTTP status, the
  byte count against `Content-Length`, and the zip header. An HTML error page
  saved as `.apk` produces "problem parsing the package", which blames the
  wrong thing.

The browser fallback is always on screen. It is slower, and it works when
nothing else does.

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
