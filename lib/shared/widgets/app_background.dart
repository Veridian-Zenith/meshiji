import 'package:flutter/material.dart';
import 'package:meshiji/shared/widgets/particle_background.dart';
import 'package:meshiji/theme/tokens/design_tokens.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1: Bright Gradient
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DesignTokens.colorRed,
                  DesignTokens.colorAmber,
                  DesignTokens.colorGold,
                ],
              ),
            ),
          ),
        ),
        // Layer 2: Darkening Overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: DesignTokens.backgroundPrimary.withAlpha(
                (255 * 0.85).round(),
              ),
            ),
          ),
        ),
        // Layer 3: Particles
        const ParticleBackground(),
      ],
    );
  }
}
