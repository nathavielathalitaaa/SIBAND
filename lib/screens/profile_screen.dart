import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/heart_rate_service.dart';
import 'device_setup_screen.dart';
import 'help_screen.dart';
import 'journal_privacy_screen.dart';
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
  static const Color _kGreen = Color(0xFF1F5C4A);
  static const Color _kGreenSoft = Color(0xFFE3EEDF);
  static const Color _kSand = Color(0xFFF6F4EF);
  static const Color _kAmber = Color(0xFFE8A24F);
  static const Color _kGrey = Color(0xFFD9DED6);
  static const Color _kText = Color(0xFF1E2A24);
  static const Color _kTextMuted = Color(0xFF6F7B74);
  static const Color _kBrightGreen = Color(0xFF1ECE9F);

  static final Color _kNeutralCard = Color.alphaBlend(
    _kGrey.withValues(alpha: 0.30),
    _kSand,
  );
  static final Color _kInfoCard = Color.alphaBlend(
    _kGreenSoft.withValues(alpha: 0.72),
    _kSand,
  );
  static final Color _kHeroDeep = Color.alphaBlend(
    _kText.withValues(alpha: 0.22),
    _kGreen,
  );
  static final Color _kWarmButtonBg = Color.alphaBlend(
    _kAmber.withValues(alpha: 0.16),
    _kSand,
  );

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
      backgroundColor: _kSand,
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
                            color: _kGrey,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Edit profil',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nicknameController,
                        decoration: InputDecoration(
                          labelText: 'Nama panggilan',
                          filled: true,
                          fillColor: _kNeutralCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _kGrey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _kGrey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _kGreen, width: 1.5),
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
                          filled: true,
                          fillColor: _kNeutralCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _kGrey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _kGrey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _kGreen, width: 1.5),
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
                              color: _kGreen,
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
                              style: GoogleFonts.inter(color: _kTextMuted),
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
                                          backgroundColor: _kGreen,
                                        ),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Gagal memperbarui profil anak'),
                                          backgroundColor: _kAmber,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kGreen,
                              foregroundColor: _kSand,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _kSand,
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

  Future<void> _openDeviceAndDataSourceSheet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceSetupScreen(
          activeChild: _activeChild,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  String _watchStatusSummary() {
    final connectedName = _hrService.connectedDevice?.platformName.trim();
    final watchName = (connectedName != null && connectedName.isNotEmpty)
        ? connectedName
        : _hrService.pairedDeviceName?.trim();
    if (_hrService.currentMode == Mode.ble) {
      if (_hrService.isConnectingBle) {
        return watchName != null && watchName.isNotEmpty
            ? 'Menyambungkan $watchName...'
            : 'Menyambungkan jam...';
      }
      switch (_hrService.sensorStatus) {
        case HrSensorStatus.measuring:
          return watchName != null && watchName.isNotEmpty
              ? 'Terhubung · $watchName'
              : 'Smartwatch terhubung';
        case HrSensorStatus.resting:
          return watchName != null && watchName.isNotEmpty
              ? '$watchName · siaga'
              : 'Smartwatch siaga';
        case HrSensorStatus.disconnected:
          return watchName != null && watchName.isNotEmpty
              ? '$watchName · belum tersambung'
              : 'Belum tersambung ke jam';
      }
    }
    return 'Mode contoh aktif · atur smartwatch';
  }

  Color _watchDotColor() {
    if (_hrService.currentMode == Mode.ble) {
      if (_hrService.isConnectingBle) return _kAmber;
      switch (_hrService.sensorStatus) {
        case HrSensorStatus.measuring:
          return _kBrightGreen;
        case HrSensorStatus.resting:
          return _kAmber;
        case HrSensorStatus.disconnected:
          return _kGrey;
      }
    }
    return _kAmber;
  }

  Widget _buildCompanionRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: _kSand,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: _kGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _kTextMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceCard({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    String? badge,
  }) {
    final disabled = onTap == null;
    return Semantics(
      label: disabled ? 'Segera hadir, belum aktif' : title,
      button: !disabled,
      enabled: !disabled,
      excludeSemantics: disabled,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: _kNeutralCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashFactory: disabled ? NoSplash.splashFactory : InkRipple.splashFactory,
              splashColor: disabled ? Colors.transparent : _kGreen.withValues(alpha: 0.08),
              highlightColor: disabled ? Colors.transparent : _kGreen.withValues(alpha: 0.04),
              hoverColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: _kGreenSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 20, color: _kGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _kText,
                            ),
                          ),
                          if (subtitle != null && subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: _kTextMuted,
                              ),
                            ),
                          ],
                          if (badge != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kGrey.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _kTextMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!disabled) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: _kTextMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Konfirmasi Keluar',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun ini?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: _kTextMuted,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: _kTextMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAmber,
              foregroundColor: _kText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Keluar',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
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
    final watchSummary = _watchStatusSummary();

    return Material(
      color: _kSand,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Editorial Header
              Text(
                'Profil',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Anak aktif, informasi pendamping, dan perangkat pemantauan.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: _kTextMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // Active Child Hero Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kGreen, _kHeroDeep],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _kGreen.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _kGreenSoft,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 2.5,
                            ),
                          ),
                          child: Text(
                            initial,
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: _kGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ANAK AKTIF',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.9,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                childName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              if (subtitleText.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        subtitleText,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (_activeChild != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          'Lahir ${_activeChild!.birthYear}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(alpha: 0.88),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _openDeviceAndDataSourceSheet,
                              splashColor: Colors.white.withValues(alpha: 0.14),
                              highlightColor: Colors.white.withValues(alpha: 0.08),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _watchDotColor(),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        watchSummary,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.88),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Semantics(
                          label: 'Edit profil',
                          button: true,
                          child: TextButton(
                            onPressed: _showEditProfileSheet,
                            style: TextButton.styleFrom(
                              backgroundColor: _kGreenSoft,
                              foregroundColor: _kGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              minimumSize: const Size(0, 38),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              'Edit profil',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _kGreen,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Informasi pendamping
              Text(
                'Informasi pendamping',
                style: GoogleFonts.inter(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kInfoCard,
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
                    _buildCompanionRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Nama orang tua/wali',
                      value: _userName,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        color: _kGrey.withValues(alpha: 0.7),
                      ),
                    ),
                    _buildCompanionRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email akun',
                      value: _userEmail.isNotEmpty ? _userEmail : '-',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Preferensi pendampingan
              Text(
                'Preferensi pendampingan',
                style: GoogleFonts.inter(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 10),
              _buildPreferenceCard(
                icon: Icons.watch_rounded,
                title: 'Perangkat & sumber data',
                subtitle: watchSummary,
                onTap: _openDeviceAndDataSourceSheet,
              ),
              const SizedBox(height: 10),
              _buildPreferenceCard(
                icon: Icons.menu_book_rounded,
                title: 'Jurnal harian & pengaturan privasi',
                subtitle: 'Catatan kejadian dan pengelolaan data',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JournalPrivacyScreen(
                        initialChild: _activeChild,
                        onChildrenChanged: () {
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
              const SizedBox(height: 10),
              _buildPreferenceCard(
                icon: Icons.help_outline_rounded,
                title: 'Bantuan dan dukungan',
                subtitle: 'Panduan singkat dan pertanyaan umum',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildPreferenceCard(
                icon: Icons.notifications_none_rounded,
                title: 'Pengingat jurnal & zona aman',
                badge: 'Segera hadir',
              ),
              const SizedBox(height: 24),

              // Logout button (tonal palette, no harsh red)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Semantics(
                  label: 'Keluar',
                  button: true,
                  child: ElevatedButton(
                    onPressed: _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kWarmButtonBg,
                      foregroundColor: _kText,
                      elevation: 0,
                      side: BorderSide(
                        color: _kAmber.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: _kText,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Keluar',
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _kText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
