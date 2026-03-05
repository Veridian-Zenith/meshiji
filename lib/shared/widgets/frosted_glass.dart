import 'dart:ui';
import 'package:flutter/material.dart';

class FrostedGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadiusGeometry? borderRadius;

  const FrostedGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(0), // Padding is handled inside now
    this.margin = EdgeInsets.zero,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(24);

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              // Use semi-transparent BLACK, not grey. This is the key fix.
              color: Colors.black.withAlpha((255 * 0.4).round()),
              borderRadius: effectiveBorderRadius,
              border: Border.all(
                color: Colors.white.withAlpha(20),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
