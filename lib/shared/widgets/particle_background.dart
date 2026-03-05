import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meshiji/theme/tokens/design_tokens.dart';

const List<String> runes = [
  "ᚦ",
  "ᚧ",
  "ᚨ",
  "ᚱ",
  "ᚷ",
  "ᚹ",
  "ᚺ",
  "ᚾ",
  "ᛁ",
  "ᛃ",
  "ᛈ",
  "ᛇ",
  "ᛉ",
  "ᛊ",
  "ᛏ",
  "ᛒ",
  "ᛖ",
  "ᛗ",
  "ᛚ",
  "ᛝ",
  "ᛟ",
  "ᛞ",
];

class RuneParticle {
  final String rune;
  final double size;
  final Offset position;
  final double speed;
  final int direction;
  final bool isTiny;
  final double initialRotation;
  final double initialYOffset;

  RuneParticle({
    required this.rune,
    required this.size,
    required this.position,
    required this.speed,
    required this.direction,
    required this.isTiny,
    required this.initialRotation,
    required this.initialYOffset,
  });
}

class RunePainter extends CustomPainter {
  final List<RuneParticle> particles;
  final double animationValue;

  RunePainter({required this.particles, required this.animationValue});
  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: particle.rune,
          style: TextStyle(
            fontSize: particle.size,
            fontFamily: 'Rosemary',
            color: particle.isTiny
                ? DesignTokens.accentPrimary.withAlpha((255 * 0.6).round())
                : DesignTokens.accentPrimary.withAlpha((255 * 0.1).round()),
            shadows: particle.isTiny
                ? [
                    const Shadow(
                      blurRadius: 8.0,
                      color: DesignTokens.accentPrimary,
                    ),
                  ]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      double dx = particle.position.dx;
      double dy = particle.position.dy;

      // Calculate new position based on the global animation value
      if (particle.isTiny) {
        // Simple vertical drift
        final effectiveY = dy + particle.initialYOffset;
        dy = (effectiveY - (animationValue * particle.speed)) % size.height;
      } else {
        // Slower, rotating horizontal drift
        final angle =
            (animationValue * 2 * pi / particle.speed) +
            particle.initialRotation;
        dx = (dx + particle.direction * 60 * sin(angle)) % size.width;
      }

      canvas.save();
      canvas.translate(dx, dy);
      if (!particle.isTiny) {
        final rotationAngle =
            (animationValue * 2 * pi / particle.speed) +
            particle.initialRotation;
        canvas.rotate(rotationAngle);
      }
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant RunePainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;
}

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> {
  final List<RuneParticle> _particles = [];
  final Random _random = Random();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_particles.isEmpty) {
      _createParticles();
    }
  }

  void _createParticles() {
    final size = MediaQuery.of(context).size;
    if (size.isEmpty) return;

    _particles.clear();
    // Massive Runes
    for (int i = 0; i < 18; i++) {
      _particles.add(
        RuneParticle(
          rune: runes[i % runes.length],
          size: 80 + _random.nextDouble() * 120,
          position: Offset(
            _random.nextDouble() * size.width,
            _random.nextDouble() * size.height,
          ),
          speed: 40 + _random.nextDouble() * 30,
          direction: i % 2 == 0 ? 1 : -1,
          isTiny: false,
          initialRotation: _random.nextDouble() * 2 * pi,
          initialYOffset: 0,
        ),
      );
    }
    // Tiny Runes
    for (int i = 0; i < 50; i++) {
      _particles.add(
        RuneParticle(
          rune: runes[i % runes.length],
          size: 10 + _random.nextDouble() * 10,
          position: Offset(
            _random.nextDouble() * size.width,
            _random.nextDouble() * size.height,
          ),
          speed: 20 + _random.nextDouble() * 20,
          direction: 1,
          isTiny: true,
          initialRotation: 0,
          initialYOffset: _random.nextDouble() * 100,
        ),
      );
    }
    // Use setState to ensure the widget rebuilds with particles
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // We use a simple container and the .animate extension method to create a looping animation
    return Positioned.fill(
      child: Container()
          .animate(onPlay: (controller) => controller.repeat())
          .custom(
            duration:
                120.seconds, // Long duration for a slow, continuous animation
            builder: (context, value, child) {
              // The 'value' goes from 0.0 to 1.0 over the duration
              // We pass this value to our painter to drive the animations
              return CustomPaint(
                painter: RunePainter(
                  particles: _particles,
                  animationValue:
                      value * 120, // Scale value to make movement more apparent
                ),
                child: Container(),
              );
            },
          ),
    );
  }
}
