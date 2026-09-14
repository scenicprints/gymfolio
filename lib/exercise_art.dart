import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// How to actually do the movement.
///
/// Drawn rather than photographed: no assets to license, nothing to download,
/// it themes itself, and — the reason it is worth the code — it can move at
/// the prescribed tempo. A still picture cannot show you that the lowering
/// takes three seconds, and the lowering is the whole intervention.
///
/// Every figure is drawn in a 200x200 space and scaled to fit, so the same art
/// works as a thumbnail on a card and full-width on the how-to sheet.

const double _box = 200;

double _rad(double deg) => deg * math.pi / 180.0;

Offset _polar(Offset from, double deg, double r) =>
    from + Offset(math.cos(_rad(deg)) * r, math.sin(_rad(deg)) * r);

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Which view of the movement reads clearest, and what the figure is doing.
enum MovementView { sideCurl, inclineCurl, endOnRotation, isoPress, isoHammer }

MovementView viewFor(String id) => switch (id) {
      'incline-curl' => MovementView.inclineCurl,
      'bar-curl' => MovementView.sideCurl,
      'screwdriver' => MovementView.endOnRotation,
      'iso-flexion' => MovementView.isoPress,
      'iso-supination' => MovementView.isoHammer,
      _ => MovementView.sideCurl,
    };

/// The one-line "what am I looking at" under each figure.
String captionFor(String id, double t) => switch (id) {
      'incline-curl' =>
        t < 0.5 ? 'Bottom — biceps on stretch' : 'Top — squeeze, then lower slow',
      'bar-curl' => t < 0.5 ? 'Bottom — full supination' : 'Top — elbows still',
      'screwdriver' => t < 0.5 ? 'Palm down' : 'Palm up',
      'iso-flexion' => 'Push up into something immovable',
      'iso-supination' => 'Rotate toward palm-up and hold',
      _ => '',
    };

class MovementPainter extends CustomPainter {
  /// 0 at the start of the concentric, 1 at the top.
  final double t;
  final MovementView view;
  final Color body;
  final Color accent;
  final Color muted;

  /// Thumbnail mode: drop the scenery, the path arcs and the inset diagrams.
  /// At 46 pixels a chair and a dotted arc are noise, and the pose is the only
  /// thing that has to survive.
  final bool simplified;

  MovementPainter({
    required this.t,
    required this.view,
    this.body = const Color(0xFFB9C6CE),
    this.accent = Tone.accent,
    this.muted = Tone.line,
    this.simplified = false,
  });

  // ------------------------------------------------------------- primitives

  void _limb(Canvas c, Offset a, Offset b, double w, Color col) {
    c.drawLine(
      a,
      b,
      Paint()
        ..color = col
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
  }

  void _dot(Canvas c, Offset o, double r, Color col) =>
      c.drawCircle(o, r, Paint()..color = col);

  /// A dotted arc showing the path the weight travels.
  void _arcPath(Canvas c, Offset centre, double r, double fromDeg, double toDeg) {
    if (simplified) return;
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const step = 9.0;
    final dir = toDeg > fromDeg ? 1 : -1;
    for (var a = fromDeg; dir > 0 ? a < toDeg : a > toDeg; a += step * dir) {
      final p1 = _polar(centre, a, r);
      final p2 = _polar(centre, a + step * 0.5 * dir, r);
      c.drawLine(p1, p2, paint);
    }
  }

  void _arrow(Canvas c, Offset from, Offset to, Color col, {double head = 7}) {
    if (simplified) return;
    final paint = Paint()
      ..color = col
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    c.drawLine(from, to, paint);
    final ang = math.atan2(to.dy - from.dy, to.dx - from.dx);
    for (final s in [2.6, -2.6]) {
      c.drawLine(
        to,
        to + Offset(math.cos(ang + s) * head, math.sin(ang + s) * head),
        paint,
      );
    }
  }

  /// A dumbbell drawn across [angle], centred on the hand.
  void _dumbbell(Canvas c, Offset hand, double angleDeg, {double len = 26}) {
    final a = _polar(hand, angleDeg, len / 2);
    final b = _polar(hand, angleDeg + 180, len / 2);
    _limb(c, a, b, 5, body);
    for (final e in [a, b]) {
      final perp = angleDeg + 90;
      final p1 = _polar(e, perp, 9);
      final p2 = _polar(e, perp + 180, 9);
      _limb(c, p1, p2, 8, accent);
    }
  }

  void _barbell(Canvas c, Offset hand) {
    final a = hand + const Offset(-30, 0);
    final b = hand + const Offset(30, 0);
    _limb(c, a, b, 4, body);
    for (final e in [a, b]) {
      _limb(c, e + const Offset(0, -11), e + const Offset(0, 11), 9, accent);
    }
  }

  void _head(Canvas c, Offset o, double r) {
    c.drawCircle(
      o,
      r,
      Paint()
        ..color = body
        ..style = PaintingStyle.fill,
    );
  }

  // ------------------------------------------------------------------ views

  void _paintSideCurl(Canvas c) {
    // Standing, side on. The bar travels; the elbow does not.
    const hip = Offset(100, 112);
    const neck = Offset(100, 52);
    const shoulder = Offset(100, 58);

    if (!simplified) {
      _limb(c, const Offset(52, 190), const Offset(152, 190), 2,
          muted.withValues(alpha: 0.9));
    }

    // Legs.
    _limb(c, hip, const Offset(94, 152), 11, body.withValues(alpha: 0.55));
    _limb(c, const Offset(94, 152), const Offset(92, 188), 10,
        body.withValues(alpha: 0.55));

    // Torso and head.
    _limb(c, hip, neck, 20, body.withValues(alpha: 0.75));
    _head(c, const Offset(101, 34), 13);

    // Upper arm hangs; only the forearm moves.
    const elbow = Offset(104, 101);
    _limb(c, shoulder, elbow, 10, body);

    const startDeg = 86.0, endDeg = -52.0;
    const forearm = 40.0;
    _arcPath(c, elbow, forearm, startDeg, endDeg);

    final ang = _lerp(startDeg, endDeg, t);
    final hand = _polar(elbow, ang, forearm);
    _limb(c, elbow, hand, 9, body);
    _dot(c, elbow, 5.5, accent);
    _barbell(c, hand);
  }

  void _paintInclineCurl(Canvas c) {
    // The incline is the point: the upper arm sits behind the torso, so the
    // biceps is stretched at the bottom. Bench sits behind and darker, or it
    // merges with the torso and the whole figure reads as one slab.
    const benchTop = Offset(128, 52);
    const benchBottom = Offset(50, 152);

    _limb(c, benchBottom, benchTop, 11, muted);
    if (!simplified) {
      _limb(c, const Offset(38, 158), const Offset(78, 158), 11, muted);
      _limb(c, const Offset(44, 162), const Offset(44, 188), 5,
          muted.withValues(alpha: 0.8));
      _limb(c, const Offset(72, 162), const Offset(72, 188), 5,
          muted.withValues(alpha: 0.8));
    }

    // Torso lying on the backrest, offset clear of it.
    const hip = Offset(74, 150);
    const shoulder = Offset(126, 82);
    _limb(c, hip, shoulder, 18, body.withValues(alpha: 0.8));
    _head(c, const Offset(140, 66), 12);

    // Legs off the front.
    _limb(c, hip, const Offset(48, 174), 11, body.withValues(alpha: 0.55));
    _limb(c, const Offset(48, 174), const Offset(26, 186), 9,
        body.withValues(alpha: 0.45));

    // Upper arm hangs vertically from the shoulder — behind the torso line.
    const elbow = Offset(126, 126);
    _limb(c, shoulder, elbow, 10, body);

    const startDeg = 92.0, endDeg = -58.0;
    const forearm = 38.0;
    _arcPath(c, elbow, forearm, startDeg, endDeg);

    final ang = _lerp(startDeg, endDeg, t);
    final hand = _polar(elbow, ang, forearm);
    _limb(c, elbow, hand, 9, body);
    _dot(c, elbow, 5.5, accent);
    _dumbbell(c, hand, ang + 90);
  }

  /// A fist gripping a handle, drawn in the rotated frame so the hand turns
  /// with the forearm. Without the hand it reads as a knob on a stick.
  void _fistAndHandle(
    Canvas c,
    Offset centre,
    double angDeg, {
    required bool hammer,
  }) {
    c.save();
    c.translate(centre.dx, centre.dy);
    c.rotate(_rad(angDeg));

    // Handle through the fist.
    _limb(c, const Offset(-26, 0), Offset(hammer ? 44 : 50, 0), 6, body);

    // Fist.
    final fist = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 40, height: 34),
      const Radius.circular(11),
    );
    c.drawRRect(fist, Paint()..color = body.withValues(alpha: 0.92));
    // Knuckle creases, so it is unmistakably a hand.
    for (final x in [-9.0, 1.0, 11.0]) {
      c.drawLine(
        Offset(x, -13),
        Offset(x, 4),
        Paint()
          ..color = Tone.bg.withValues(alpha: 0.35)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }

    if (hammer) {
      // Head sits across the end of the handle, offset to one side.
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(46, -5), width: 15, height: 32),
          const Radius.circular(4),
        ),
        Paint()..color = accent,
      );
    } else {
      // Two plates on one end only — that is what makes it a supination lift.
      for (final d in [const Offset(46, 0), const Offset(55, 0)]) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: d, width: 8, height: d.dx == 46 ? 34 : 24),
            const Radius.circular(3),
          ),
          Paint()..color = accent,
        );
      }
    }
    c.restore();
  }

  /// The "elbow stays at ninety, pinned to your ribs" reminder, boxed so it
  /// reads as an inset rather than stray line work.
  void _elbowInset(Canvas c, Offset o) {
    if (simplified) return;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx - 8, o.dy - 12, 52, 50),
      const Radius.circular(8),
    );
    c.drawRRect(box, Paint()..color = muted.withValues(alpha: 0.45));
    c.drawRRect(
      box,
      Paint()
        ..color = muted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _limb(c, o + const Offset(4, -4), o + const Offset(4, 24), 8,
        body.withValues(alpha: 0.5));
    _limb(c, o + const Offset(5, 20), o + const Offset(32, 20), 7,
        body.withValues(alpha: 0.85));
    _dot(c, o + const Offset(5, 20), 4, accent);
  }

  void _paintEndOnRotation(Canvas c) {
    // Looking straight down the forearm. This is the only view that shows
    // supination at all — from the side it is invisible.
    const centre = Offset(104, 96);

    // Forearm cross-section behind the hand.
    if (!simplified) {
      c.drawCircle(centre, 30, Paint()..color = body.withValues(alpha: 0.16));
      c.drawCircle(
        centre,
        30,
        Paint()
          ..color = body.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Rotation sweep, palm-down through to palm-up.
    _arcPath(c, centre, 62, 176, 4);

    final ang = _lerp(180, 0, t);
    _fistAndHandle(c, centre, ang, hammer: false);

    // Direction of travel.
    _arrow(c, _polar(centre, 152, 80), _polar(centre, 122, 80),
        accent.withValues(alpha: 0.85), head: 8);

    _elbowInset(c, const Offset(136, 152));
  }

  void _paintIsoPress(Canvas c) {
    // Nothing moves. The only thing to show is where the force goes, so the
    // arrows carry the animation instead of the limb.
    const shoulder = Offset(88, 74);
    const hip = Offset(86, 128);

    // Seated figure.
    _limb(c, hip, shoulder, 19, body.withValues(alpha: 0.75));
    _head(c, const Offset(90, 54), 12);
    _limb(c, hip, const Offset(128, 132), 11, body.withValues(alpha: 0.5));
    _limb(c, const Offset(128, 132), const Offset(130, 168), 10,
        body.withValues(alpha: 0.5));

    if (!simplified) {
      _limb(c, const Offset(64, 134), const Offset(126, 134), 5, muted);
      _limb(c, const Offset(70, 138), const Offset(70, 172), 4, muted);
    }

    // Upper arm pinned to the side, forearm at ninety degrees.
    const elbow = Offset(90, 112);
    _limb(c, shoulder, elbow, 10, body);
    const hand = Offset(146, 108);
    _limb(c, elbow, hand, 9, body);
    _dot(c, elbow, 5.5, accent);

    // The immovable thing — a desk edge, a rack pin, your other hand.
    final slab = Rect.fromLTWH(112, 74, 68, 14);
    c.drawRRect(
      RRect.fromRectAndRadius(slab, const Radius.circular(3)),
      Paint()..color = muted,
    );
    if (!simplified) {
      for (var x = 116.0; x < 178; x += 9) {
        _limb(c, Offset(x, 88), Offset(x - 6, 96), 2,
            muted.withValues(alpha: 0.85));
      }
    }

    // Force into the slab, pulsing so the still frame still reads as effort.
    final pulse = 0.45 + 0.55 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
    for (final x in [134.0, 152.0]) {
      _arrow(c, Offset(x, 104), Offset(x, 92),
          accent.withValues(alpha: pulse.clamp(0.25, 1.0)));
    }
  }

  void _paintIsoHammer(Canvas c) {
    // End on again, but the load is gravity on the hammer head rather than a
    // weight you rotate through — so the arrow stays vertical while the
    // hammer turns.
    const centre = Offset(104, 92);

    if (!simplified) {
      c.drawCircle(centre, 30, Paint()..color = body.withValues(alpha: 0.16));
      c.drawCircle(
        centre,
        30,
        Paint()
          ..color = body.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Neutral through to palm-up is about a quarter turn, then you hold.
    _arcPath(c, centre, 60, 96, 20);
    final ang = _lerp(95, 22, t);
    _fistAndHandle(c, centre, ang, hammer: true);

    // Gravity acts on the head wherever the head happens to be.
    final head = _polar(centre, ang, 52);
    _arrow(c, head + const Offset(0, 16), head + const Offset(0, 40),
        Tone.dim, head: 6);

    _elbowInset(c, const Offset(20, 158));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _box * (simplified ? 1.22 : 1.0);
    canvas.save();
    canvas.translate(
      (size.width - _box * scale) / 2,
      (size.height - _box * scale) / 2,
    );
    canvas.scale(scale);

    switch (view) {
      case MovementView.sideCurl:
        _paintSideCurl(canvas);
      case MovementView.inclineCurl:
        _paintInclineCurl(canvas);
      case MovementView.endOnRotation:
        _paintEndOnRotation(canvas);
      case MovementView.isoPress:
        _paintIsoPress(canvas);
      case MovementView.isoHammer:
        _paintIsoHammer(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MovementPainter old) => old.t != t || old.view != view;
}

/// The animated figure. Runs at the movement's real tempo — three seconds up,
/// three seconds down — so watching it once tells you how slow slow is.
class MovementDemo extends StatefulWidget {
  final String movementId;
  final int upSeconds;
  final int downSeconds;
  final bool playing;
  final double height;

  const MovementDemo({
    super.key,
    required this.movementId,
    this.upSeconds = 3,
    this.downSeconds = 3,
    this.playing = true,
    this.height = 190,
  });

  @override
  State<MovementDemo> createState() => _MovementDemoState();
}

class _MovementDemoState extends State<MovementDemo>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  int get _cycleMs => (widget.upSeconds + widget.downSeconds) * 1000;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _cycleMs == 0 ? 4000 : _cycleMs),
    );
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant MovementDemo old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Split the cycle so the up phase takes upSeconds and the down phase takes
  /// downSeconds, rather than a symmetric sine that would flatter the tempo.
  double _phase(double v) {
    final total = widget.upSeconds + widget.downSeconds;
    // Isometrics have no concentric and no eccentric — they are passed a zero
    // tempo, so there is no ratio to split on. Pulse symmetrically instead.
    if (total <= 0) {
      return v <= 0.5
          ? Curves.easeInOut.transform(v * 2)
          : 1 - Curves.easeInOut.transform((v - 0.5) * 2);
    }
    final up = widget.upSeconds / total;
    if (up <= 0) return 1 - Curves.easeInOut.transform(v);
    if (up >= 1) return Curves.easeInOut.transform(v);
    if (v <= up) return Curves.easeInOut.transform(v / up);
    return 1 - Curves.easeInOut.transform((v - up) / (1 - up));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _phase(_c.value);
        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: MovementPainter(
                    t: t,
                    view: viewFor(widget.movementId),
                  ),
                  size: Size.infinite,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                captionFor(widget.movementId, t),
                style: const TextStyle(color: Tone.dim, fontSize: 12.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small static thumbnail for a list row — the top of the movement, which is
/// the pose that identifies it.
class MovementThumb extends StatelessWidget {
  final String movementId;
  final double size;
  const MovementThumb({super.key, required this.movementId, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: MovementPainter(
          t: 0.85,
          view: viewFor(movementId),
          body: Tone.dim,
          accent: Tone.accent.withValues(alpha: 0.95),
          muted: Tone.line,
          simplified: true,
        ),
      ),
    );
  }
}
