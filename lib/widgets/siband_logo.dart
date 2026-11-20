import 'package:flutter/material.dart';

/// Logo sementara Siband: garis detak yang membentuk huruf S, naik sekali lalu
/// tenang, hijau tua dengan satu titik amber di dalam persegi membulat hijau muda.
/// Sementara, ganti dengan logo dari desain tim.
class SibandLogo extends StatelessWidget {
  final double size;

  const SibandLogo({
    super.key,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo Siband',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size.square(size),
          painter: _SibandLogoPainter(),
        ),
      ),
    );
  }
}

class _SibandLogoPainter extends CustomPainter {
  static const Color _kGreenDark = Color(0xFF1F5C4A);
  static const Color _kGreenSoft = Color(0xFFE3EEDF);
  static const Color _kAmber = Color(0xFFE8A24F);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Persegi membulat hijau muda
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.26),
    );
    canvas.drawRRect(bgRect, Paint()..color = _kGreenSoft);

    // Garis detak membentuk huruf S: naik sekali lalu tenang
    final strokePaint = Paint()
      ..color = _kGreenDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.085).clamp(1.6, 5.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      // Awal atas kanan melengkung ke kiri atas (lengkung atas S)
      ..moveTo(w * 0.72, h * 0.25)
      ..cubicTo(
        w * 0.56,
        h * 0.16,
        w * 0.26,
        h * 0.20,
        w * 0.26,
        h * 0.36,
      )
      // Melintas tengah dengan satu kenaikan detak singkat
      ..cubicTo(
        w * 0.26,
        h * 0.48,
        w * 0.40,
        h * 0.48,
        w * 0.46,
        h * 0.48,
      )
      ..lineTo(w * 0.53, h * 0.35)
      ..lineTo(w * 0.60, h * 0.55)
      // Melengkung bawah kanan lalu tenang ke kiri bawah (lengkung bawah S)
      ..cubicTo(
        w * 0.74,
        h * 0.58,
        w * 0.76,
        h * 0.78,
        w * 0.52,
        h * 0.80,
      )
      ..cubicTo(
        w * 0.38,
        h * 0.81,
        w * 0.27,
        h * 0.76,
        w * 0.24,
        h * 0.72,
      );

    canvas.drawPath(path, strokePaint);

    // Satu titik amber di puncak detak
    final dotRadius = (w * 0.075).clamp(1.8, 5.5);
    canvas.drawCircle(
      Offset(w * 0.53, h * 0.35),
      dotRadius,
      Paint()..color = _kAmber,
    );
  }

  @override
  bool shouldRepaint(covariant _SibandLogoPainter oldDelegate) => false;
}
