import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';

class EventNoteScreen extends StatefulWidget {
  final int childId;

  const EventNoteScreen({
    super.key,
    required this.childId,
  });

  @override
  State<EventNoteScreen> createState() => _EventNoteScreenState();
}

class _EventNoteScreenState extends State<EventNoteScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  String _selectedType = 'suara_keras'; // Default Suara keras sesuai desain
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _eventTypes = [
    {
      'type': 'suara_keras',
      'label': 'Suara keras',
      'icon': Icons.volume_up_outlined,
    },
    {
      'type': 'perubahan_aktivitas',
      'label': 'Perubahan aktivitas',
      'icon': Icons.alt_route_rounded,
    },
    {
      'type': 'transisi',
      'label': 'Transisi kegiatan',
      'icon': Icons.swap_horiz_rounded,
    },
    {
      'type': 'aktivitas_sulit',
      'label': 'Aktivitas sulit',
      'icon': Icons.sentiment_dissatisfied_outlined,
    },
    {
      'type': 'interaksi_sosial',
      'label': 'Interaksi sosial',
      'icon': Icons.people_outline_rounded,
    },
    {
      'type': 'lainnya',
      'label': 'Lainnya',
      'icon': Icons.more_horiz_rounded,
    },
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    if (isToday) {
      return 'Hari ini, $hour:$minute';
    } else {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      return '$day/$month/$year, $hour:$minute';
    }
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1F5C4A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E2A24),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1F5C4A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E2A24),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final result = await _apiService.createEventNote(
      widget.childId,
      type: _selectedType,
      note: _noteController.text.trim(),
      occurredAt: _selectedDateTime,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catatan tersimpan'),
          backgroundColor: Color(0xFF1F5C4A),
        ),
      );
      Navigator.pop(context, true);
    } else {
      final msg = result['message']?.toString() ?? 'Gagal menyimpan catatan';
      if (msg.contains('Unauthenticated') || msg.contains('Sesi telah berakhir')) {
        await AuthService().logout();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            (route) => false,
          );
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalPadding = width * 0.08;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tombol kembali
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      label: 'Kembali',
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFD9DED6)),
                          ),
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

                  // Judul
                  Text(
                    'Catatan kejadian',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E2A24),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subjudul
                  Text(
                    'Tambahkan konteks untuk memahami perubahan detak jantung.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6F7B74),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Kartu WAKTU KEJADIAN
                  Semantics(
                    label: 'Pilih Waktu Kejadian',
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _pickDateTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3EEDF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.access_time_filled_rounded,
                                color: Color(0xFF1F5C4A),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WAKTU KEJADIAN',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                      color: const Color(0xFF6F7B74),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDateTime(_selectedDateTime),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E2A24),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: Color(0xFF6F7B74),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bagian "Apa yang terjadi?"
                  Text(
                    'Apa yang terjadi?',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E2A24),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grid 2 kolom pilihan tipe kejadian
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _eventTypes.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.3,
                    ),
                    itemBuilder: (context, index) {
                      final item = _eventTypes[index];
                      final isSelected = _selectedType == item['type'];

                      return Semantics(
                        label: item['label'] as String,
                        selected: isSelected,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _selectedType = item['type'] as String;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF1ECE9F) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1ECE9F)
                                    : const Color(0xFFD9DED6),
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? const Color(0xFF1ECE9F).withValues(alpha: 0.25)
                                      : Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  size: 22,
                                  color: isSelected ? Colors.white : const Color(0xFF1F5C4A),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['label'] as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? Colors.white : const Color(0xFF1E2A24),
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Catatan tambahan (opsional)
                  Text(
                    'Catatan tambahan (opsional)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E2A24),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Semantics(
                    label: 'Input catatan tambahan',
                    textField: true,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD9DED6)),
                      ),
                      child: TextField(
                        controller: _noteController,
                        maxLength: 500,
                        maxLines: 4,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF1E2A24),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Apa yang terlihat sebelum atau sesudah kejadian?',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF8A948E),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                          border: InputBorder.none,
                          counterStyle: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF6F7B74),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Tombol Simpan catatan
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F5C4A),
                        disabledBackgroundColor: const Color(0xFF1F5C4A).withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Simpan catatan',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
