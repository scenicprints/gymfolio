import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../state.dart';
import '../theme.dart';
import '../update_checker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = '${i.version} (${i.buildNumber})');
    }).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final s = model.state!;
    final r = s.reminders;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const SectionLabel('Reminders'),
        Panel(
          child: Column(
            children: [
              SwitchListTile(
                value: r.enabled,
                onChanged: (v) {
                  r.enabled = v;
                  model.saveReminders(r);
                },
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Tone.good,
                title: const Text('Daily reminders'),
                subtitle: const Text(
                  'A twice-daily protocol nobody reminds you about is a protocol you do four times a week.',
                  style: TextStyle(color: Tone.faint, fontSize: 12, height: 1.35),
                ),
              ),
              if (r.enabled) ...[
                const Divider(height: 20),
                _TimeRow(
                  label: 'Morning check-in',
                  hour: r.checkInHour,
                  minute: r.checkInMinute,
                  onPick: (h, m) {
                    r.checkInHour = h;
                    r.checkInMinute = m;
                    model.saveReminders(r);
                  },
                ),
                _TimeRow(
                  label: 'First session',
                  hour: r.trainHour,
                  minute: r.trainMinute,
                  onPick: (h, m) {
                    r.trainHour = h;
                    r.trainMinute = m;
                    model.saveReminders(r);
                  },
                ),
                _TimeRow(
                  label: 'Evening session',
                  hour: r.eveningHour,
                  minute: r.eveningMinute,
                  onPick: (h, m) {
                    r.eveningHour = h;
                    r.eveningMinute = m;
                    model.saveReminders(r);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'The evening reminder only fires while the program is on isometrics — Phase 1 or a flare.',
                    style: TextStyle(color: Tone.faint, fontSize: 11.5, height: 1.35),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        const SectionLabel('Your log'),
        Panel(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.ios_share, color: Tone.dim),
                title: const Text('Export the log'),
                subtitle: const Text(
                  'The whole record as JSON — for a backup, or to hand to a physio.',
                  style: TextStyle(color: Tone.faint, fontSize: 12),
                ),
                onTap: () async {
                  final text = s.export();
                  await Share.share(
                    text,
                    subject: 'GymFolio log ${ymd(DateTime.now())}',
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt, color: Tone.bad),
                title: const Text('Start over',
                    style: TextStyle(color: Tone.bad)),
                subtitle: const Text(
                  'Erases every check-in and session on this phone.',
                  style: TextStyle(color: Tone.faint, fontSize: 12),
                ),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: Tone.surface,
                      title: const Text('Erase the log?'),
                      content: Text(
                        'This deletes ${s.checkIns.length} check-ins and '
                        '${s.sessions.length} sessions. There is no undo — '
                        'export first if you might want it.',
                        style: const TextStyle(color: Tone.dim, height: 1.4),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel')),
                        FilledButton(
                          style:
                              FilledButton.styleFrom(backgroundColor: Tone.bad),
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Erase'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await model.resetEverything();
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const SectionLabel('App'),
        Panel(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.system_update, color: Tone.dim),
                title: const Text('Check for updates'),
                subtitle: Text(
                  _version.isEmpty ? 'GymFolio' : 'GymFolio $_version',
                  style: const TextStyle(color: Tone.faint, fontSize: 12),
                ),
                onTap: () => manualCheck(context),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined, color: Tone.dim),
                title: Text(model.program!.name),
                subtitle: Text(
                  'Program document · ${model.program!.id}',
                  style: const TextStyle(color: Tone.faint, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Baseline',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                s.baselineNote.isEmpty
                    ? 'Not recorded.'
                    : s.baselineNote,
                style: const TextStyle(color: Tone.dim, height: 1.4, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final int hour;
  final int minute;
  final void Function(int, int) onPick;
  const _TimeRow({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeOfDay(hour: hour, minute: minute);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        t.format(context),
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: Tone.accent),
      ),
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: t);
        if (picked != null) onPick(picked.hour, picked.minute);
      },
    );
  }
}
