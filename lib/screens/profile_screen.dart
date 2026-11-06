import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/heart_rate_service.dart';
import 'bpm_dashboard_screen.dart' hide Mode, HrSensorStatus;
import 'manage_children_screen.dart';
import 'onboarding_screen.dart';
import 'pair_device_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onChildrenChanged;

  const ProfileScreen({
    super.key,
    this.onChildrenChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final HeartRateService _hrService = HeartRateService.instance;

  static const String activeChildIdKey = 'active_child_id';

  String _userName = 'Memuat...';
  String _userEmail = '';
  ChildModel? _activeChild;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchActiveChild();
    _hrService.addListener(_onHrChanged);
  }

  void _onHrChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hrService.removeListener(_onHrChanged);
    super.dispose();
  }

  Future<void> _fetchActiveChild() async {
    try {
      final list = await _apiService.getChildren();
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final savedChildId = prefs.getInt(activeChildIdKey);

      ChildModel? selectedChild;
      if (list.isNotEmpty) {
        if (savedChildId != null) {
          selectedChild = list.firstWhere(
            (c) => c.id == savedChildId,
            orElse: () => list.first,
          );
        } else {
          selectedChild = list.first;
        }
        await prefs.setInt(activeChildIdKey, selectedChild.id);
        _hrService.setActiveChild(selectedChild.id);
      }

      if (!mounted) return;
      setState(() {
        _activeChild = selectedChild;
      });
    } catch (_) {}
  }

  Future<void> _fetchUserData() async {
    try {
      final user = await _apiService.getUserProfile();
      if (!mounted) return;
      setState(() {
        if (user != null) {
          _userName = user['name']?.toString() ?? 'Orang Tua';
          _userEmail = user['email']?.toString() ?? '';
        } else {
          _userName = 'Orang Tua';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userName = 'Orang Tua';
      });
    }
  }

  Future<void> _showEditProfileSheet() async {
    final activeChild = _activeChild;
    final nicknameController = TextEditingController(text: activeChild?.nickname ?? '');
    final birthYearController = TextEditingController(
      text: activeChild != null ? activeChild.birthYear.toString() : '',
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Edit profil',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E2A24),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nicknameController,
                        decoration: InputDecoration(
                          labelText: 'Nama panggilan',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          if (trimmed.length > 255) {
                            return 'Nama maksimal 255 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: birthYearController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Tahun lahir',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Tahun lahir tidak boleh kosong';
                          }
                          final year = int.tryParse(trimmed);
                          final currentYear = DateTime.now().year;
                          if (year == null || year < 1900 || year > currentYear) {
                            return 'Masukkan tahun yang valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ManageChildrenScreen(
                                  onChildrenUpdated: () {
                                    _fetchActiveChild();
                                    widget.onChildrenChanged?.call();
                                  },
                                ),
                              ),
                            );
                            await _fetchActiveChild();
                            widget.onChildrenChanged?.call();
                          },
                          child: Text(
                            'Kelola anak',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F5C4A),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving ? null : () => Navigator.pop(ctx),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.inter(color: const Color(0xFF6F7B74)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    if (activeChild == null) return;
                                    setSheetState(() {
                                      isSaving = true;
                                    });
                                    final nickname = nicknameController.text.trim();
                                    final birthYear = int.parse(birthYearController.text.trim());
                                    final navigator = Navigator.of(ctx);
                                    final messenger = ScaffoldMessenger.of(context);

                                    final updated = await _apiService.updateChild(
                                      id: activeChild.id,
                                      nickname: nickname,
                                      birthYear: birthYear,
                                    );
                                    navigator.pop();
                                    if (!mounted) return;
                                    if (updated != null) {
                                      setState(() {
                                        _activeChild = updated;
                                      });
                                      await _fetchActiveChild();
                                      widget.onChildrenChanged?.call();
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Profil anak berhasil diperbarui'),
                                          backgroundColor: Color(0xFF1F5C4A),
                                        ),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Gagal memperbarui profil anak'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F5C4A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Simpan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDataSourceSelection() async {
    final currentMode = _hrService.currentMode;
    final selectedMode = await showDialog<Mode>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Pilih Sumber Data',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: currentMode == Mode.dummy ? const Color(0xFFE3EEDF) : null,
                leading: Icon(
                  Icons.bolt_rounded,
                  color: currentMode == Mode.dummy ? const Color(0xFF1F5C4A) : const Color(0xFF6F7B74),
                ),
                title: Text(
                  'Mode Dummy',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: currentMode == Mode.dummy ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                subtitle: Text(
                  'Data simulasi acak',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: currentMode == Mode.dummy
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1F5C4A))
                    : null,
                onTap: () => Navigator.pop(ctx, Mode.dummy),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: currentMode == Mode.ble ? const Color(0xFFE3EEDF) : null,
                leading: Icon(
                  Icons.bluetooth_rounded,
                  color: currentMode == Mode.ble ? const Color(0xFF1F5C4A) : const Color(0xFF6F7B74),
                ),
                title: Text(
                  'BLE Asli (Smartband)',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: currentMode == Mode.ble ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                subtitle: Text(
                  'Hubungkan ke jam lewat Bluetooth',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: currentMode == Mode.ble
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1F5C4A))
                    : null,
                onTap: () => Navigator.pop(ctx, Mode.ble),
              ),
            ],
          ),
        );
      },
    );

    if (selectedMode == null || !mounted) return;

    if (selectedMode == Mode.dummy) {
      _hrService.switchMode(Mode.dummy);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beralih ke Mode Dummy'),
            backgroundColor: Color(0xFF1F5C4A),
          ),
        );
        setState(() {});
      }
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PairDeviceScreen(),
        ),
      );
      if (mounted) setState(() {});
    }
  }


  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Konfirmasi Keluar', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('Apakah Anda yakin ingin keluar dari akun ini?', style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF6F7B74))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final childName = _activeChild != null && _activeChild!.nickname.isNotEmpty
        ? _activeChild!.nickname
        : _userName;
    final initial = childName.trim().isNotEmpty
        ? childName.trim()[0].toUpperCase()
        : '?';
    final subtitleText = _activeChild != null
        ? '${DateTime.now().year - _activeChild!.birthYear} tahun'
        : _userEmail;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      appBar: AppBar(
        title: Text(
          'Profil',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E2A24),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Active Child Card
            Container(
              padding: const EdgeInsets.all(20),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3EEDF),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F5C4A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          childName.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E2A24),
                          ),
                        ),
                        if (subtitleText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitleText,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF6F7B74),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Semantics(
                      label: 'Edit profil',
                      button: true,
                      child: TextButton(
                        onPressed: _showEditProfileSheet,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFE8F0E3),
                          foregroundColor: const Color(0xFF1F5C4A),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Edit profil',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F5C4A),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Informasi pendamping
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Informasi pendamping',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E2A24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
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
                    'Nama orang tua/wali',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF6F7B74),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E2A24),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Email akun',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF6F7B74),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _userEmail.isNotEmpty ? _userEmail : '-',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E2A24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Settings Group
            Container(
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
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3EEDF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.child_care_rounded, color: Color(0xFF1F5C4A), size: 20),
                    ),
                    title: Text(
                      'Kelola anak',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF1E2A24)),
                    ),
                    subtitle: Text(
                      'Daftar, tambah, ubah, dan hapus profil anak',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6F7B74)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6F7B74)),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManageChildrenScreen(
                            onChildrenUpdated: () {
                              _fetchActiveChild();
                              widget.onChildrenChanged?.call();
                            },
                          ),
                        ),
                      );
                      await _fetchActiveChild();
                      widget.onChildrenChanged?.call();
                    },
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 20),

                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3EEDF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sensors_rounded, color: Color(0xFF1F5C4A), size: 20),
                    ),
                    title: Text(
                      'Sumber data',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF1E2A24)),
                    ),
                    subtitle: Text(
                      _hrService.currentMode == Mode.dummy ? 'Mode Dummy' : 'BLE Asli',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6F7B74)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6F7B74)),
                    onTap: _handleDataSourceSelection,
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 20),

                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3EEDF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.watch_rounded, color: Color(0xFF1F5C4A), size: 20),
                    ),
                    title: Text(
                      'Jam terpasang',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF1E2A24)),
                    ),
                    subtitle: Text(
                      _hrService.pairedDeviceName != null
                          ? _hrService.pairedDeviceName!
                          : 'Belum ada jam terpasang',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6F7B74)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6F7B74)),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PairDeviceScreen(),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 20),

                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3EEDF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.developer_board_rounded, color: Color(0xFF1F5C4A), size: 20),
                    ),
                    title: Text(
                      'Layar teknis (lama)',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF1E2A24)),
                    ),
                    subtitle: Text(
                      'BpmDashboardScreen lama untuk pengujian BLE langsung',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6F7B74)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6F7B74)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BpmDashboardScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Semantics(
              label: 'Keluar',
              button: true,
              child: ElevatedButton(
                onPressed: _handleLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD01A10),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Keluar',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
