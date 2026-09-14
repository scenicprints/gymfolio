import 'package:flutter/material.dart';

import '../app.dart';
import '../theme.dart';

/// Picking the working loads. This happens once at the start of Phase 2 and
/// again every time the rep scheme changes, because a 5% nudge off a 15-rep
/// max is meaningless when the target becomes a 12-rep max.
class CalibrateScreen extends StatefulWidget {
  const CalibrateScreen({super.key});

  @override
  State<CalibrateScreen> createState() => _CalibrateScreenState();
}

class _CalibrateScreenState extends State<CalibrateScreen> {
  final Map<String, TextEditingController> _ctl = {};
  bool _primed = false;

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _key(String ex, String side) => '$ex|$side';

  void _prime(AppModel model) {
    if (_primed) return;
    _primed = true;
    for (final p in model.engine!.prescription()) {
      for (final side in p.sides) {
        final v = p.loads[side] ?? 0;
        _ctl[_key(p.exercise.id, side)] = TextEditingController(
          text: v > 0 ? v.toStringAsFixed(v % 1 == 0 ? 0 : 1) : '',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final e = model.engine!;
    final block = e.loadBlock;
    _prime(model);

    return Scaffold(
      appBar: const _Bar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weeks ${block?.docWeeks ?? ''} · ${block?.scheme ?? ''} at your ${block?.target ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(e.phase.repMaxNote,
                    style: const TextStyle(
                        color: Tone.dim, fontSize: 13, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final p in e.prescription()) ...[
            Text(p.exercise.title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(p.exercise.note,
                style: const TextStyle(
                    color: Tone.dim, fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final side in p.sides) ...[
                  Expanded(
                    child: TextField(
                      controller: _ctl[_key(p.exercise.id, side)],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        prefixIcon: side == 'BOTH'
                            ? null
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                                child: SideChip(side, size: 22),
                              ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                        labelText: side == 'BOTH' ? 'Both arms' : null,
                        labelStyle: const TextStyle(color: Tone.faint),
                        suffixText: p.exercise.unit,
                        suffixStyle: const TextStyle(color: Tone.faint),
                        filled: true,
                        fillColor: Tone.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (side != p.sides.last) const SizedBox(width: 12),
                ],
              ],
            ),
            const SizedBox(height: 20),
          ],
          FilledButton(
            onPressed: () async {
              final out = <String, Map<String, double>>{};
              for (final p in e.prescription()) {
                for (final side in p.sides) {
                  final raw = _ctl[_key(p.exercise.id, side)]?.text.trim() ?? '';
                  final v = double.tryParse(raw);
                  if (v != null && v > 0) {
                    (out[p.exercise.id] ??= {})[side] = v;
                  }
                }
              }
              await model.calibrate(out);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save loads'),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  const _Bar();
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(title: const Text('Working loads'));
}
