# GymFolio

A training app that decides whether you earned the next week.

It is currently running one program: a 12-week bilateral distal biceps
tendinopathy loading block. Every progression decision in that program is
deterministic given the log, so the app makes them — what to do today, whether
the week advances or repeats at the same load, when a flare starts and ends,
and what the weights should be. It will become a general weight-lifting log;
the engine is already built for it.

**Read [ROADMAP.md](ROADMAP.md) before working on this.**

## What it does that a workout app does not

- **The morning check-in is the front door.** The signal that drives the whole
  program is captured about twelve hours after the session — better, same, or
  worse than baseline, per arm — and a logbook that only opens at the gym never
  asks for it.
- **The tempo runs the set.** Three seconds up, three seconds down, with a
  rising bar, a rep counter and a haptic at each turnaround. A weight you
  cannot control for three seconds down is the wrong weight, and that is the
  most common way this kind of block gets wasted.
- **It refuses.** 72 hours between sessions. No next week until three sessions
  came back clean the following morning. A red flag stops the program until
  someone has looked at it.
- **Both arms, separately loaded.** Except the barbell curl, which is one bar
  and one load, gated by the weaker arm.

## Install

Grab the latest `gymfolio.apk` from [Releases](../../releases) and open it on
your phone. After that the app updates itself: it checks the same endpoint on
launch, downloads in-app and hands the APK to Android's installer.

## Build

There is no local Android toolchain in the loop — GitHub Actions builds and
signs the APK. Locally:

```bash
flutter pub get
flutter test test/engine_test.dart     # the progression rules
flutter test test/shots_test.dart      # renders every screen to build/shots/
bash tool/prepare_android.sh           # regenerate + patch android/
flutter build apk --release
```

The repo tracks `lib/`, `assets/`, `test/`, `tool/` and `pubspec.yaml`. The
`android/` project is generated, because everything it needs is applied by a
script that CI runs too.

## Not medical advice

This runs a program its owner already had, written to be handed to a physio and
modified. The red-flag list is in the app and it stops the program rather than
suggesting anything.
