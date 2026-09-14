import 'package:flutter/material.dart';

import '../app.dart';
import '../state.dart';
import '../theme.dart';

/// Correcting the record. A mistyped pain score is not cosmetic — pain during
/// the holds is one of the three Phase 1 gate criteria — and a wrong load
/// poisons the progress chart for the rest of the block.
Future<void> showEditSession(BuildContext context, SessionLog session) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, controller) =>
          _EditBody(controller: controller, session: session),
    ),
  );
}

class _EditBody extends StatefulWidget {
  final ScrollController controller;
  final SessionLog session;
  const _EditBody({required this.controller, required this.session});

  @override
  State<_EditBody> createState() => _EditBodyState();
}

class _EditBodyState extends State<_EditBody> {
  late Map<String, double> _pain;
  late List<SetEntry> _sets;
  late TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _pain = Map.of(widget.session.painDuring);
    _sets = List.of(widget.session.sets);
    _note = TextEditingController(text: widget.session.note);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Color _painColor(double v) {
    if (v <= 4) return Tone.good;
    if (v <= 5) return Tone.hold;
    return Tone.bad;
  }

  String _fmt(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final s = widget.session;

    final byEx = <String, List<int>>{};
    for (var i = 0; i < _sets.length; i++) {
      (byEx[_sets[i].exerciseId] ??= []).add(i);
    }

    String titleOf(String exId) {
      for (final ph in model.program!.phases) {
        for (final e in ph.exercises) {
          if (e.id == exId) return e.title;
        }
      }
      return exId;
    }

    return ListView(
      controller: widget.controller,
      padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + Insets.bottomOf(context)),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.label.isEmpty ? 'Session' : s.label,
                      style: display(28)),
                  Text(s.date,
                      style: const TextStyle(color: Tone.dim, fontSize: 14)),
                ],
              ),
            ),
            Pill(s.kind == 'iso' ? 'iso' : 'hsr', color: Tone.dim),
          ],
        ),
        const SizedBox(height: 20),

        const SectionLabel('Pain during'),
        for (final side in model.program!.sides) ...[
          Row(children: [
            SideChip(side),
            const SizedBox(width: 8),
            Text(side == 'L' ? 'Left' : 'Right',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${(_pain[side] ?? 0).toStringAsFixed(0)}/10',
                style: display(20, color: _painColor(_pain[side] ?? 0))),
          ]),
          const SizedBox(height: 7),
          Row(
            children: [
              for (var i = 0; i <= 10; i++) ...[
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _pain[side] = i.toDouble()),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _pain[side] == i
                            ? _painColor(i.toDouble()).withValues(alpha: 0.25)
                            : Tone.surfaceHi,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: _pain[side] == i
                              ? _painColor(i.toDouble())
                              : Colors.transparent,
                        ),
                      ),
                      child: Text('$i',
                          style: display(15,
                              color: _pain[side] == i
                                  ? _painColor(i.toDouble())
                                  : Tone.dim)),
                    ),
                  ),
                ),
                if (i < 10) const SizedBox(width: 3),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],

        if (_sets.isNotEmpty) ...[
          const SectionLabel('Sets'),
          for (final entry in byEx.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 2),
              child: Text(titleOf(entry.key),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14.5)),
            ),
            for (final i in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    SizedBox(
                        width: 26,
                        child: Text('${_sets[i].setIndex}',
                            style: display(16, color: Tone.faint))),
                    if (_sets[i].side != 'BOTH')
                      SideChip(_sets[i].side, size: 19)
                    else
                      SizedBox(
                          width: 19,
                          child: Text('BAR', style: stencil(9))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stepper(
                        label: 'lb',
                        value: _fmt(_sets[i].load),
                        onDown: () => setState(() => _sets[i] = _sets[i]
                            .copyWith(
                                load: (_sets[i].load - 2.5).clamp(0, 999))),
                        onUp: () => setState(() =>
                            _sets[i] = _sets[i].copyWith(load: _sets[i].load + 2.5)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stepper(
                        label: 'reps',
                        value: '${_sets[i].reps}',
                        onDown: () => setState(() => _sets[i] = _sets[i]
                            .copyWith(reps: (_sets[i].reps - 1).clamp(0, 99))),
                        onUp: () => setState(() =>
                            _sets[i] = _sets[i].copyWith(reps: _sets[i].reps + 1)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],

        const SizedBox(height: 6),
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Note (optional)'),
        ),

        const SizedBox(height: 10),
        Text(
          'Editing corrects the record. It does not rewind a week you have '
          'already been given — only the week in progress is re-evaluated.',
          style: const TextStyle(color: Tone.faint, fontSize: 12, height: 1.45),
        ),

        const SizedBox(height: 18),
        FilledButton(
          onPressed: () async {
            await model.editSession(SessionLog(
              id: s.id,
              date: s.date,
              at: s.at,
              phaseId: s.phaseId,
              phaseWeek: s.phaseWeek,
              kind: s.kind,
              blockId: s.blockId,
              label: s.label,
              painDuring: _pain,
              sets: _sets,
              note: _note.text.trim(),
            ));
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save changes'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Tone.bad,
            side: BorderSide(color: Tone.bad.withValues(alpha: 0.5)),
          ),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Delete this session?'),
                content: const Text(
                  'It comes out of the log, the loads chart and the week count. '
                  'There is no undo.',
                  style: TextStyle(color: Tone.dim, height: 1.45),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Tone.bad,
                        foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await model.removeSession(s.id);
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Delete session'),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onDown;
  final VoidCallback onUp;
  const _Stepper({
    required this.label,
    required this.value,
    required this.onDown,
    required this.onUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Tone.surfaceHi,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Tone.lineSoft),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onDown,
            icon: const Icon(Icons.remove, size: 17),
            color: Tone.dim,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: display(17)),
                Text(label.toUpperCase(), style: stencil(8.5)),
              ],
            ),
          ),
          IconButton(
            onPressed: onUp,
            icon: const Icon(Icons.add, size: 17),
            color: Tone.dim,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
        ],
      ),
    );
  }
}
