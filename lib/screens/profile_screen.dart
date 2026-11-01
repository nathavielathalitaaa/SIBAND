import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/ble_service.dart';
import '../services/heart_rate_service.dart';
import 'bpm_dashboard_screen.dart' hide Mode, HrSensorStatus;
import 'manage_children_screen.dart';
import 'onboarding_screen.dart';

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
  final BleService _bleService = BleService();
  final HeartRateService _hrService = HeartRateService.instance;

  String _userName = 'Memuat...';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
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
      await _pickBleDeviceAndConnect();
    }
  }

  Future<void> _pickBleDeviceAndConnect() async {
    final devices = await _bleService.getBondedDevices();
    if (!mounted) return;

    if (devices.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Tidak Ada Perangkat', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          content: Text(
            'Tidak ada device Bluetooth yang terpasang. Pasangkan smartband dulu lewat Pengaturan Bluetooth HP.',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final chosenDevice = await showDialog<BluetoothDevice>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Pilih Device Bluetooth', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final d = devices[index];
                final name = d.platformName.isNotEmpty ? d.platformName : 'Perangkat Tanpa Nama';
                return ListTile(
                  leading: const Icon(Icons.watch, color: Color(0xFF1F5C4A)),
                  title: Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(d.remoteId.str, style: GoogleFonts.inter(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, d),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );

    if (chosenDevice == null || !mounted) return;

    await _hrService.connectToDevice(chosenDevice);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Menghubungkan ke ${chosenDevice.platformName.isNotEmpty ? chosenDevice.platformName : chosenDevice.remoteId.str}...'),
        backgroundColor: const Color(0xFF1F5C4A),
      ),
    );
    setState(() {});
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
            // User Card
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
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3EEDF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: Color(0xFF1F5C4A),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E2A24),
                          ),
                        ),
                        if (_userEmail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _userEmail,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF6F7B74),
                            ),
                          ),
                        ],
                      ],
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
                            onChildrenUpdated: widget.onChildrenChanged,
                          ),
                        ),
                      );
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
