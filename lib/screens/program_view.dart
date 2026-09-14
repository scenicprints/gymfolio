import 'package:flutter/material.dart';

import '../app.dart';
import '../theme.dart';

/// The written program, rendered from the same JSON the engine runs on. If the
/// document and the app ever disagree, there is only one file to fix.
class ProgramScreen extends StatelessWidget {
  const ProgramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final p = model.program!;
    final e = model.engine!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(p.name,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        Text(p.subtitle, style: const TextStyle(color: Tone.dim)),
        const SizedBox(height: 20),

        const SectionLabel('The governing rule'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.governing.headline,
                  style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
              const SizedBox(height: 14),
              for (final row in p.governing.rows) ...[
                Text(row[0],
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Tone.faint)),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 15, color: Tone.good),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(row[1],
                            style: const TextStyle(fontSize: 13, height: 1.35))),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.close, size: 15, color: Tone.bad),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(row[2],
                            style: const TextStyle(
                                fontSize: 13, height: 1.35, color: Tone.dim))),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const Divider(height: 1),
              const SizedBox(height: 10),
              for (final n in p.governing.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(n,
                      style: const TextStyle(
                          color: Tone.dim, fontSize: 12.5, height: 1.45)),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const SectionLabel('Phases'),
        for (final ph in p.phases)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              border: ph.id == e.phase.id ? Tone.accent.withValues(alpha: 0.6) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(ph.title,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (ph.id == e.phase.id)
                        const Text('YOU ARE HERE',
                            style: TextStyle(
                                color: Tone.accent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(ph.purpose,
                      style: const TextStyle(
                          color: Tone.dim, fontSize: 13, height: 1.4)),
                  if (ph.isDaily) ...[
                    const SizedBox(height: 10),
                    for (final b in ph.blocks) ...[
                      Text('${b.title} — ${b.sets} x ${b.holdSeconds}s, '
                          '${b.timesPerDay}x daily',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      for (final c in b.cues)
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 3),
                          child: Text('· $c',
                              style: const TextStyle(
                                  color: Tone.dim, fontSize: 12, height: 1.35)),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ] else ...[
                    const SizedBox(height: 10),
                    Text(
                      '${ph.sessionsPerWeek}x per week · '
                      '${ph.minHoursBetweenSessions}h apart · tempo ${ph.tempo}',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    for (final ex in ph.exercises)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('· ', style: TextStyle(color: Tone.faint)),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 12.5, height: 1.35, color: Tone.text),
                                  children: [
                                    TextSpan(
                                        text: ex.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    TextSpan(
                                      text: ex.unilateral
                                          ? '  (per arm)'
                                          : '  (one load)',
                                      style: const TextStyle(color: Tone.faint),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (ph.loadBlocks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final b in ph.loadBlocks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(children: [
                            SizedBox(
                                width: 62,
                                child: Text('Wk ${b.docWeeks}',
                                    style: const TextStyle(
                                        color: Tone.faint, fontSize: 12))),
                            Text('${b.scheme} @ ${b.target}',
                                style: const TextStyle(fontSize: 12.5)),
                            const Spacer(),
                            Text('${(b.restSeconds / 60).toStringAsFixed(b.restSeconds % 60 == 0 ? 0 : 1)} min rest',
                                style: const TextStyle(
                                    color: Tone.faint, fontSize: 11.5)),
                          ]),
                        ),
                    ],
                    if (ph.reintroduction.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final r in ph.reintroduction)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text('· $r',
                              style: const TextStyle(
                                  color: Tone.dim, fontSize: 12, height: 1.35)),
                        ),
                    ],
                    if (ph.maintenanceNote.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(ph.maintenanceNote,
                          style: const TextStyle(
                              color: Tone.hold, fontSize: 12, height: 1.4)),
                    ],
                  ],
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),
        const SectionLabel('The rest of your training'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in p.restrictions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.part,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Text(r.status,
                          style: const TextStyle(
                              color: Tone.dim, fontSize: 12.5, height: 1.4)),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const SectionLabel('Flare protocol'),
        Panel(
          border: Tone.hold.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.flare.definition,
                  style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
              const SizedBox(height: 12),
              for (var i = 0; i < p.flare.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}. ',
                          style: const TextStyle(
                              color: Tone.hold, fontWeight: FontWeight.w700)),
                      Expanded(
                          child: Text(p.flare.steps[i],
                              style: const TextStyle(fontSize: 13, height: 1.4))),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text(p.flare.note,
                  style: const TextStyle(
                      color: Tone.dim, fontSize: 12.5, height: 1.45)),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const SectionLabel('What not to do'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in p.whatNotToDo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Text(n.text,
                          style: const TextStyle(
                              color: Tone.dim, fontSize: 12.5, height: 1.4)),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const SectionLabel('Red flags — stop and get seen'),
        Panel(
          border: Tone.bad.withValues(alpha: 0.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in p.redFlags)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 15, color: Tone.bad),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(f,
                              style: const TextStyle(fontSize: 13, height: 1.4))),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const SectionLabel('Timeline'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in p.timeline)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: Text(row[0],
                              style: const TextStyle(fontSize: 13, height: 1.35))),
                      const SizedBox(width: 12),
                      Text(row[1],
                          style: const TextStyle(
                              color: Tone.dim,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(p.timelineNote,
                  style: const TextStyle(
                      color: Tone.faint, fontSize: 12, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}
