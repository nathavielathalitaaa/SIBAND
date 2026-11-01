import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'guide_calming_screen.dart';

class GuideScreen extends StatelessWidget {
  final int? childId;

  const GuideScreen({
    super.key,
    this.childId,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6F4EF),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalPadding = width * 0.06;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Panduan Praktis',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E2A24),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Langkah-langkah pendampingan anak saat menghadapi situasi sulit.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6F7B74),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Kartu Panduan Menenangkan
                  Semantics(
                    label: 'Panduan menenangkan, Saat anak sedang tantrum',
                    button: true,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GuideCalmingScreen(childId: childId),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE3EEDF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_border_rounded,
                                size: 28,
                                color: Color(0xFF1F5C4A),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Panduan menenangkan',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E2A24),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Saat anak sedang tantrum',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF6F7B74),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
