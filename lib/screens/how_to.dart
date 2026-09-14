import 'package:flutter/material.dart';

import '../exercise_art.dart';
import '../theme.dart';

/// "How do I actually do this?" — one sheet, reachable from anywhere the
/// movement is named. The figure runs at the real tempo, so the answer to
/// "how slow is slow" is on screen rather than in a sentence.
Future<void> showHowTo(
  BuildContext context, {
  required String movementId,
  required String title,
  required List<String> steps,
  String? note,
  String? cue,
  int upSeconds = 3,
  int downSeconds = 3,
  String? scheme,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Tone.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, controller) => _HowToBody(
        controller: controller,
        movementId: movementId,
        title: title,
        steps: steps,
        note: note,
        cue: cue,
        upSeconds: upSeconds,
        downSeconds: downSeconds,
        scheme: scheme,
      ),
    ),
  );
}

class _HowToBody extends StatelessWidget {
  final ScrollController controller;
  final String movementId;
  final String title;
  final List<String> steps;
  final String? note;
  final String? cue;
  final int upSeconds;
  final int downSeconds;
  final String? scheme;

  const _HowToBody({
    required this.controller,
    required this.movementId,
    required this.title,
    required this.steps,
    this.note,
    this.cue,
    required this.upSeconds,
    required this.downSeconds,
    this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final isTempo = upSeconds > 0 && downSeconds > 0;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        if (scheme != null) ...[
          const SizedBox(height: 3),
          Text(scheme!, style: const TextStyle(color: Tone.dim, fontSize: 14)),
        ],
        const SizedBox(height: 14),

        Container(
          decoration: BoxDecoration(
            color: Tone.bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Tone.line),
          ),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            children: [
              MovementDemo(
                movementId: movementId,
                upSeconds: upSeconds,
                downSeconds: downSeconds,
                height: 210,
              ),
              if (isTempo) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Tone.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Real time · ${upSeconds}s up, ${downSeconds}s down',
                    style: const TextStyle(
                        color: Tone.accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),

        if (cue != null && cue!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Panel(
            fill: Tone.accent.withValues(alpha: 0.10),
            border: Tone.accent.withValues(alpha: 0.4),
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                const Icon(Icons.push_pin_outlined, size: 17, color: Tone.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('This week: $cue',
                      style: const TextStyle(fontSize: 13.5, height: 1.35)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),
        const SectionLabel('How to do it'),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: Tone.surfaceHi,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Tone.line),
                  ),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Tone.dim)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(steps[i],
                      style: const TextStyle(fontSize: 14.5, height: 1.45)),
                ),
              ],
            ),
          ),

        if (note != null && note!.isNotEmpty) ...[
          const SizedBox(height: 6),
          const SectionLabel('Why this one'),
          Panel(
            padding: const EdgeInsets.all(14),
            child: Text(note!,
                style: const TextStyle(
                    color: Tone.dim, fontSize: 13, height: 1.45)),
          ),
        ],
      ],
    );
  }
}

/// The affordance itself. Quiet — an outline circle with a question mark, the
/// same one everywhere a movement is named, so it is learned once.
class HowToButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const HowToButton({super.key, required this.onTap, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Tone.line),
          color: Tone.surfaceHi,
        ),
        child: Icon(Icons.help_outline, size: size * 0.55, color: Tone.dim),
      ),
    );
  }
}
