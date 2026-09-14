import 'package:flutter/material.dart';

/// The look: an instrument panel, not a feed.
///
/// Two interactions a day, in two very different states — half awake at 6am,
/// and mid-set with sweaty hands — so everything is big, high contrast and
/// unambiguous. Numbers are the content, so numbers get the display face,
/// tabular figures and the most weight on screen.
///
/// One colour rule, and it is load-bearing: **blue is the left arm and coral is
/// the right arm, everywhere, always.** Nothing else may use them. That is why
/// the primary action is near-white rather than blue — a blue button would
/// quietly mean "left" on a screen where left and right are the whole story.

class Tone {
  // Surfaces, darkest to lightest.
  static const bg = Color(0xFF0B0D0F);
  static const surface = Color(0xFF14171A);
  static const surfaceHi = Color(0xFF1C2126);
  static const line = Color(0xFF262C32);
  static const lineSoft = Color(0xFF1B2126);

  // Text.
  static const text = Color(0xFFE8EDF0);
  static const dim = Color(0xFF93A1AB);
  static const faint = Color(0xFF5F6B74);

  // Semantics.
  static const good = Color(0xFF3FD684);
  static const hold = Color(0xFFF5C451);
  static const bad = Color(0xFFFF6B6B);

  /// Informational highlight — cues, links, the tempo badge.
  static const accent = Color(0xFF58A6FF);

  /// The primary action. Near-white on near-black: unmistakable, and it leaves
  /// blue free to mean "left arm".
  static const action = Color(0xFFE8EDF0);
  static const onAction = Color(0xFF0B0D0F);

  static const left = Color(0xFF58A6FF);
  static const right = Color(0xFFF2864B);

  static Color side(String s) => s == 'R' ? right : left;
}

const kDisplay = 'BarlowCondensed';
const kText = 'Barlow';

/// Big numeric readouts — timers, loads, rep counts, the week number.
TextStyle display(double size,
        {Color color = Tone.text, FontWeight weight = FontWeight.w700}) =>
    TextStyle(
      fontFamily: kDisplay,
      fontSize: size,
      height: 1.0,
      color: color,
      fontWeight: weight,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Small caps label — the engraving on the panel.
TextStyle stencil(double size, {Color color = Tone.faint}) => TextStyle(
      fontFamily: kDisplay,
      fontSize: size,
      color: color,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
    );

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final t = base.textTheme
      .apply(bodyColor: Tone.text, displayColor: Tone.text)
      .copyWith(
        bodyLarge: const TextStyle(fontSize: 15.5, height: 1.45),
        bodyMedium: const TextStyle(fontSize: 14.5, height: 1.45),
        bodySmall: const TextStyle(fontSize: 13, height: 1.4, color: Tone.dim),
        titleLarge: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      )
      .apply(fontFamily: kText);

  return base.copyWith(
    scaffoldBackgroundColor: Tone.bg,
    colorScheme: base.colorScheme.copyWith(
      surface: Tone.surface,
      primary: Tone.action,
      onPrimary: Tone.onAction,
      secondary: Tone.accent,
      error: Tone.bad,
    ),
    textTheme: t,
    appBarTheme: AppBarTheme(
      backgroundColor: Tone.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Tone.dim),
      titleTextStyle: const TextStyle(
        fontFamily: kText,
        color: Tone.text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
    ),
    dividerColor: Tone.line,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Tone.action,
        foregroundColor: Tone.onAction,
        disabledBackgroundColor: Tone.surfaceHi,
        disabledForegroundColor: Tone.faint,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(
          fontFamily: kText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: Tone.text,
        side: const BorderSide(color: Tone.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(
          fontFamily: kText,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Tone.dim),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Tone.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Tone.text.withValues(alpha: 0.10),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: kDisplay,
          fontSize: 12,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? Tone.text : Tone.faint,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected) ? Tone.text : Tone.faint,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Tone.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: const TextStyle(
          fontFamily: kText,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: Tone.text),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Tone.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Tone.line,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Tone.surfaceHi,
      contentTextStyle: TextStyle(color: Tone.text, fontFamily: kText),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Tone.surfaceHi,
      hintStyle: const TextStyle(color: Tone.faint, fontFamily: kText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Tone.lineSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Tone.dim),
      ),
    ),
  );
}

/// A panel. Optionally with a coloured rail down its left edge, which is how
/// this app marks a card that means something — a flare, a stop, a thing due.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? border;
  final Color? fill;
  final Color? rail;
  final VoidCallback? onTap;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.border,
    this.fill,
    this.rail,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    // A Material, not a decorated Container. Anything inkable inside a panel —
    // a ListTile, a SwitchListTile, the panel's own tap — paints its ripple on
    // the nearest Material ancestor, and a plain coloured box hides it. Get
    // this wrong and rows simply stop responding to the touch, visibly.
    Widget body = Material(
      color: fill ?? Tone.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: border ?? Tone.lineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (onTap == null)
            Padding(
              padding: padding,
              child: SizedBox(width: double.infinity, child: child),
            )
          else
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: padding,
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
          if (rail != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(child: Container(width: 3, color: rail)),
            ),
        ],
      ),
    );

    return body;
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 9, top: 4),
        child: Row(
          children: [
            Text(text.toUpperCase(), style: stencil(12)),
            const SizedBox(width: 10),
            const Expanded(child: Divider(height: 1, color: Tone.lineSoft)),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      );
}

/// The L / R chip. Present wherever a per-arm number is, so the eye can find
/// its own side without reading.
class SideChip extends StatelessWidget {
  final String side;
  final double size;
  const SideChip(this.side, {super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final c = Tone.side(side);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.55)),
      ),
      child: Text(
        side,
        style: TextStyle(
          fontFamily: kDisplay,
          color: c,
          fontSize: size * 0.62,
          height: 1.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The instrument-cluster primitive: a caption, a big number, and a unit.
class Readout extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final double size;
  final CrossAxisAlignment align;

  const Readout({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.color = Tone.text,
    this.size = 30,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: stencil(10.5)),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: display(size, color: color)),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(unit!,
                  style: TextStyle(
                    fontFamily: kText,
                    fontSize: size * 0.36,
                    color: Tone.faint,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ],
        ),
      ],
    );
  }
}

/// A status pill — ON PROGRAM / FLARE / STOPPED, and the smaller inline ones.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool solid;
  const Pill(this.text, {super.key, required this.color, this.solid = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: solid ? 1 : 0.45)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: kDisplay,
          color: solid ? Tone.onAction : color,
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}
