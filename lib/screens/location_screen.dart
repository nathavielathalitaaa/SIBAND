import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LocationScreen extends StatelessWidget {
  final VoidCallback? onBackToHome;

  const LocationScreen({
    super.key,
    this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tombol kembali kiri atas (kotak putih kecil)
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  label: 'Kembali ke Beranda',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (onBackToHome != null) {
                        onBackToHome!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: Color(0xFF1E2A24),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Judul & Subjudul
              Text(
                'Lokasi anak',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E2A24),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Lihat lokasi saat perangkat saat ini',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6F7B74),
                ),
              ),
              const SizedBox(height: 16),

              // Kartu status putih
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1F5C4A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode contoh',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E2A24),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Data demo · bukan lokasi sebenarnya',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF6F7B74),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Kartu peta demo
              Semantics(
                label: 'Peta contoh lokasi terakhir demo',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 240,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1EADC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DemoGridMapPainter(),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Lokasi terakhir (demo)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E2A24),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F5C4A).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1F5C4A),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Kartu putih Lokasi terakhir diketahui
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lokasi terakhir diketahui',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E2A24),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Koordinat GPS belum tersedia pada prototipe.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF1E2A24),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pembaruan: -',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6F7B74),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tombol hijau tua Perbarui Lokasi
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Semantics(
                  label: 'Perbarui Lokasi',
                  button: true,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pelacakan lokasi belum tersedia pada prototipe.'),
                          backgroundColor: Color(0xFF1F5C4A),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F5C4A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Perbarui Lokasi',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Teks kecil abu di bawah
              Text(
                'Fitur lokasi di luar cakupan versi ini. Tampilan di atas hanya contoh.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF6F7B74),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoGridMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mainRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final minorRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Garis grid horizontal
    final hOffsets = [0.2, 0.45, 0.72, 0.88];
    for (int i = 0; i < hOffsets.length; i++) {
      final y = size.height * hOffsets[i];
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        i == 1 ? mainRoadPaint : minorRoadPaint,
      );
    }

    // Garis grid vertikal
    final vOffsets = [0.18, 0.42, 0.68, 0.85];
    for (int i = 0; i < vOffsets.length; i++) {
      final x = size.width * vOffsets[i];
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i == 2 ? mainRoadPaint : minorRoadPaint,
      );
    }

    // Jalan diagonal sekunder untuk kesan peta
    canvas.drawLine(
      Offset(0, size.height * 0.85),
      Offset(size.width * 0.55, 0),
      minorRoadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
