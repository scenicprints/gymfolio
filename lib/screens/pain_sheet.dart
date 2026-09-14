import 'package:flutter/material.dart';

import '../theme.dart';

/// Pain during the session, per arm. The program asks for three numbers and
/// ten seconds, so this is a row of taps and nothing else — no per-set matrix.
Future<Map<String, double>?> showPainSheet(
    BuildContext context, List<String> sides) {
  return showModalBottomSheet<Map<String, double>>(
    context: context,
    backgroundColor: Tone.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PainSheet(sides: sides),
  );
}

class _PainSheet extends StatefulWidget {
  final List<String> sides;
  const _PainSheet({required this.sides});

  @override
  State<_PainSheet> createState() => _PainSheetState();
}

class _PainSheetState extends State<_PainSheet> {
  final Map<String, double> _values = {};

  bool get _complete => _values.length == widget.sides.length;

  Color _colorFor(double v) {
    if (v <= 4) return Tone.good;
    if (v <= 5) return Tone.hold;
    return Tone.bad;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            18, 16, 18, MediaQuery.of(context).viewInsets.bottom + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pain during the session',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Up to 4/10 is acceptable. Above 5, or sharp and stabbing, is too much.',
              style: TextStyle(color: Tone.dim, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            for (final side in widget.sides) ...[
              Row(children: [
                SideChip(side),
                const SizedBox(width: 8),
                Text(side == 'L' ? 'Left' : 'Right',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_values[side] != null)
                  Text('${_values[side]!.toStringAsFixed(0)}/10',
                      style: TextStyle(
                          color: _colorFor(_values[side]!),
                          fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i <= 10; i++) ...[
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            setState(() => _values[side] = i.toDouble()),
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _values[side] == i
                                ? _colorFor(i.toDouble()).withValues(alpha: 0.25)
                                : Tone.surfaceHi,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: _values[side] == i
                                  ? _colorFor(i.toDouble())
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text('$i',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _values[side] == i
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: _values[side] == i
                                    ? _colorFor(i.toDouble())
                                    : Tone.dim,
                              )),
                        ),
                      ),
                    ),
                    if (i < 10) const SizedBox(width: 3),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 4),
            FilledButton(
              onPressed:
                  _complete ? () => Navigator.pop(context, _values) : null,
              child: const Text('Save session'),
            ),
          ],
        ),
      ),
    );
  }
}
