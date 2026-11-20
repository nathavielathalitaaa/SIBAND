import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ThinLineNavType { home, guide, recap, location, profile }

/// Logo Siband bergaya SVG garis tipis (monoline stroke).
class SibandThinLineLogo extends StatelessWidget {
  final double size;
  final Color color;
  final bool showWordmark;

  const SibandThinLineLogo({
    super.key,
    this.size = 30,
    this.color = const Color(0xFF1F5C4A),
    this.showWordmark = true,
  });

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SibandThinLogoPainter(color: color),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Siband',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SibandThinLogoPainter extends CustomPainter {
  final Color color;

  const _SibandThinLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Strap atas & bawah bergaya garis tipis (siluet smartwatch)
    final strapTop = Path()
      ..moveTo(w * 0.36, h * 0.16)
      ..lineTo(w * 0.39, h * 0.05)
      ..lineTo(w * 0.61, h * 0.05)
      ..lineTo(w * 0.64, h * 0.16);
    final strapBottom = Path()
      ..moveTo(w * 0.36, h * 0.84)
      ..lineTo(w * 0.39, h * 0.95)
      ..lineTo(w * 0.61, h * 0.95)
      ..lineTo(w * 0.64, h * 0.84);
    canvas.drawPath(strapTop, stroke);
    canvas.drawPath(strapBottom, stroke);

    // Bodi jam membulat tipis
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.16, w * 0.68, h * 0.68),
      Radius.circular(w * 0.22),
    );
    canvas.drawRRect(bodyRect, stroke);

    // Gelombang denyut (pulse line) minimalis di tengah bodi jam
    final pulse = Path()
      ..moveTo(w * 0.26, h * 0.52)
      ..lineTo(w * 0.38, h * 0.52)
      ..lineTo(w * 0.44, h * 0.36)
      ..lineTo(w * 0.53, h * 0.64)
      ..lineTo(w * 0.59, h * 0.48)
      ..lineTo(w * 0.64, h * 0.52)
      ..lineTo(w * 0.74, h * 0.52);
    canvas.drawPath(pulse, stroke);
  }

  @override
  bool shouldRepaint(covariant _SibandThinLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Ikon navigasi vektor bergaya SVG garis tipis (monoline stroke).
class ThinLineNavIcon extends StatelessWidget {
  final ThinLineNavType type;
  final Color color;
  final double size;
  final bool isSelected;

  const ThinLineNavIcon({
    super.key,
    required this.type,
    required this.color,
    this.size = 22,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ThinLineNavPainter(
          type: type,
          color: color,
          strokeWidth: isSelected ? 1.75 : 1.45,
        ),
      ),
    );
  }
}

class _ThinLineNavPainter extends CustomPainter {
  final ThinLineNavType type;
  final Color color;
  final double strokeWidth;

  const _ThinLineNavPainter({
    required this.type,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case ThinLineNavType.home:
        final roof = Path()
          ..moveTo(w * 0.14, h * 0.46)
          ..lineTo(w * 0.50, h * 0.15)
          ..lineTo(w * 0.86, h * 0.46);
        final walls = Path()
          ..moveTo(w * 0.23, h * 0.42)
          ..lineTo(w * 0.23, h * 0.84)
          ..lineTo(w * 0.77, h * 0.84)
          ..lineTo(w * 0.77, h * 0.42);
        final door = RRect.fromRectAndCorners(
          Rect.fromLTWH(w * 0.41, h * 0.56, w * 0.18, h * 0.28),
          topLeft: Radius.circular(w * 0.08),
          topRight: Radius.circular(w * 0.08),
        );
        canvas.drawPath(roof, paint);
        canvas.drawPath(walls, paint);
        canvas.drawRRect(door, paint);
        break;

      case ThinLineNavType.guide:
        final leftPage = Path()
          ..moveTo(w * 0.50, h * 0.24)
          ..quadraticBezierTo(w * 0.32, h * 0.17, w * 0.14, h * 0.22)
          ..lineTo(w * 0.14, h * 0.78)
          ..quadraticBezierTo(w * 0.32, h * 0.73, w * 0.50, h * 0.82);
        final rightPage = Path()
          ..moveTo(w * 0.50, h * 0.24)
          ..quadraticBezierTo(w * 0.68, h * 0.17, w * 0.86, h * 0.22)
          ..lineTo(w * 0.86, h * 0.78)
          ..quadraticBezierTo(w * 0.68, h * 0.73, w * 0.50, h * 0.82);
        canvas.drawPath(leftPage, paint);
        canvas.drawPath(rightPage, paint);
        canvas.drawLine(
          Offset(w * 0.50, h * 0.24),
          Offset(w * 0.50, h * 0.82),
          paint,
        );
        break;

      case ThinLineNavType.recap:
        canvas.drawLine(
          Offset(w * 0.14, h * 0.84),
          Offset(w * 0.86, h * 0.84),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.20, h * 0.52, w * 0.13, h * 0.32),
            Radius.circular(w * 0.04),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.435, h * 0.30, w * 0.13, h * 0.54),
            Radius.circular(w * 0.04),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.67, h * 0.42, w * 0.13, h * 0.42),
            Radius.circular(w * 0.04),
          ),
          paint,
        );
        break;

      case ThinLineNavType.location:
        final pin = Path()
          ..moveTo(w * 0.50, h * 0.88)
          ..cubicTo(
            w * 0.22,
            h * 0.62,
            w * 0.20,
            h * 0.20,
            w * 0.50,
            h * 0.14,
          )
          ..cubicTo(
            w * 0.80,
            h * 0.20,
            w * 0.78,
            h * 0.62,
            w * 0.50,
            h * 0.88,
          );
        canvas.drawPath(pin, paint);
        canvas.drawCircle(Offset(w * 0.50, h * 0.41), w * 0.11, paint);
        break;

      case ThinLineNavType.profile:
        canvas.drawCircle(Offset(w * 0.50, h * 0.33), w * 0.17, paint);
        final shoulders = Path()
          ..moveTo(w * 0.20, h * 0.84)
          ..quadraticBezierTo(w * 0.24, h * 0.58, w * 0.50, h * 0.58)
          ..quadraticBezierTo(w * 0.76, h * 0.58, w * 0.80, h * 0.84);
        canvas.drawPath(shoulders, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ThinLineNavPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
