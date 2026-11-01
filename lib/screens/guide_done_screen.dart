import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/guide_data.dart';
import '../services/api_service.dart';
import 'event_note_screen.dart';
import 'main_navigation_screen.dart';

class GuideDoneScreen extends StatelessWidget {
  final List<String> checkedItemIds;
  final int? childId;

  const GuideDoneScreen({
    super.key,
    required this.checkedItemIds,
    this.childId,
  });

  void _navigateToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MainNavigationScreen(initialIndex: 0),
      ),
      (route) => false,
    );
  }

  Future<void> _openEventNote(BuildContext context) async {
    int targetChildId = childId ?? 1;

    if (childId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedId = prefs.getInt('selected_child_id');
        if (savedId != null) {
          targetChildId = savedId;
        } else {
          final children = await ApiService().getChildren();
          if (children.isNotEmpty) {
            targetChildId = children.first.id;
          }
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventNoteScreen(
          childId: targetChildId,
          initialType: 'lainnya',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedItems = kCalmingChecklistItems
        .where((item) => checkedItemIds.contains(item.id))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalPadding = width * 0.07;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Lingkaran hijau muda + centang hijau tua
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3EEDF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 48,
                        color: Color(0xFF1F5C4A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Kamu sudah mendampingi dengan baik',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E2A24),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Terima kasih sudah mencoba langkah pendampingan. Setiap anak punya kebutuhan yang berbeda; proses kecil pun berarti.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6F7B74),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Kartu putih: Langkah yang sudah dicoba
                  Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Langkah yang sudah dicoba',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F5C4A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (completedItems.isEmpty)
                          Text(
                            'Belum ada langkah yang dipilih.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF6F7B74),
                            ),
                          )
                        else
                          ...List.generate(completedItems.length, (idx) {
                            final item = completedItems[idx];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: idx == completedItems.length - 1 ? 0 : 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: Color(0xFF57BB7B),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.doneText,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF1E2A24),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Kartu hijau muda: Apa yang membantu anak hari ini?
                  Semantics(
                    label: 'Apa yang membantu anak hari ini? Buka catatan kejadian',
                    button: true,
                    child: InkWell(
                      onTap: () => _openEventNote(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3EEDF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Apa yang membantu anak hari ini?',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1F5C4A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Catat pemicu, kebutuhan, atau strategi yang terasa membantu.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF1E2A24),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1F5C4A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Tombol putih "Kembali ke beranda"
                  SizedBox(
                    height: 52,
                    child: Semantics(
                      label: 'Kembali ke beranda',
                      button: true,
                      child: OutlinedButton(
                        onPressed: () => _navigateToHome(context),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Kembali ke beranda',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E2A24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
