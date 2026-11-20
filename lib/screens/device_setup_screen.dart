import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_model.dart';
import '../services/heart_rate_service.dart';
import 'bpm_dashboard_screen.dart' hide Mode, HrSensorStatus;
import 'pair_device_screen.dart';

class DeviceSetupScreen extends StatefulWidget {
  final ChildModel? activeChild;
  final HeartRateService? heartRateService;

  const DeviceSetupScreen({
    super.key,
    this.activeChild,
    this.heartRateService,
  });

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  static const Color _kGreen = Color(0xFF1F5C4A);
  static const Color _kGreenSoft = Color(0xFFE3EEDF);
  static const Color _kSand = Color(0xFFF6F4EF);
  static const Color _kAmber = Color(0xFFE8A24F);
  static const Color _kGrey = Color(0xFFD9DED6);
  static const Color _kText = Color(0xFF1E2A24);
  static const Color _kTextMuted = Color(0xFF6F7B74);

  late final HeartRateService _hrService;

  static const List<({String title, String detail})> _tutorialSteps = [
    (
      title: 'Nyalakan Bluetooth dan Lokasi',
      detail: 'Aktifkan Bluetooth serta izin lokasi di pengaturan HP.',
    ),
    (
      title: 'Putuskan dari aplikasi bawaan',
      detail: 'Putuskan jam dari aplikasi bawaan agar koneksi BLE tidak berebut.',
    ),
    (
      title: 'Pasang jam cukup pas di tangan',
      detail: 'Kenakan satu jari di atas tulang pergelangan agar sensor stabil.',
    ),
    (
      title: 'Ketuk Pasang jam lalu pilih perangkat',
      detail: 'Dekatkan smartwatch ke HP lalu pilih nama jam yang muncul.',
    ),
    (
      title: 'Tunggu bacaan pertama dari jam',
      detail: 'Sensor hijau menyala otomatis; layar jam tidak perlu menyala.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _hrService = widget.heartRateService ?? HeartRateService.instance;
    _hrService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _hrService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openPairDevice() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PairDeviceScreen(
          childId: widget.activeChild?.id,
          childNickname: widget.activeChild?.nickname,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _handleDataSourceSelection() async {
    final currentMode = _hrService.currentMode;

    final selectedMode = await showModalBottomSheet<Mode>(
      context: context,
      backgroundColor: _kSand,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _kGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pilih sumber data',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: currentMode == Mode.ble ? _kGreenSoft : null,
                  leading: Icon(
                    Icons.bluetooth_rounded,
                    color: currentMode == Mode.ble ? _kGreen : _kTextMuted,
                  ),
                  title: Text(
                    'BLE Asli (Smartwatch)',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: currentMode == Mode.ble
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: _kText,
                    ),
                  ),
                  subtitle: Text(
                    'Hubungkan ke jam lewat Bluetooth',
                    style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
                  ),
                  trailing: currentMode == Mode.ble
                      ? const Icon(Icons.check_circle_rounded, color: _kGreen)
                      : null,
                  onTap: () => Navigator.pop(ctx, Mode.ble),
                ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: currentMode == Mode.dummy ? _kGreenSoft : null,
                  leading: Icon(
                    Icons.bolt_rounded,
                    color: currentMode == Mode.dummy ? _kGreen : _kTextMuted,
                  ),
                  title: Text(
                    'Mode Dummy',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: currentMode == Mode.dummy
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: _kText,
                    ),
                  ),
                  subtitle: Text(
                    'Data simulasi untuk uji tampilan',
                    style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
                  ),
                  trailing: currentMode == Mode.dummy
                      ? const Icon(Icons.check_circle_rounded, color: _kGreen)
                      : null,
                  onTap: () => Navigator.pop(ctx, Mode.dummy),
                ),
              ],
            ),
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
            backgroundColor: _kGreen,
          ),
        );
        setState(() {});
      }
    } else {
      await _openPairDevice();
    }
  }

  BoxDecoration _cardDecoration(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final pairedName = _hrService.pairedDeviceName;
    final hasWatch =
        _hrService.activeDeviceId != null && pairedName != null && pairedName.isNotEmpty;
    final modeLabel =
        _hrService.currentMode == Mode.dummy ? 'Mode Dummy' : 'BLE Asli';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(_kGreenSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.watch_outlined,
                  color: _kGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasWatch ? pairedName : 'Belum ada jam terpasang',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mode aktif: $modeLabel',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('device_setup_pair_button'),
              onPressed: _openPairDevice,
              icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
              label: Text(
                'Pasang jam',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialCard() {
    return Container(
      key: const Key('smartwatch_tutorial_card'),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(
        Color.alphaBlend(_kAmber.withValues(alpha: 0.12), _kSand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _kGreenSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: _kGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tutorial hubungkan smartwatch',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                    Text(
                      'Ikuti langkah ini agar detak terbaca lancar.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(_tutorialSteps.length, (index) {
            final step = _tutorialSteps[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _tutorialSteps.length - 1 ? 0 : 10,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kSand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _kGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _kText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.detail,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _kTextMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kGreenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: _kGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Jam beristirahat sebentar di antara pengukuran untuk menghemat baterai; itu normal.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _kText,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard() {
    final modeText =
        _hrService.currentMode == Mode.dummy ? 'Mode Dummy' : 'BLE Asli';

    return Container(
      decoration: _cardDecoration(
        Color.alphaBlend(_kGrey.withValues(alpha: 0.35), _kSand),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: _kGreenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sensors_rounded,
                color: _kGreen,
                size: 19,
              ),
            ),
            title: Text(
              'Sumber data',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
            subtitle: Text(
              modeText,
              style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: _kTextMuted,
            ),
            onTap: _handleDataSourceSelection,
          ),
          Divider(height: 1, color: _kGrey.withValues(alpha: 0.7)),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: _kGreenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.developer_board_rounded,
                color: _kGreen,
                size: 19,
              ),
            ),
            title: Text(
              'Layar teknis (lama)',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
            subtitle: Text(
              'Pengujian koneksi BLE langsung',
              style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: _kTextMuted,
            ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSand,
      appBar: AppBar(
        title: Text(
          'Perangkat & sumber data',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _kText,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Semantics(
          label: 'Kembali',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _kText),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildTutorialCard(),
              const SizedBox(height: 16),
              _buildOptionsCard(),
            ],
          ),
        ),
      ),
    );
  }
}
