import 'package:flutter/material.dart';

/// Two interactions a day, in two very different states: half awake at 6am,
/// and mid-set with sweaty hands. Both want large targets and no decoration.

class Tone {
  static const bg = Color(0xFF0E1113);
  static const surface = Color(0xFF171B1F);
  static const surfaceHi = Color(0xFF1F252A);
  static const line = Color(0xFF2A3238);
  static const text = Color(0xFFECF1F4);
  static const dim = Color(0xFF8C9AA4);
  static const faint = Color(0xFF5C6870);

  static const good = Color(0xFF4ADE80);
  static const hold = Color(0xFFFBBF24);
  static const bad = Color(0xFFF87171);
  static const accent = Color(0xFF60A5FA);

  /// Left and right are told apart by colour everywhere in the app, because
  /// the whole story of this program is one arm trailing the other.
  static const left = Color(0xFF60A5FA);
  static const right = Color(0xFFF0A868);

  static Color side(String s) => s == 'R' ? right : left;
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Tone.bg,
    colorScheme: base.colorScheme.copyWith(
      surface: Tone.surface,
      primary: Tone.accent,
      secondary: Tone.good,
      error: Tone.bad,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Tone.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Tone.text,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Tone.text,
      displayColor: Tone.text,
    ),
    dividerColor: Tone.line,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: Tone.text,
        side: const BorderSide(color: Tone.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Tone.surface,
      indicatorColor: Tone.accent.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Tone.text : Tone.faint,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Tone.surfaceHi,
      contentTextStyle: TextStyle(color: Tone.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// A plain panel. Every surface in the app is one of these — no elevation
/// games, no gradients.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? border;
  final Color? fill;
  final VoidCallback? onTap;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.border,
    this.fill,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: fill ?? Tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border ?? Tone.line),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: body,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Tone.faint,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      );
}

/// The L / R chip used everywhere a per-arm number appears.
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
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        side,
        style: TextStyle(
          color: c,
          fontSize: size * 0.55,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
