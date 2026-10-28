import 'dart:math';
import 'package:flutter/material.dart';

/// Party-popper / confetti-cannon burst. Fires two cannons from the bottom
/// corners toward the centre, plus a radial pop, then confetti falls with
/// gravity. Purely visual: wrapped in IgnorePointer so taps pass through.
class BurstEffect extends StatefulWidget {
  /// Change the key (or call [BurstEffectState.fire]) to replay.
  const BurstEffect({super.key});

  @override
  State<BurstEffect> createState() => BurstEffectState();
}

class BurstEffectState extends State<BurstEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));
  List<_Particle> _ps = const [];

  static const _colors = [
    Color(0xFF7C3AED), Color(0xFFD946EF), Color(0xFFFBBF24),
    Color(0xFF34D399), Color(0xFF60A5FA), Color(0xFFF97316), Color(0xFFEF4444),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => fire());
  }

  void fire() {
    final r = Random();
    final ps = <_Particle>[];
    // Two cannons, bottom-left and bottom-right, aimed up and inward.
    for (final side in const [-1, 1]) {
      for (var i = 0; i < 45; i++) {
        final angle = (-pi / 2) - side * (0.25 + r.nextDouble() * 0.55);
        final speed = 0.9 + r.nextDouble() * 1.1;
        ps.add(_Particle(
          origin: Offset(side < 0 ? 0.04 : 0.96, 1.0),
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: _colors[r.nextInt(_colors.length)],
          size: 5 + r.nextDouble() * 6,
          spin: r.nextDouble() * 10,
          circle: r.nextBool(),
        ));
      }
    }
    // Radial pop from the middle.
    for (var i = 0; i < 40; i++) {
      final angle = r.nextDouble() * 2 * pi;
      final speed = 0.25 + r.nextDouble() * 0.7;
      ps.add(_Particle(
        origin: const Offset(0.5, 0.55),
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 0.2,
        color: _colors[r.nextInt(_colors.length)],
        size: 4 + r.nextDouble() * 5,
        spin: r.nextDouble() * 10,
        circle: r.nextBool(),
      ));
    }
    setState(() => _ps = ps);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(_ps, _c.value),
        ),
      ),
    );
  }
}

class _Particle {
  final Offset origin; // fractions of the canvas
  final double vx, vy; // canvas-heights per second-ish
  final Color color;
  final double size, spin;
  final bool circle;
  const _Particle({
    required this.origin, required this.vx, required this.vy,
    required this.color, required this.size, required this.spin,
    required this.circle,
  });
}

class _BurstPainter extends CustomPainter {
  final List<_Particle> ps;
  final double t; // 0..1
  _BurstPainter(this.ps, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final secs = t * 2.6;
    final fade = t < 0.7 ? 1.0 : (1 - t) / 0.3;
    final paint = Paint();
    for (final p in ps) {
      final x = (p.origin.dx + p.vx * secs * 0.55) * size.width;
      final y = (p.origin.dy + p.vy * secs * 0.9 + 0.9 * secs * secs) *
          size.height;
      if (y > size.height + 20) continue;
      paint.color = p.color.withOpacity(fade.clamp(0.0, 1.0));
      if (p.circle) {
        canvas.drawCircle(Offset(x, y), p.size / 2, paint);
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(p.spin * secs);
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t || old.ps != ps;
}
