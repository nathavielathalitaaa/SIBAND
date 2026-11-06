import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/heart_rate_service.dart';
import '../utils/event_type_helper.dart';
import 'manage_children_screen.dart';
import 'onboarding_screen.dart';

class JournalPrivacyScreen extends StatefulWidget {
  final ChildModel? initialChild;
  final VoidCallback? onChildrenChanged;
  final ApiService? apiService;

  const JournalPrivacyScreen({
    super.key,
    this.initialChild,
    this.onChildrenChanged,
    this.apiService,
  });

  @override
  State<JournalPrivacyScreen> createState() => _JournalPrivacyScreenState();
}

class _JournalPrivacyScreenState extends State<JournalPrivacyScreen> {
  static const String activeChildIdKey = 'active_child_id';

  late final ApiService _apiService;
  final AuthService _authService = AuthService();
  final HeartRateService _hrService = HeartRateService.instance;

  ChildModel? _activeChild;
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _activeChild = widget.initialChild;
    _loadData();
  }

  Future<void> _handleAuthError() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      (route) => false,
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      ChildModel? child = _activeChild;
      if (child == null) {
        final list = await _apiService.getChildren();
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        final savedId = prefs.getInt(activeChildIdKey);
        if (list.isNotEmpty) {
          if (savedId != null) {
            child = list.firstWhere(
              (c) => c.id == savedId,
              orElse: () => list.first,
            );
          } else {
            child = list.first;
          }
          await prefs.setInt(activeChildIdKey, child.id);
        }
      }

      if (child == null) {
        if (!mounted) return;
        setState(() {
          _activeChild = null;
          _notes = [];
          _isLoading = false;
        });
        return;
      }

      final notes = await _apiService.getEventNotes(child.id);
      if (!mounted) return;
      setState(() {
        _activeChild = child;
        _notes = notes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('Unauthenticated') || e.toString().contains('401')) {
        await _handleAuthError();
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  String _formatNoteTime(dynamic raw) {
    if (raw == null) return '-';
    final str = raw.toString().trim();
    if (str.isEmpty) return '-';
    final dt = DateTime.tryParse(str);
    if (dt == null) return str;
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year, $hour:$minute';
  }

  Future<bool> _confirmAndDeleteNote(Map<String, dynamic> item) async {
    final rawId = item['id'];
    final noteId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (noteId == null) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus catatan?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: Text(
          'Catatan kejadian ini akan dihapus secara permanen.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(color: const Color(0xFF6F7B74)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD01A10),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return false;

    try {
      final success = await _apiService.deleteEventNote(noteId);
      if (!mounted) return false;
      if (success) {
        setState(() {
          _notes.removeWhere((n) => n['id']?.toString() == noteId.toString());
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catatan kejadian dihapus'),
            backgroundColor: Color(0xFF1F5C4A),
          ),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menghapus catatan'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      if (e.toString().contains('Unauthenticated') || e.toString().contains('401')) {
        await _handleAuthError();
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus catatan'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }
  }

  Future<void> _handleDeleteActiveChild() async {
    final child = _activeChild;
    if (child == null) return;

    // Langkah 1 konfirmasi
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus data anak ini?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: Text(
          'Seluruh catatan kejadian dan riwayat pemantauan "${child.nickname}" akan ikut terhapus.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(color: const Color(0xFF6F7B74)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD01A10),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );

    if (step1 != true || !mounted) return;

    // Langkah 2 konfirmasi
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Konfirmasi akhir',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: Text(
          'Tindakan ini tidak dapat dibatalkan. Yakin ingin menghapus data "${child.nickname}" sekarang?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(color: const Color(0xFF6F7B74)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD01A10),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ya, hapus permanen'),
          ),
        ],
      ),
    );

    if (step2 != true || !mounted) return;

    final deleted = await _apiService.deleteChild(child.id);
    if (!mounted) return;

    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus data anak'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<ChildModel> remaining = [];
    try {
      remaining = await _apiService.getChildren();
    } catch (_) {}

    if (remaining.isNotEmpty) {
      final nextChild = remaining.first;
      await prefs.setInt(activeChildIdKey, nextChild.id);
      _hrService.setActiveChild(nextChild.id);
      widget.onChildrenChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data anak berhasil dihapus'),
          backgroundColor: Color(0xFF1F5C4A),
        ),
      );
      Navigator.pop(context, true);
    } else {
      await prefs.remove(activeChildIdKey);
      widget.onChildrenChanged?.call();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ManageChildrenScreen(
            onChildrenUpdated: widget.onChildrenChanged,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      appBar: AppBar(
        title: Text(
          'Jurnal & privasi',
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
              'Jurnal catatan kejadian',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E2A24),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Color(0xFF1F5C4A)),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF6F7B74),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F5C4A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              )
            else if (_notes.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Belum ada catatan kejadian',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF6F7B74),
                  ),
                ),
              )
            else
              Column(
                children: _notes.map((item) {
                  final rawType = item['type']?.toString() ?? 'lainnya';
                  final typeLabel = getEventTypeName(rawType);
                  final noteText = item['note']?.toString().trim() ?? '';
                  final timeLabel = _formatNoteTime(item['occurred_at'] ?? item['created_at']);
                  final itemKey = ValueKey('note_${item['id']}');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
                      key: itemKey,
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmAndDeleteNote(item),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD01A10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    typeLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E2A24),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF6F7B74),
                                    ),
                                  ),
                                  if (noteText.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      noteText,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: const Color(0xFF1E2A24),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Semantics(
                              label: 'Hapus catatan $typeLabel',
                              button: true,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFD01A10),
                                  size: 20,
                                ),
                                onPressed: () => _confirmAndDeleteNote(item),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            Text(
              'Privasi',
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Data anak bersifat pribadi. Kamu bisa menghapus catatan dan seluruh data anak kapan saja.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: const Color(0xFF1E2A24),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 44,
                    child: Semantics(
                      label: 'Hapus data anak ini',
                      button: true,
                      child: OutlinedButton(
                        onPressed: _activeChild == null ? null : _handleDeleteActiveChild,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD01A10),
                          side: const BorderSide(color: Color(0xFFD01A10)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Hapus data anak ini',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFD01A10),
                          ),
                        ),
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

