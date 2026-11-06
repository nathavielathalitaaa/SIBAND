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
                    child: TextButton(
                      onPressed: () {},
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
                  const Divider(height: 1, indent: 64, endIndent: 20),

                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    ),
                    title: Text(
                      'Keluar',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.redAccent),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.redAccent),
                    onTap: _handleLogout,
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
