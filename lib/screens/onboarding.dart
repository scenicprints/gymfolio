import 'package:flutter/material.dart';

import '../app.dart';
import '../theme.dart';

/// First run. Two things have to happen before the program can start: you
/// describe the baseline everything will be compared against, and you say
/// whether the exam the document asks for has happened.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _baseline = TextEditingController();
  bool _exam = false;
  bool _saving = false;

  @override
  void dispose() {
    _baseline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final p = model.program!;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Text(
              'GymFolio',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8),
            ),
            const SizedBox(height: 6),
            Text(
              '${p.name} · ${p.subtitle}',
              style: const TextStyle(color: Tone.dim, fontSize: 15),
            ),
            const SizedBox(height: 24),

            Panel(
              border: Tone.hold.withValues(alpha: 0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    Icon(Icons.info_outline, color: Tone.hold, size: 18),
                    SizedBox(width: 8),
                    Text('Before starting',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: Tone.hold)),
                  ]),
                  const SizedBox(height: 10),
                  Text(p.beforeStarting,
                      style: const TextStyle(color: Tone.dim, height: 1.45)),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: _exam,
                    onChanged: (v) => setState(() => _exam = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    activeColor: Tone.good,
                    title: const Text(
                      'I have had this looked at in person.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  if (!_exam)
                    const Padding(
                      padding: EdgeInsets.only(left: 4, top: 2),
                      child: Text(
                        'You can start either way — the app records the answer '
                        'so the log you hand over says so.',
                        style: TextStyle(color: Tone.faint, fontSize: 12.5),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SectionLabel('Your baseline'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Every morning from now on you answer one question: better, '
                    'same, or worse than this. Write down what "this" is today, '
                    'in your own words.',
                    style: TextStyle(color: Tone.dim, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _baseline,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Right elbow aches picking up a full kettle, '
                          'left only after pressing. Both stiff first thing.',
                      hintStyle:
                          const TextStyle(color: Tone.faint, fontSize: 14),
                      filled: true,
                      fillColor: Tone.surfaceHi,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SectionLabel('What happens next'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final ph in p.phases) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6, right: 10),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: Tone.accent, shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ph.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(ph.purpose,
                                  style: const TextStyle(
                                      color: Tone.dim,
                                      fontSize: 13,
                                      height: 1.35)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await model.startProgram(
                        baselineNote: _baseline.text.trim(),
                        examAcknowledged: _exam,
                      );
                    },
              child: Text(_saving ? 'Starting…' : 'Start Week 1'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Loads, weeks and flares are all decided from what you log. '
              'Nothing here is a substitute for the person who examined you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Tone.faint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
