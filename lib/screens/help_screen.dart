import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Jam mengirim detak jantung anak secara berkala ke aplikasi.',
      'Siband membandingkannya dengan baseline anak untuk mengenali perubahan pola.',
      'Catatan kejadian dari pendamping memberi konteks situasi yang dialami anak.',
      'Rekap dapat dibagikan ke terapis lewat tautan yang bisa dicabut kapan saja.',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      appBar: AppBar(
        title: Text(
          'Bantuan dan dukungan',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E2A24),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Semantics(
          label: 'Kembali',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E2A24)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cara kerja singkat',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E2A24),
              ),
            ),
            const SizedBox(height: 12),
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
                children: List.generate(steps.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1F5C4A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            steps[index],
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.5,
                              color: const Color(0xFF1E2A24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Batasan',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E2A24),
              ),
            ),
            const SizedBox(height: 12),
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
              child: Text(
                'Siband bukan alat diagnosis dan bukan pengganti tenaga profesional. Perubahan detak jantung bukan bukti stres. Jam tangan konsumen bisa salah baca saat anak banyak bergerak. Jam kadang beristirahat sebentar di antara pengukuran; itu normal.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: const Color(0xFF1E2A24),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3EEDF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF1F5C4A),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Jika anak dalam kondisi darurat, hubungi tenaga medis atau layanan darurat setempat.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: const Color(0xFF1F5C4A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

