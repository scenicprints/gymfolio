import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'state.dart';

/// Reminders. A twice-daily protocol that nobody reminds you about is a
/// protocol you do four times a week.
///
/// Every entry point here is wrapped: if notifications are unavailable, denied,
/// or the plugin throws on some OEM build, the app carries on without them.
class Nudges {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _tzReady = false;

  static const _checkInId = 1001;
  static const _trainId = 1002;
  static const _eveningId = 1003;

  static const _channel = AndroidNotificationDetails(
    'gymfolio_reminders',
    'Reminders',
    channelDescription: 'Morning check-in and session reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings);
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('GymFolio: notifications unavailable: $e');
    }
  }

  static void _initTz() {
    if (_tzReady) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(_guessZone()));
      _tzReady = true;
    } catch (e) {
      debugPrint('GymFolio: timezone init failed: $e');
    }
  }

  /// Pick a zone that matches this device's offset both now and half a year
  /// out, so a reminder does not drift an hour at the DST boundary.
  static String _guessZone() {
    final now = DateTime.now();
    final later = DateTime(now.year, now.month + 6, now.day);
    final offNow = now.timeZoneOffset;
    final offLater = later.timeZoneOffset;
    for (final entry in tz.timeZoneDatabase.locations.entries) {
      final loc = entry.value;
      final a = Duration(
          milliseconds: loc.timeZone(now.millisecondsSinceEpoch).offset);
      final b = Duration(
          milliseconds: loc.timeZone(later.millisecondsSinceEpoch).offset);
      if (a == offNow && b == offLater) return entry.key;
    }
    return 'UTC';
  }

  static tz.TZDateTime _nextAt(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var when =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    return when;
  }

  static Future<void> _daily(
      int id, int hour, int minute, String title, String body) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextAt(hour, minute),
      const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Rebuilt from scratch on every state change, so a phase switch or a flare
  /// never leaves a stale reminder behind.
  static Future<void> sync(AppModel model) async {
    if (kIsWeb) return;
    try {
      await init();
      if (!_ready) return;
      _initTz();
      if (!_tzReady) return;

      await _plugin.cancel(_checkInId);
      await _plugin.cancel(_trainId);
      await _plugin.cancel(_eveningId);

      final s = model.state;
      final e = model.engine;
      if (s == null || e == null || !s.onboarded) return;
      final r = s.reminders;
      if (!r.enabled) return;

      await _daily(
        _checkInId,
        r.checkInHour,
        r.checkInMinute,
        'Morning check-in',
        'Better, same, or worse than baseline? Ten seconds, and it decides the week.',
      );

      final twiceDaily = e.activePhase.isDaily || s.mode == kModeFlare;
      if (twiceDaily) {
        await _daily(_trainId, r.trainHour, r.trainMinute, 'Isometrics',
            'Morning round: 5 x 45 seconds, each arm.');
        await _daily(_eveningId, r.eveningHour, r.eveningMinute, 'Isometrics',
            'Evening round: 5 x 45 seconds, each arm.');
      } else {
        await _daily(_trainId, r.trainHour, r.trainMinute, 'Training',
            'Session available today if you are 72 hours clear.');
      }
    } catch (e) {
      debugPrint('GymFolio: reminder sync failed: $e');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
