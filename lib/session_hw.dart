import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The two things a session needs from the phone that are not pixels: a screen
/// that stays on through a three-minute rest, and a tempo cue you can hear over
/// a gym.
///
/// Everything here is guarded. A phone that refuses the wake lock, or an OEM
/// audio stack that throws, must not take the session down with it.

class SessionHw {
  // Constructed lazily inside a guard. Building an AudioPlayer eagerly spins up
  // the plugin's global scope, which throws where there is no platform side —
  // widget tests, most obviously — before any try/catch of ours can catch it.
  static AudioPlayer? _tick;
  static AudioPlayer? _turn;
  static AudioPlayer? _end;
  static bool _ready = false;

  /// Set false to run the session silently; haptics still fire.
  static bool muted = false;

  /// Set false where there is no platform side at all (tests, previews).
  /// Turns the whole subsystem into a no-op rather than a pile of caught
  /// exceptions.
  static bool enabled = true;

  static Future<void> _prepare() async {
    if (_ready || kIsWeb || !enabled) return;
    try {
      _tick ??= AudioPlayer(playerId: 'gf_tick');
      _turn ??= AudioPlayer(playerId: 'gf_turn');
      _end ??= AudioPlayer(playerId: 'gf_end');
      for (final e in [
        (_tick!, 'sound/tick.wav'),
        (_turn!, 'sound/turn.wav'),
        (_end!, 'sound/end.wav'),
      ]) {
        // Low latency mode keeps the cue on the beat; a late metronome is
        // worse than none, because you follow it.
        await e.$1.setReleaseMode(ReleaseMode.stop);
        await e.$1.setPlayerMode(PlayerMode.lowLatency);
        await e.$1.setSource(AssetSource(e.$2));
        await e.$1.setVolume(1.0);
      }
      _ready = true;
    } catch (e) {
      debugPrint('GymFolio: audio unavailable: $e');
    }
  }

  static Future<void> _play(AudioPlayer? Function() pick) async {
    if (muted || kIsWeb || !enabled) return;
    try {
      await _prepare();
      final p = pick();
      if (!_ready || p == null) return;
      await p.stop();
      await p.resume();
    } catch (e) {
      debugPrint('GymFolio: cue failed: $e');
    }
  }

  /// Top of the rep — the loudest, sharpest cue.
  static void rep() {
    HapticFeedback.heavyImpact();
    _play(() => _tick);
  }

  /// Turnaround from up to down. Different pitch on purpose, so you can tell
  /// which half of the rep you are in without looking at the phone.
  static void turn() {
    HapticFeedback.lightImpact();
    _play(() => _turn);
  }

  /// End of a set, or end of a rest.
  static void done() {
    HapticFeedback.heavyImpact();
    _play(() => _end);
  }

  static void soft() => HapticFeedback.mediumImpact();

  /// Warm the audio pipeline before the first rep, or the first cue arrives
  /// late while the platform sets itself up.
  static Future<void> warmUp() => _prepare();

  // ------------------------------------------------------------ wake lock

  static Future<void> keepAwake() async {
    if (kIsWeb || !enabled) return;
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('GymFolio: wakelock enable failed: $e');
    }
  }

  static Future<void> letSleep() async {
    if (kIsWeb || !enabled) return;
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('GymFolio: wakelock disable failed: $e');
    }
  }
}
