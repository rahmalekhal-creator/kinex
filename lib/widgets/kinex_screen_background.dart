import 'package:flutter/material.dart';

class KinexScreenBackground extends StatelessWidget {
  final Widget child;

  const KinexScreenBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF0B1220) : const Color(0xFFF3F6FB);
    final top = isDark ? const Color(0xFF0E1A33) : const Color(0xFFEAF3FF);
    final bottom = isDark ? const Color(0xFF111827) : const Color(0xFFF8FBFF);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [top, base, bottom],
              ),
            ),
          ),
        ),
        Positioned(
          top: -44,
          right: -28,
          child: _GlowOrb(
            color: isDark ? const Color(0xFF63E6FF) : const Color(0xFF2E90FA),
            alpha: isDark ? 0.14 : 0.10,
            size: 170,
          ),
        ),
        Positioned(
          bottom: -60,
          left: -36,
          child: _GlowOrb(
            color: isDark ? const Color(0xFF8A7CFF) : const Color(0xFF7C4DFF),
            alpha: isDark ? 0.12 : 0.08,
            size: 200,
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double alpha;
  final double size;

  const _GlowOrb({
    required this.color,
    required this.alpha,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: alpha),
      ),
    );
  }
}

