import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/guide_data.dart';
import 'guide_done_screen.dart';

class GuideCalmingScreen extends StatefulWidget {
  final int? childId;

  const GuideCalmingScreen({
    super.key,
    this.childId,
  });

  @override
  State<GuideCalmingScreen> createState() => _GuideCalmingScreenState();
}

class _GuideCalmingScreenState extends State<GuideCalmingScreen> {
  // State checklist di memori, semua awalnya TIDAK dicentang
  final Set<String> _checkedIds = {};

  void _toggleItem(String id) {
    setState(() {
      if (_checkedIds.contains(id)) {
        _checkedIds.remove(id);
      } else {
        _checkedIds.add(id);
      }
    });
  }

  void _onFinish() {
    if (_checkedIds.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GuideDoneScreen(
          checkedItemIds: _checkedIds.toList(),
          childId: widget.childId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = kCalmingChecklistItems.length;
    final checkedCount = _checkedIds.length;
    final progress = totalItems > 0 ? (checkedCount / totalItems) : 0.0;
    final isButtonEnabled = checkedCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalPadding = width * 0.06;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Bar
                  Row(
                    children: [
                      Semantics(
                        label: 'Kembali',
                        button: true,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: Color(0xFF1E2A24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Panduan menenangkan',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E2A24),
                              ),
                            ),
                            Text(
                              'Saat anak sedang tantrum',
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
                  const SizedBox(height: 20),

                  // Kartu Hijau Tua: Utamakan aman dan tenang
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F5C4A),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1F5C4A).withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Utamakan aman dan tenang',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$checkedCount / $totalItems',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFE3EEDF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE8A24F)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Tantrum bisa menjadi tanda anak kewalahan.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFE3EEDF),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 6 Item Checklist
                  ...kCalmingChecklistItems.map((item) {
                    final isChecked = _checkedIds.contains(item.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isChecked ? const Color(0xFF1F5C4A) : const Color(0xFFE2E8F0),
                          width: isChecked ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Semantics(
                        label: '${item.title}, ${item.description}',
                        checked: isChecked,
                        child: InkWell(
                          onTap: () => _toggleItem(item.id),
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    color: isChecked ? const Color(0xFF1F5C4A) : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isChecked
                                          ? const Color(0xFF1F5C4A)
                                          : const Color(0xFFCBD5E1),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isChecked
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E2A24),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.description,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF6F7B74),
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  // Teks kecil di bawah daftar
                  Center(
                    child: Text(
                      'Panduan umum, bukan pengganti saran terapis atau tenaga profesional.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tombol Selesai (Aktif jika minimal 1 item dicentang)
                  SizedBox(
                    height: 52,
                    child: Semantics(
                      label: 'Selesai langkah panduan',
                      button: true,
                      enabled: isButtonEnabled,
                      child: ElevatedButton(
                        onPressed: isButtonEnabled ? _onFinish : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F5C4A),
                          disabledBackgroundColor: const Color(0xFFCBD5E1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Selesai',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
