import 'package:flutter/material.dart';

import '../app.dart';
import '../state.dart';
import '../theme.dart';

/// Two arms, three answers. The only extra question appears when you say
/// worse, because that is the one word that has two very different meanings:
/// back off a week, or stop and run the flare protocol.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final Map<String, Verdict> _verdicts = {};
  bool _flare = false;
  final Set<String> _redFlags = {};
  final _note = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _prime(AppModel model) {
    if (_loaded) return;
    _loaded = true;
    final existing = model.state!.checkInOn(ymd(DateTime.now()));
    if (existing != null) {
      _verdicts.addAll(existing.verdicts);
      _flare = existing.flare;
      _redFlags.addAll(existing.redFlags);
      _note.text = existing.note;
    }
  }

  bool get _anyWorse => _verdicts.values.any((v) => v == Verdict.worse);
  bool get _complete => _verdicts.length == _sides.length;
  List<String> _sides = const ['L', 'R'];

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final p = model.program!;
    _sides = p.sides;
    _prime(model);

    return Scaffold(
      appBar: AppBar(title: const Text('Morning check-in')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + Insets.bottomOf(context)),
        children: [
          Panel(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Compared with your baseline',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  model.state!.baselineNote.isEmpty
                      ? 'How the arms were when you started the program.'
                      : model.state!.baselineNote,
                  style: const TextStyle(color: Tone.dim, height: 1.4, fontSize: 13.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          for (final side in _sides) ...[
            _SideBlock(
              side: side,
              value: _verdicts[side],
              onPick: (v) => setState(() => _verdicts[side] = v),
            ),
            const SizedBox(height: 18),
          ],

          if (_anyWorse) ...[
            Panel(
              fill: Tone.bad.withValues(alpha: 0.08),
              border: Tone.bad.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How much worse?',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15.5)),
                  const SizedBox(height: 6),
                  Text(p.flare.definition,
                      style: const TextStyle(
                          color: Tone.dim, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 12),
                  _Choice(
                    label: 'A bit worse',
                    detail: 'Repeat this week at the same load.',
                    selected: !_flare,
                    color: Tone.hold,
                    onTap: () => setState(() => _flare = false),
                  ),
                  const SizedBox(height: 8),
                  _Choice(
                    label: 'Clearly worse, or back in daily activities',
                    detail: 'Run the flare protocol.',
                    selected: _flare,
                    color: Tone.bad,
                    onTap: () => setState(() => _flare = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          _RedFlagSection(
            flags: p.redFlags,
            selected: _redFlags,
            onToggle: (f) => setState(() {
              _redFlags.contains(f) ? _redFlags.remove(f) : _redFlags.add(f);
            }),
          ),

          const SizedBox(height: 18),
          TextField(
            controller: _note,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Note (optional)',
              hintStyle: const TextStyle(color: Tone.faint, fontSize: 14),
              filled: true,
              fillColor: Tone.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 22),
          FilledButton(
            onPressed: _complete
                ? () async {
                    await model.submitCheckIn(CheckIn(
                      date: ymd(DateTime.now()),
                      verdicts: Map.of(_verdicts),
                      flare: _flare && _anyWorse,
                      redFlags: _redFlags.toList(),
                      note: _note.text.trim(),
                    ));
                    if (context.mounted) Navigator.pop(context);
                  }
                : null,
            child: Text(_complete
                ? 'Save check-in'
                : 'Answer for ${_sides.where((s) => !_verdicts.containsKey(s)).join(' and ')}'),
          ),
        ],
      ),
    );
  }
}

class _SideBlock extends StatelessWidget {
  final String side;
  final Verdict? value;
  final ValueChanged<Verdict> onPick;
  const _SideBlock(
      {required this.side, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SideChip(side, size: 26),
          const SizedBox(width: 10),
          Text(side == 'L' ? 'Left arm' : 'Right arm',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Row(
          children: [
            _Big(
                label: 'Better',
                color: Tone.good,
                selected: value == Verdict.better,
                onTap: () => onPick(Verdict.better)),
            const SizedBox(width: 8),
            _Big(
                label: 'Same',
                color: Tone.dim,
                selected: value == Verdict.same,
                onTap: () => onPick(Verdict.same)),
            const SizedBox(width: 8),
            _Big(
                label: 'Worse',
                color: Tone.bad,
                selected: value == Verdict.worse,
                onTap: () => onPick(Verdict.worse)),
          ],
        ),
      ],
    );
  }
}

class _Big extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Big(
      {required this.label,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.20) : Tone.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Tone.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : Tone.text,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final String detail;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Choice(
      {required this.label,
      required this.detail,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : Tone.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Tone.line),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 19, color: selected ? color : Tone.faint),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(detail,
                      style: const TextStyle(color: Tone.dim, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsed by default — it is not a daily question, but it has to be one tap
/// away every single morning.
class _RedFlagSection extends StatefulWidget {
  final List<String> flags;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _RedFlagSection(
      {required this.flags, required this.selected, required this.onToggle});

  @override
  State<_RedFlagSection> createState() => _RedFlagSectionState();
}

class _RedFlagSectionState extends State<_RedFlagSection> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _open = widget.selected.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      border: widget.selected.isEmpty ? null : Tone.bad,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.flag_outlined,
                      size: 18,
                      color: widget.selected.isEmpty ? Tone.dim : Tone.bad),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.selected.isEmpty
                          ? 'Something else has changed'
                          : '${widget.selected.length} red flag(s) reported',
                      style: TextStyle(
                        color: widget.selected.isEmpty ? Tone.dim : Tone.bad,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      color: Tone.faint, size: 20),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Any of these stops the program until it has been looked at.',
                  style: TextStyle(color: Tone.faint, fontSize: 12.5),
                ),
              ),
            ),
            for (final f in widget.flags)
              CheckboxListTile(
                value: widget.selected.contains(f),
                onChanged: (_) => widget.onToggle(f),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                activeColor: Tone.bad,
                title: Text(f,
                    style: const TextStyle(fontSize: 13, height: 1.3)),
              ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
