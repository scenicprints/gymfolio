# GymFolio — roadmap

**Read this first if you are picking up this repo cold.** It says what the app
is, what is done, what is next, and the handful of decisions that are settled
and should not be relitigated.

---

## What this is

A training app that **decides whether you earned the next week**, not a
logbook that remembers what you lifted.

It is running one program right now — a 12-week bilateral distal biceps
tendinopathy loading block (`docs/biceps-tendinopathy-program.md`). Every
progression decision in that program is deterministic given the log, so the app
makes them: what to do today, whether the week advances or repeats, when a
flare starts, when it ends, and what the weights should be.

**It becomes a general weight-lifting log.** That is the stated destination, and
the architecture is already built for it — see *The generalisation* below.
Nothing about biceps tendons is compiled into the app.

---

## Settled decisions — do not relitigate

| Decision | Why |
|---|---|
| **The app prescribes, it does not just record.** | It opens to "Session B, week 6: incline curl 4×12, L 35, R 27.5" and refuses week 7 until the 24-hour rule came back clean three sessions running. |
| **Shared timeline, per-arm loads.** | Both arms move through the same phase and week; only the loads differ. A flare sets both arms back. This was chosen deliberately over independent per-arm timelines. |
| **Morning check-in is better / same / worse**, not a 0–10 rating. | Owner's call. The app shows the recorded baseline text next to the question so "same" does not drift. |
| **The barbell curl stays a barbell curl.** | One bar, one load, gated by the right arm. Modelled with `unilateral: false` on the exercise, which is why that flag exists. |
| **Follow the written routine.** | Restrictions, warm-up, red flags and timeline ship as reference content on the Program tab, not as extra tracked features. |
| **The program is data, never code.** | `assets/programs/*.json`. A physio's modifications are a JSON edit. |

---

## Architecture

```
lib/
  program.dart      the program DOCUMENT model — parses the JSON
  state.dart        the LOG — check-ins, sessions, loads; atomic local JSON
  engine.dart       the DECISIONS — today's plan, gates, flares, load maths
  app.dart          AppModel: holds program + state + engine, persists, notifies
  notifications.dart  daily reminders, fully guarded (app works without them)
  update_checker.dart in-app updater off GitHub Releases
  theme.dart        palette (`Tone`) and the shared Panel / SideChip widgets
  screens/          today, checkin, iso_runner, hsr_runner, calibrate,
                    progress, program_view, settings, onboarding, pain_sheet
assets/programs/biceps_tendinopathy.json   the program document
tool/prepare_android.sh                    regenerates + patches android/
test/engine_test.dart                      25 tests over the decision rules
test/shots_test.dart                       renders every screen to build/shots/
```

**The engine is the app.** Widgets read `Engine.todayPlan(now)` and
`Engine.prescription()`; they never work out progression themselves. If you are
changing behaviour, you are almost certainly changing `engine.dart` and adding a
test, not editing a screen.

**`android/` and `web/` are generated and gitignored.** Run
`bash tool/prepare_android.sh` to recreate the Android project with its three
required patches (permissions, launcher label, core-library desugaring for
`flutter_local_notifications`). CI runs exactly that script, so what you test
locally is what ships.

---

## How a release ships

1. Bump `version:` in `pubspec.yaml`.
2. Commit, merge the feature branch `--no-ff`.
3. `git tag vX.Y.Z && git push --tags`.
4. GitHub Actions builds, signs and attaches `gymfolio.apk` to a Release.
5. The phone finds it — the app checks `/releases/latest` on launch, compares
   against its own version, downloads the APK in-app with a progress bar and
   hands it to Android's installer.

CI fails the build if the tag and `pubspec.yaml` disagree, because a mismatch
means the phone is offered an update to a version it already has and the dialog
never goes away.

**Releases are batched.** Work lands on a feature branch and ships as one tag
with real notes — not a tag per fix.

### The signing key

`KEYSTORE_B64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS` are repo secrets. Android only
accepts an in-app update when the new APK carries **the same signature** as the
installed one. If that key is lost, every future version has to be installed by
uninstalling the app first — which erases the log. It is backed up outside this
repo; keep it that way and never rotate it.

---

## Status

### Shipped — v0.1.0

- **The engine.** Phase/week position, today's plan, the 72-hour guard, the
  24-hour gate, week advance/repeat, load maths, flare entry and exit, the
  rebuild ramp, red-flag stop. 25 tests.
- **Program document** — all three phases, both isometric blocks, three
  exercises with laterality and week-dependent cues, the five load blocks, the
  flare spec, restrictions, red flags, timeline.
- **Onboarding** — the pre-start exam note, baseline capture, phase overview.
- **Morning check-in** — better/same/worse per arm; the one follow-up question
  that separates "repeat the week" from "run the flare protocol"; red-flag
  screen one tap away.
- **Phase 1 runner** — 2s ramp, 45s hold, arms alternating inside the rest, 5
  sets, 2-minute rest, haptics and a click at every transition.
- **Phase 2 runner** — warm-up card, per-exercise prescription, the **tempo
  metronome** (3s up / 3s down with a rising bar, rep counter, haptic at each
  turnaround), inline load adjustment, rest timer, per-set logging.
- **Progress** — the week ladder with flares marked, per-arm load sparklines,
  and the session log with the next-morning verdict against each session.
- **Program tab** — the whole written document, rendered from the same JSON the
  engine runs on.
- **Settings** — reminder times, JSON export through the share sheet, manual
  update check, start-over.
- **Reminders** — morning check-in daily; twice-daily nudges while on
  isometrics or in a flare, once daily otherwise.
- **CI + in-app updater.**

### Next — v0.2.0 (nothing started)

Ordered by how much they matter in the first month of actually using it.

- [ ] **Session resume.** Kill the app mid-session and the sets logged so far
      are gone. Persist an in-progress session and offer to resume.
- [ ] **Wake lock during a session.** The screen sleeps during a 3-minute rest.
- [ ] **Sound, not just the system click.** The tempo cue needs to be audible
      over a gym; `SystemSound.click` may not cut it. Bundle a short tick.
- [ ] **Edit a logged session.** Wrong reps or a mistyped pain score currently
      cannot be corrected, and pain feeds the Phase 1 gate.
- [ ] **Physio export.** A readable one-page summary (the program's own
      tracking-log table) rather than raw JSON.
- [ ] **Backup that survives the phone.** Export is manual today. Consider a
      private `gymfolio-data` repo, matching the pattern used by bodycomp and
      fuelwise.
- [ ] **Launcher icon.** Currently the stock Flutter icon.

### Later

- [ ] **Phase 3 reintroduction checklist.** Weeks 13–20 add pressing back at
      ~10%/week and restore depth after two clean weeks. That is trackable, and
      right now it is only reference text.
- [ ] **Plateau detection.** The document says a 6–8 week plateau with no change
      is the point to seek imaging. The app has the data to notice.
- [ ] **Program editor in-app**, so a physio's changes do not need a rebuild.

---

## The generalisation

Every concept in the rehab program has a strength-training twin, which is why
the engine can carry both:

| Tendon program | General training |
|---|---|
| Program → phase → week → session | Program → mesocycle → week → session |
| The 24-hour pain rule gates the next week | Autoregulation gates the next week |
| Flare protocol | Deload |
| Morning check-in | Readiness check |
| 3s/3s tempo | Tempo prescription |
| Per-arm loads | Per-side loads |
| 72 hours between sessions | Recovery spacing per muscle group |

**What has to change to become a general lifting log:**

1. **The gate becomes pluggable.** `Engine._evaluateWeek` hardcodes the
   24-hour rule. Extract it behind a `Gate` interface with the pain rule as one
   implementation and "hit all prescribed reps at tempo" as another; the
   program JSON names which gate it uses.
2. **Multiple programs.** `AppState` already carries `programId`; the app just
   needs a picker and one state per program.
3. **A free-form session.** Today every session comes from a program. A general
   log needs "just log what I did", which is a `SessionLog` with `SetEntry`
   rows and no prescription — the data model already allows it.
4. **An exercise library**, so exercises are not defined inline per program.

None of that requires touching the log format. `SetEntry`
(exercise, set, side, load, reps) is deliberately the row a general lifting log
needs.

---

## Working notes for whoever picks this up

- **Look at the screens.** `flutter test test/shots_test.dart` renders every
  one to `build/shots/*.png` at phone size, with a real font loaded — the
  placeholder font in `flutter_test` is about twice the width of real text and
  invents overflows that do not exist. Green tests are not evidence a screen is
  usable.
- **Do not use `pumpAndSettle` on the runner screens.** The tempo metronome and
  the rest clock are periodic timers and a settle waits for them forever.
- There is no Android toolchain assumption: CI builds the APK. A local
  `flutter build apk` works too if the SDK is set up.
- The owner's other apps follow the same shape (bodycomp, upkeep, poppy,
  fuelwise). Reason each app from its own needs rather than copying wholesale,
  but the CI-builds-and-signs / app-updates-itself pipeline is settled here.
