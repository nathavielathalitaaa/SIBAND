import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/pair_device_screen.dart';
import '../services/heart_rate_service.dart';

/// Ambang waktu standar (detik) sebelum bacaan BPM dianggap kedaluwarsa.
const int kDefaultWatchStaleAfterSeconds = HeartRateService.staleTimeoutSeconds;

/// Fungsi bersama penentu apakah bacaan BLE lokal dari [hrService] masih segar.
/// Dipakai oleh kartu BPM Beranda dan [WatchStatusChip] agar tidak pernah bertentangan.
bool hasFreshLocalBleReadingForWatch(
  HeartRateService hrService, {
  int staleAfterSeconds = kDefaultWatchStaleAfterSeconds,
}) {
  return hrService.lastBpmReceivedAt != null &&
      hrService.currentBpm > 0 &&
      hrService.secondsSinceLastBpm <= staleAfterSeconds;
}

enum WatchChipState {
  unpaired,
  simulated,
  connecting,
  connectedFresh,
  connectedWaiting,
  disconnected,
}

class WatchStatusResolution {
  final WatchChipState state;
  final String label;
  final String semanticsLabel;
  final String sheetDescription;

  const WatchStatusResolution({
    required this.state,
    required this.label,
    required this.semanticsLabel,
    required this.sheetDescription,
  });
}

/// Menentukan keadaan jam secara berurutan (a -> f, yang pertama cocok menang).
WatchStatusResolution resolveWatchStatus(
  HeartRateService hrService, {
  int staleAfterSeconds = kDefaultWatchStaleAfterSeconds,
}) {
  final hasPairedDevice = hrService.activeDeviceId != null &&
      hrService.pairedDeviceName != null &&
      hrService.pairedDeviceName!.trim().isNotEmpty;

  // a. Belum ada jam terpasang
  if (!hasPairedDevice) {
    return const WatchStatusResolution(
      state: WatchChipState.unpaired,
      label: 'Pasang jam',
      semanticsLabel: 'Status jam: pasang jam',
      sheetDescription: 'Belum ada jam yang terpasang untuk anak ini.',
    );
  }

  // b. Mode Dummy (tidak pernah menampilkan Terhubung walau currentBleState connected)
  if (hrService.currentMode == Mode.dummy) {
    return const WatchStatusResolution(
      state: WatchChipState.simulated,
      label: 'Simulasi',
      semanticsLabel: 'Status jam: simulasi',
      sheetDescription:
          'Menampilkan data simulasi contoh, bukan bacaan langsung dari jam.',
    );
  }

  // c. Sedang menghubungkan BLE
  if (hrService.isConnectingBle) {
    return const WatchStatusResolution(
      state: WatchChipState.connecting,
      label: 'Menghubungkan…',
      semanticsLabel: 'Status jam: menghubungkan',
      sheetDescription: 'Sedang menghubungkan ke jam melalui Bluetooth.',
    );
  }

  final isBleConnected = hrService.currentMode == Mode.ble &&
      hrService.connectedDevice != null &&
      hrService.currentBleState == BluetoothConnectionState.connected;

  // d. Mode BLE, connectedDevice != null, state connected, dan bacaan segar
  if (isBleConnected &&
      hasFreshLocalBleReadingForWatch(
        hrService,
        staleAfterSeconds: staleAfterSeconds,
      )) {
    return const WatchStatusResolution(
      state: WatchChipState.connectedFresh,
      label: 'Terhubung',
      semanticsLabel: 'Status jam: terhubung',
      sheetDescription:
          'Jam terhubung dan mengirim bacaan detak jantung terbaru.',
    );
  }

  // e. Mode BLE, connected, tetapi tidak ada bacaan segar
  if (isBleConnected) {
    return const WatchStatusResolution(
      state: WatchChipState.connectedWaiting,
      label: 'Terhubung · menunggu data',
      semanticsLabel: 'Status jam: terhubung, menunggu data',
      sheetDescription:
          'Jam terhubung, sedang menunggu bacaan baru dari sensor.',
    );
  }

  // f. Selain itu (terputus)
  return const WatchStatusResolution(
    state: WatchChipState.disconnected,
    label: 'Jam terputus',
    semanticsLabel: 'Status jam: jam terputus',
    sheetDescription: 'Jam tidak terhubung ke ponsel saat ini.',
  );
}

class WatchStatusChip extends StatefulWidget {
  final HeartRateService? heartRateService;
  final int staleAfterSeconds;
  final int? activeChildId;
  final String? activeChildNickname;
  final VoidCallback? onDeviceChanged;

  const WatchStatusChip({
    super.key,
    this.heartRateService,
    this.staleAfterSeconds = kDefaultWatchStaleAfterSeconds,
    this.activeChildId,
    this.activeChildNickname,
    this.onDeviceChanged,
  });

  @override
  State<WatchStatusChip> createState() => _WatchStatusChipState();
}

class _WatchStatusChipState extends State<WatchStatusChip>
    with SingleTickerProviderStateMixin {
  static const int _maxPulseHalfCycles = 4;
  late HeartRateService _hrService;
  late final AnimationController _pulseController;
  int _completedHalfCycles = 0;

  @override
  void initState() {
    super.initState();
    _hrService = widget.heartRateService ?? HeartRateService.instance;
    _hrService.addListener(_onServiceChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener(_onPulseStatus);
  }

  void _onPulseStatus(AnimationStatus status) {
    if (!mounted) return;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final resolution = resolveWatchStatus(
      _hrService,
      staleAfterSeconds: widget.staleAfterSeconds,
    );
    if (disableAnimations || resolution.state != WatchChipState.connecting) {
      return;
    }
    if (status == AnimationStatus.completed) {
      _completedHalfCycles++;
      if (_completedHalfCycles < _maxPulseHalfCycles) {
        _pulseController.reverse();
      }
    } else if (status == AnimationStatus.dismissed) {
      _completedHalfCycles++;
      if (_completedHalfCycles < _maxPulseHalfCycles) {
        _pulseController.forward();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulseAnimation();
  }

  @override
  void didUpdateWidget(covariant WatchStatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newService = widget.heartRateService ?? HeartRateService.instance;
    if (newService != _hrService) {
      _hrService.removeListener(_onServiceChanged);
      _hrService = newService;
      _hrService.addListener(_onServiceChanged);
    }
    _syncPulseAnimation();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _syncPulseAnimation();
    setState(() {});
  }

  void _syncPulseAnimation() {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final resolution = resolveWatchStatus(
      _hrService,
      staleAfterSeconds: widget.staleAfterSeconds,
    );
    if (!disableAnimations && resolution.state == WatchChipState.connecting) {
      _completedHalfCycles = 0;
      if (!_pulseController.isAnimating) {
        _pulseController.forward(from: 0.0);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _hrService.removeListener(_onServiceChanged);
    _pulseController.removeStatusListener(_onPulseStatus);
    _pulseController.dispose();
    super.dispose();
  }

  static String? _formatLastReadingLine(HeartRateService hr) {
    if (hr.lastBpmReceivedAt == null) return null;
    final sec = hr.secondsSinceLastBpm < 0 ? 0 : hr.secondsSinceLastBpm;
    if (sec < 60) {
      return 'Data terakhir: $sec detik lalu';
    }
    return 'Data terakhir: ${sec ~/ 60} menit lalu';
  }

  void _showWatchStatusSheet(BuildContext context) {
    final resolution = resolveWatchStatus(
      _hrService,
      staleAfterSeconds: widget.staleAfterSeconds,
    );
    final hasPaired = _hrService.activeDeviceId != null &&
        _hrService.pairedDeviceName != null &&
        _hrService.pairedDeviceName!.trim().isNotEmpty;
    final deviceTitle =
        hasPaired ? _hrService.pairedDeviceName!.trim() : 'Belum ada jam';
    final lastReadingLine = _formatLastReadingLine(_hrService);
    final reconnectTarget = _hrService.connectedDevice;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9DED6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Status jam',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E2A24),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.watch_outlined,
                      size: 20,
                      color: Color(0xFF1F5C4A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        deviceTitle,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E2A24),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  resolution.sheetDescription,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF6F7B74),
                    height: 1.35,
                  ),
                ),
                if (lastReadingLine != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    lastReadingLine,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6F7B74),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (reconnectTarget != null &&
                    resolution.state == WatchChipState.disconnected) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _hrService.connectToDevice(reconnectTarget);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1F5C4A),
                        side: const BorderSide(color: Color(0xFF1F5C4A)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Sambungkan ulang',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PairDeviceScreen(
                            childId: widget.activeChildId,
                            childNickname: widget.activeChildNickname,
                          ),
                        ),
                      );
                      widget.onDeviceChanged?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F5C4A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Pasang atau ganti jam',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeadingIndicator(WatchChipState state, bool disableAnimations) {
    switch (state) {
      case WatchChipState.unpaired:
        return const Icon(
          Icons.watch_outlined,
          size: 14,
          color: Color(0xFF6F7B74),
        );
      case WatchChipState.simulated:
        return const Icon(
          Icons.insights_rounded,
          size: 13,
          color: Color(0xFF6F7B74),
        );
      case WatchChipState.connecting:
        final dot = Container(
          key: const Key('watch_chip_dot_connecting'),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFFD97706),
            shape: BoxShape.circle,
          ),
        );
        if (disableAnimations) return dot;
        return FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1.0).animate(
            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
          ),
          child: dot,
        );
      case WatchChipState.connectedFresh:
        return Container(
          key: const Key('watch_chip_dot_green'),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF1F5C4A),
            shape: BoxShape.circle,
          ),
        );
      case WatchChipState.connectedWaiting:
        return Container(
          key: const Key('watch_chip_dot_amber'),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFFD97706),
            shape: BoxShape.circle,
          ),
        );
      case WatchChipState.disconnected:
        return Container(
          key: const Key('watch_chip_dot_grey'),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF94A3B8),
            shape: BoxShape.circle,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final resolution = resolveWatchStatus(
      _hrService,
      staleAfterSeconds: widget.staleAfterSeconds,
    );
    final isSimulated = resolution.state == WatchChipState.simulated;
    final isConnectedFresh = resolution.state == WatchChipState.connectedFresh;

    final Color bgColor = isSimulated
        ? Colors.transparent
        : (isConnectedFresh
            ? const Color(0xFFE3EEDF)
            : Colors.white);
    final Color borderColor = isSimulated
        ? const Color(0xFF6F7B74)
        : (isConnectedFresh
            ? const Color(0xFF1F5C4A).withValues(alpha: 0.35)
            : const Color(0xFFD9DED6));
    final Color textColor = isConnectedFresh
        ? const Color(0xFF1F5C4A)
        : (isSimulated
            ? const Color(0xFF6F7B74)
            : const Color(0xFF1E2A24));

    return Semantics(
      label: resolution.semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('watch_status_chip'),
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showWatchStatusSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLeadingIndicator(resolution.state, disableAnimations),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      resolution.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
