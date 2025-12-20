import 'package:flutter/material.dart';

class RunicDivider extends StatelessWidget {
  final double height;
  final Color color;

  const RunicDivider({
    super.key,
    this.height = 20,
    this.color = const Color(0xFFB71C1C),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _RunicPainter(color)),
    );
  }
}

class _RunicPainter extends CustomPainter {
  final Color color;
  _RunicPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    double midY = size.height / 2;

    // Elven/Nordic style line with runic knot in the middle
    path.moveTo(0, midY);
    path.lineTo(size.width * 0.4, midY);

    // Middle knot
    double centerX = size.width / 2;
    path.lineTo(centerX - 10, midY - 10);
    path.lineTo(centerX, midY + 10);
    path.lineTo(centerX + 10, midY - 10);
    path.lineTo(centerX, midY);

    path.moveTo(centerX + 10, midY);
    path.lineTo(size.width, midY);

    canvas.drawPath(path, paint);

    // Add glow
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.2)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.1,
    this.borderColor = const Color(0xFFB71C1C),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}

class MeshijiDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const MeshijiDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        borderColor: const Color(0xFFB71C1C),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFB71C1C),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              const RunicDivider(height: 20),
              const SizedBox(height: 16),
              content,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
