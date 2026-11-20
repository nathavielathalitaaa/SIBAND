import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis_model.dart';
import '../models/child_model.dart';
import '../services/api_service.dart';
import '../services/heart_rate_service.dart';
import '../utils/event_type_helper.dart';
import '../widgets/heartbeat_pulse.dart';
import '../widgets/home_monitoring_chart_card.dart';
import '../widgets/thin_line_logo.dart';
import '../widgets/watch_status_chip.dart';
import 'event_note_screen.dart';
import 'guide_calming_screen.dart';
import 'pair_device_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToPanduan;
  final List<ChildModel>? initialChildren;
  final String? initialUserName;
  final String? initialErrorMessage;
  final Future<List<ChildModel>> Function()? onFetchChildren;
  final AnalysisModel? initialAnalysisData;
  final ApiService? apiService;
  final HeartRateService? heartRateService;
  final bool isActiveTab;

  const HomeScreen({
    super.key,
    this.onNavigateToPanduan,
    this.initialChildren,
    this.initialUserName,
    this.initialErrorMessage,
    this.onFetchChildren,
    this.initialAnalysisData,
    this.apiService,
    this.heartRateService,
    this.isActiveTab = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiService _apiService;
  late final HeartRateService _hrService;

  static const String activeChildIdKey = 'active_child_id';

  List<ChildModel> _children = [];
  ChildModel? _activeChild;
  bool _isLoadingChildren = true;
  bool _isLoadingAnalysis = false;
  bool _isRetryingAnalysis = false;
  bool _analysisLoadFailed = false;
  String? _errorMessage;

  String _userName = 'Orang Tua';
  AnalysisModel? _analysisData;
  Map<String, dynamic>? _baselineData;
  List<Map<String, dynamic>> _hourlyAverages = [];
  final Set<String> _animatedEpisodeKeys = <String>{};

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _hrService = widget.heartRateService ?? HeartRateService.instance;
    _analysisData = widget.initialAnalysisData;

    _hrService.start();
    _hrService.addListener(_onHeartRateUpdate);

    if (widget.initialErrorMessage != null) {
      _errorMessage = widget.initialErrorMessage;
      _isLoadingChildren = false;
    }

    if (widget.initialChildren != null) {
      _children = widget.initialChildren!;
      _isLoadingChildren = false;
      if (_children.isNotEmpty) {
        _activeChild = _children.first;
        _hrService.setActiveChild(_activeChild!.id);
      }
    }
    if (widget.initialUserName != null) {
      _userName = widget.initialUserName!;
    }

    if (widget.initialErrorMessage == null) {
      _initData();
    }

    // Auto-refresh stats periodically (every 30 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _activeChild != null) {
        _fetchStatsForChild(_activeChild!.id);
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialChildren != oldWidget.initialChildren &&
        widget.initialChildren != null) {
      setState(() {
        _children = widget.initialChildren!;
        _activeChild = _children.isNotEmpty ? _children.first : null;
      });
    }
    if (widget.initialAnalysisData != oldWidget.initialAnalysisData &&
        widget.initialAnalysisData != null) {
      setState(() {
        _analysisData = widget.initialAnalysisData;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _hrService.removeListener(_onHeartRateUpdate);
    _hrService.stop();
    super.dispose();
  }

  void _onHeartRateUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initData() async {
    final futures = <Future<void>>[];
    if (widget.initialUserName == null) {
      futures.add(_fetchUserProfile());
    }
    if (widget.initialChildren == null) {
      futures.add(_fetchChildren());
    } else {
      futures.add(_syncActiveChildFromPrefsAndFetchStats());
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> _syncActiveChildFromPrefsAndFetchStats() async {
    if (_children.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final savedChildId = prefs.getInt(activeChildIdKey);

    ChildModel selected = _children.first;
    if (savedChildId != null) {
      selected = _children.firstWhere(
        (c) => c.id == savedChildId,
        orElse: () => _children.first,
      );
    }
    await prefs.setInt(activeChildIdKey, selected.id);
    _hrService.setActiveChild(selected.id);

    if (mounted) {
      setState(() {
        _activeChild = selected;
      });
    }

    await _fetchStatsForChild(selected.id);
  }

  Future<void> _retryInit() async {
    setState(() {
      _errorMessage = null;
      _isLoadingChildren = true;
    });
    await _initData();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = await _apiService.getUserProfile();
      if (!mounted) return;
      if (user != null && user['name'] != null) {
        setState(() {
          _userName = user['name'].toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchChildren() async {
    setState(() {
      _isLoadingChildren = true;
      _errorMessage = null;
    });

    try {
      final List<ChildModel> list;
      if (widget.onFetchChildren != null) {
        list = await widget.onFetchChildren!();
      } else {
        list = await _apiService.getChildren();
      }
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

      setState(() {
        _children = list;
        _activeChild = selectedChild;
        _isLoadingChildren = false;
        _errorMessage = null;
      });

      if (selectedChild != null) {
        await _fetchStatsForChild(selectedChild.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingChildren = false;
        _errorMessage =
            'Gagal memuat data anak: ${e.toString().replaceAll("Exception: ", "")}';
      });
    }
  }

  Future<void> _selectChild(ChildModel child) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(activeChildIdKey, child.id);
    _hrService.setActiveChild(child.id);

    setState(() {
      _activeChild = child;
      _animatedEpisodeKeys.clear();
    });

    await _fetchStatsForChild(child.id);
  }

  Future<void> _handlePullToRefresh() async {
    if (widget.initialChildren == null) {
      await _fetchChildren();
    } else if (_activeChild != null) {
      await _fetchStatsForChild(_activeChild!.id);
    }
  }

  bool _isUnauthenticatedError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('unauthenticated') || msg.contains('401');
  }

  Future<void> _fetchStatsForChild(int childId) async {
    if (mounted) {
      setState(() {
        if (_analysisData == null) {
          _isLoadingAnalysis = true;
        }
        _isRetryingAnalysis = true;
      });
    }

    AnalysisModel? fetchedAnalysis;
    Map<String, dynamic>? fetchedBaseline;
    List<Map<String, dynamic>> fetchedHistory = [];
    bool analysisFailed = false;
    bool historySucceeded = false;

    await Future.wait([
      () async {
        try {
          fetchedAnalysis = await _apiService.getChildAnalysis(
            childId,
            timezone: 'Asia/Jakarta',
          );
        } catch (e, st) {
          debugPrint('[HomeScreen] Error fetching child analysis: $e\n$st');
          if (!_isUnauthenticatedError(e)) {
            analysisFailed = true;
          }
        }
      }(),
      () async {
        try {
          fetchedBaseline = await _apiService.getBaseline(childId, days: 7);
        } catch (e, st) {
          debugPrint('[HomeScreen] Error fetching baseline: $e\n$st');
        }
      }(),
      () async {
        try {
          fetchedHistory = await _apiService.getHeartRateHistory(hours: 24);
          historySucceeded = true;
        } catch (e, st) {
          debugPrint('[HomeScreen] Error fetching heart rate history: $e\n$st');
        }
      }(),
    ]);

    if (!mounted) return;

    final hourly =
        historySucceeded ? _computeHourlyAverages(fetchedHistory) : null;

    setState(() {
      _isLoadingAnalysis = false;
      _isRetryingAnalysis = false;
      if (fetchedAnalysis != null) {
        _analysisData = fetchedAnalysis;
        _analysisLoadFailed = false;
      } else if (analysisFailed) {
        _analysisLoadFailed = true;
      } else {
        _analysisLoadFailed = false;
      }
      if (fetchedBaseline != null) {
        _baselineData = fetchedBaseline;
      }
      if (hourly != null) {
        _hourlyAverages = hourly;
      }
    });
  }

  List<Map<String, dynamic>> _computeHourlyAverages(
    List<Map<String, dynamic>> history,
  ) {
    if (history.isEmpty) return [];

    final Map<int, List<int>> hourBuckets = {};

    for (final item in history) {
      final bpm = item['bpm'];
      final recordedAtStr = item['recorded_at'];
      if (bpm == null || recordedAtStr == null) continue;

      final dt = DateTime.tryParse(recordedAtStr.toString());
      if (dt == null) continue;

      final hourKey = DateTime(
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
      ).millisecondsSinceEpoch;
      hourBuckets.putIfAbsent(hourKey, () => []).add((bpm as num).toInt());
    }

    if (hourBuckets.isEmpty) return [];

    final sortedKeys = hourBuckets.keys.toList()..sort();
    final recentKeys = sortedKeys.length > 7
        ? sortedKeys.sublist(sortedKeys.length - 7)
        : sortedKeys;

    final List<Map<String, dynamic>> result = [];
    for (final key in recentKeys) {
      final bpms = hourBuckets[key]!;
      final avg = bpms.reduce((a, b) => a + b) / bpms.length;
      final dt = DateTime.fromMillisecondsSinceEpoch(key);
      result.add({
        'time': dt,
        'label': '${dt.hour.toString().padLeft(2, '0')}:00',
        'avg': avg,
      });
    }

    return result;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return 'Selamat Pagi';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  /// Format HH:mm dari ISO 8601 string (mempertahankan jam lokal pada offset string seperti +07:00).
  String _formatTimeWib(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    final match = RegExp(r'T(\d{2}):(\d{2})').firstMatch(iso);
    if (match != null) {
      return '${match.group(1)}:${match.group(2)}';
    }
    final dt = DateTime.tryParse(iso);
    if (dt != null) {
      final wib = dt.toUtc().add(const Duration(hours: 7));
      return '${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')}';
    }
    return iso;
  }

  /// Format durasi detik ke teks ringkas bahasa Indonesia (mis. "6 menit").
  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds detik';
    final minutes = (seconds / 60).round();
    return '$minutes menit';
  }

  /// Pemetaan status detak jantung sesuai tiga label utama yang disepakati & aturan backend.
  String _resolveHeartRateStatusLabel({
    required String? backendStatus,
    required int? bpm,
    required bool baselineSufficient,
    required double? p25,
    required double? p75,
    required int episodeMargin,
    bool preferDynamicBpmCalculation = false,
  }) {
    if (!preferDynamicBpmCalculation) {
      if (backendStatus == 'dalam_rentang' ||
          backendStatus == 'di_bawah_rentang') {
        return 'Dalam rentang biasa';
      }
      if (backendStatus == 'sedikit_di_atas') {
        return 'Sedikit di atas baseline';
      }
      if (backendStatus == 'jauh_di_atas') {
        return 'Jauh di atas baseline';
      }
    }

    if (baselineSufficient &&
        bpm != null &&
        bpm > 0 &&
        p25 != null &&
        p75 != null) {
      final threshold = p75 + episodeMargin;
      if (bpm <= p75) {
        return 'Dalam rentang biasa';
      } else if (bpm <= threshold) {
        return 'Sedikit di atas baseline';
      } else {
        return 'Jauh di atas baseline';
      }
    }

    if (!baselineSufficient) {
      return 'Baseline belum cukup data';
    }
    return 'Belum ada pembacaan';
  }

  /// Menentukan BPM efektif, teks tampilan BPM, label badge status, dan keterangan pengukuran
  /// dengan memprioritaskan sensor BLE live dan memisahkan mode simulasi dummy dari sensor aktual.
  ({
    int? effectiveBpm,
    String bpmDisplay,
    String statusLabel,
    String measurementStateLabel,
  }) _resolveCurrentMonitoringState({
    required AnalysisCurrent? analysisCurrent,
    required bool baselineSufficient,
    required double? p25,
    required double? p75,
    required int episodeMargin,
    required int staleAfterSeconds,
  }) {
    final bool isBleMode = _hrService.currentMode == Mode.ble;
    final HrSensorStatus bleStatus = _hrService.sensorStatus;
    final bool hasFreshLocalBleReading = hasFreshLocalBleReadingForWatch(
      _hrService,
      staleAfterSeconds: staleAfterSeconds,
    );

    final bool hasBackendBpm = analysisCurrent?.bpm != null;
    final bool isBackendStale = analysisCurrent != null &&
        (analysisCurrent.measurementState == 'tidak_ada_data' ||
            (analysisCurrent.ageSeconds != null &&
                analysisCurrent.ageSeconds! > staleAfterSeconds));

    // 1. Sensor BLE lokal aktif mengukur -> Prioritaskan nilai live BLE (tidak dikunci backend 30 dtk)
    if (isBleMode &&
        bleStatus == HrSensorStatus.measuring &&
        hasFreshLocalBleReading) {
      final liveBpm = _hrService.currentBpm;
      return (
        effectiveBpm: liveBpm,
        bpmDisplay: '$liveBpm',
        statusLabel: _resolveHeartRateStatusLabel(
          backendStatus: null,
          bpm: liveBpm,
          baselineSufficient: baselineSufficient,
          p25: p25,
          p75: p75,
          episodeMargin: episodeMargin,
          preferDynamicBpmCalculation: true,
        ),
        measurementStateLabel: 'Pembacaan langsung BLE',
      );
    }

    // 2. Mode BLE dalam siklus istirahat sensor
    if (isBleMode && bleStatus == HrSensorStatus.resting) {
      if (hasFreshLocalBleReading) {
        final lastBleBpm = _hrService.currentBpm;
        return (
          effectiveBpm: lastBleBpm,
          bpmDisplay: '$lastBleBpm',
          statusLabel: _resolveHeartRateStatusLabel(
            backendStatus: null,
            bpm: lastBleBpm,
            baselineSufficient: baselineSufficient,
            p25: p25,
            p75: p75,
            episodeMargin: episodeMargin,
            preferDynamicBpmCalculation: true,
          ),
          measurementStateLabel: 'Jam sedang beristirahat sebentar',
        );
      }
      if (hasBackendBpm && !isBackendStale) {
        final backendBpm = analysisCurrent!.bpm!;
        return (
          effectiveBpm: backendBpm,
          bpmDisplay: '$backendBpm',
          statusLabel: _resolveHeartRateStatusLabel(
            backendStatus: analysisCurrent.status,
            bpm: backendBpm,
            baselineSufficient: baselineSufficient,
            p25: p25,
            p75: p75,
            episodeMargin: episodeMargin,
          ),
          measurementStateLabel: _formatMeasurementStateLabel(analysisCurrent),
        );
      }
      return (
        effectiveBpm: null,
        bpmDisplay: '--',
        statusLabel: 'Data tidak terbaru',
        measurementStateLabel: 'Belum ada data baru',
      );
    }

    // 3. Mode BLE tetapi sensor terputus
    if (isBleMode && bleStatus == HrSensorStatus.disconnected) {
      if (hasBackendBpm && !isBackendStale) {
        final backendBpm = analysisCurrent!.bpm!;
        return (
          effectiveBpm: backendBpm,
          bpmDisplay: '$backendBpm',
          statusLabel: _resolveHeartRateStatusLabel(
            backendStatus: analysisCurrent.status,
            bpm: backendBpm,
            baselineSufficient: baselineSufficient,
            p25: p25,
            p75: p75,
            episodeMargin: episodeMargin,
          ),
          measurementStateLabel: 'Jam tidak terhubung · bacaan terakhir',
        );
      }
      if (hasBackendBpm && isBackendStale) {
        return (
          effectiveBpm: null,
          bpmDisplay: '--',
          statusLabel: 'Data tidak terbaru',
          measurementStateLabel: 'Jam tidak terhubung',
        );
      }
      return (
        effectiveBpm: null,
        bpmDisplay: '--',
        statusLabel: 'Jam tidak terhubung',
        measurementStateLabel: 'Menunggu bacaan pertama dari jam',
      );
    }

    // 4. Mode Dummy (bukan sensor fisik langsung)
    if (analysisCurrent != null) {
      if (hasBackendBpm) {
        if (isBackendStale) {
          return (
            effectiveBpm: null,
            bpmDisplay: '--',
            statusLabel: 'Data tidak terbaru',
            measurementStateLabel: 'Belum ada data baru',
          );
        }
        final backendBpm = analysisCurrent.bpm!;
        return (
          effectiveBpm: backendBpm,
          bpmDisplay: '$backendBpm',
          statusLabel: _resolveHeartRateStatusLabel(
            backendStatus: analysisCurrent.status,
            bpm: backendBpm,
            baselineSufficient: baselineSufficient,
            p25: p25,
            p75: p75,
            episodeMargin: episodeMargin,
          ),
          measurementStateLabel: _formatMeasurementStateLabel(analysisCurrent),
        );
      }
      // Backend merespons tanpa bacaan terkini (jangan gunakan angka dummy sebagai bacaan sensor aktual)
      return (
        effectiveBpm: null,
        bpmDisplay: '--',
        statusLabel: 'Belum ada pembacaan',
        measurementStateLabel: 'Belum ada data baru',
      );
    }

    // Fallback pratinjau simulasi contoh saat belum terhubung ke analisis backend
    return (
      effectiveBpm: null,
      bpmDisplay: '${_hrService.currentBpm}',
      statusLabel: 'Mode simulasi contoh',
      measurementStateLabel: 'Simulasi (bukan sensor aktual)',
    );
  }

  HeartbeatState _resolveHeartbeatState(String measurementStateLabel) {
    if (measurementStateLabel == 'Simulasi (bukan sensor aktual)') {
      return HeartbeatState.simulated;
    }
    if (measurementStateLabel == 'Pembacaan langsung BLE' ||
        measurementStateLabel == 'Jam sedang mengukur') {
      return HeartbeatState.measuring;
    }
    if (measurementStateLabel == 'Jam sedang beristirahat sebentar' ||
        measurementStateLabel.startsWith('Jeda istirahat sensor')) {
      return HeartbeatState.resting;
    }
    return HeartbeatState.stale;
  }

  Color _resolveStatusBadgeColor(String statusLabel) {
    switch (statusLabel) {
      case 'Dalam rentang biasa':
        return const Color(0xFF1ECE9F);
      case 'Sedikit di atas baseline':
        return const Color(0xFFF59E0B);
      case 'Jauh di atas baseline':
        return const Color(0xFFE8A24F);
      default:
        return Colors.white.withValues(alpha: 0.7);
    }
  }

  String _formatMeasurementStateLabel(AnalysisCurrent? current) {
    if (current == null) return '';
    switch (current.measurementState) {
      case 'mengukur':
        return 'Jam sedang mengukur';
      case 'istirahat_jam':
        final restMin = (current.expectedRestSeconds / 60).round();
        return 'Jeda istirahat sensor (~$restMin mnt)';
      case 'tidak_ada_data':
        return 'Belum ada data baru';
      default:
        return '';
    }
  }

  void _showChildSwitcherSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Anak',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E2A24),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_children.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Belum ada anak terdaftar',
                        style: GoogleFonts.inter(color: const Color(0xFF6F7B74)),
                      ),
                    ),
                  )
                else
                  ..._children.map((child) {
                    final isSelected = child.id == _activeChild?.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE3EEDF)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.face_rounded,
                          color: isSelected
                              ? const Color(0xFF1F5C4A)
                              : Colors.grey.shade600,
                        ),
                      ),
                      title: Text(
                        child.nickname,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: const Color(0xFF1E2A24),
                        ),
                      ),
                      subtitle: Text(
                        'Tahun lahir: ${child.birthYear}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF6F7B74),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF1F5C4A),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _selectChild(child);
                      },
                    );
                  }),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showAddChildDialog();
                  },
                  icon: const Icon(Icons.add, color: Color(0xFF1F5C4A)),
                  label: Text(
                    'Tambah Anak Baru',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F5C4A),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1F5C4A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddChildDialog() async {
    final nicknameController = TextEditingController();
    final birthYearController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Tambah Anak',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: const Color(0xFF1E2A24),
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nicknameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Panggilan',
                        hintText: 'Contoh: Bima',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nama tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: birthYearController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Tahun Lahir',
                        hintText: 'Contoh: 2018',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Tahun lahir tidak boleh kosong';
                        }
                        final year = int.tryParse(val.trim());
                        if (year == null ||
                            year < 1900 ||
                            year > DateTime.now().year) {
                          return 'Masukkan tahun yang valid';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.inter(color: const Color(0xFF6F7B74)),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isSaving = true;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(ctx);

                          final nickname = nicknameController.text.trim();
                          final birthYear = int.parse(
                            birthYearController.text.trim(),
                          );

                          final newChild = await _apiService.createChild(
                            nickname: nickname,
                            birthYear: birthYear,
                          );

                          navigator.pop();
                          if (!mounted) return;

                          if (newChild != null) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Anak berhasil ditambahkan'),
                                backgroundColor: Color(0xFF1F5C4A),
                              ),
                            );
                            await _fetchChildren();
                            if (mounted) {
                              _selectChild(newChild);
                            }
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Gagal menambahkan anak'),
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
            );
          },
        );
      },
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/home/logo.png',
      height: 32,
      errorBuilder: (context, error, stackTrace) {
        return const SibandThinLineLogo(size: 30);
      },
    );
  }

  int get _currentStaleAfterSeconds =>
      (_analysisData?.meta.parameters['stale_after_seconds'] as num?)
          ?.toInt() ??
      kDefaultWatchStaleAfterSeconds;

  Widget _buildHeader() {
    final activeChildName = _activeChild?.nickname ?? 'Pilih anak';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: _buildLogo()),
        const SizedBox(width: 6),
        Flexible(
          flex: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: WatchStatusChip(
                  heartRateService: _hrService,
                  staleAfterSeconds: _currentStaleAfterSeconds,
                  activeChildId: _activeChild?.id,
                  activeChildNickname: _activeChild?.nickname,
                  onDeviceChanged: () {
                    if (_activeChild != null) {
                      _fetchStatsForChild(_activeChild!.id);
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Semantics(
                  label: 'Ganti Anak Aktif: $activeChildName',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _showChildSwitcherSheet,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 130),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD9DED6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.face_outlined,
                            size: 16,
                            color: Color(0xFF1F5C4A),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              activeChildName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E2A24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Color(0xFF6F7B74),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    final activeChildName = _activeChild?.nickname ?? 'anak Anda';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_getGreeting()}, $_userName',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E2A24),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Yuk, lihat kondisi $activeChildName hari ini dan temukan cara terbaik untuk mendukungnya.',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6F7B74),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    return Semantics(
      label: 'Banner: Yuk Memahami Anak. Ketuk untuk membuka Panduan.',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          widget.onNavigateToPanduan?.call();
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFE3EEDF),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yuk Memahami Anak',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F5C4A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kenali pemicu dan pola perilaku anak melalui panduan interaktif kami.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF1E2A24),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1F5C4A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3. Kartu Detak Jantung Sekarang (CurrentHeartRateCard adaptation)
  Widget _buildMonitoringCard() {
    final analysis = _analysisData;
    final analysisBaseline = analysis?.baseline;
    final analysisCurrent = analysis?.current;

    final bool baselineSufficient = analysisBaseline != null
        ? analysisBaseline.sufficient
        : (_baselineData != null && _baselineData!['sufficient'] == true);

    final double? median = analysisBaseline?.median ??
        (baselineSufficient
            ? (_baselineData?['median'] as num?)?.toDouble()
            : null);
    final double? p25 = analysisBaseline?.p25 ??
        (baselineSufficient
            ? (_baselineData?['p25'] as num?)?.toDouble()
            : null);
    final double? p75 = analysisBaseline?.p75 ??
        (baselineSufficient
            ? (_baselineData?['p75'] as num?)?.toDouble()
            : null);
    final int sampleCount = analysisBaseline?.sampleCount ??
        ((_baselineData?['sample_count'] as num?)?.toInt() ?? 0);
    final int minSamples = analysisBaseline?.minSamples ?? 100;
    final int episodeMargin =
        (analysis?.meta.parameters['episode_margin_bpm'] as num?)?.toInt() ?? 10;
    final int staleAfterSeconds =
        (analysis?.meta.parameters['stale_after_seconds'] as num?)?.toInt() ??
            420;

    final resolvedState = _resolveCurrentMonitoringState(
      analysisCurrent: analysisCurrent,
      baselineSufficient: baselineSufficient,
      p25: p25,
      p75: p75,
      episodeMargin: episodeMargin,
      staleAfterSeconds: staleAfterSeconds,
    );

    final int? effectiveBpm = resolvedState.effectiveBpm;
    final String bpmDisplay = resolvedState.bpmDisplay;
    final String statusLabel = resolvedState.statusLabel;
    final String measurementStateLabel = resolvedState.measurementStateLabel;
    final Color badgeColor = _resolveStatusBadgeColor(statusLabel);

    final String statusText = _hrService.statusText;
    final HeartbeatState heartbeatState =
        _resolveHeartbeatState(measurementStateLabel);
    final DateTime? lastReadingAt =
        (_hrService.currentMode == Mode.ble &&
                _hrService.lastBpmReceivedAt != null)
            ? _hrService.lastBpmReceivedAt
            : (analysisCurrent?.recordedAt != null
                ? DateTime.tryParse(analysisCurrent!.recordedAt!)
                : _hrService.lastBpmReceivedAt);

    String baselineSummaryText = 'Baseline belum cukup data';
    String positionDescription = '';
    if (baselineSufficient && median != null && p25 != null && p75 != null) {
      baselineSummaryText = 'Baseline pribadi ${median.round()} BPM';
      if (effectiveBpm != null) {
        final diffMedian = effectiveBpm - median.round();
        final diffPrefix = diffMedian >= 0 ? '+$diffMedian' : '$diffMedian';
        if (effectiveBpm < p25) {
          positionDescription =
              '${(p25.round() - effectiveBpm)} BPM di bawah batas p25 ($diffPrefix dari median)';
        } else if (effectiveBpm <= p75) {
          positionDescription =
              'Berada di dalam rentang p25–p75 ($diffPrefix dari median)';
        } else {
          positionDescription =
              '+${(effectiveBpm - p75.round())} BPM di atas batas p75 ($diffPrefix dari median)';
        }
      }
    } else if (sampleCount > 0) {
      baselineSummaryText =
          'Baseline belum cukup data ($sampleCount/$minSamples sampel)';
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1F5C4A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F5C4A).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header teks
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'PEMANTAUAN DETAK JANTUNG',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              HeartbeatPulse(
                bpm: effectiveBpm ?? _hrService.currentBpm,
                state: heartbeatState,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Angka BPM besar + Badge status detak jantung
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                      );
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: slide,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      bpmDisplay,
                      key: ValueKey<String>(bpmDisplay),
                      style: GoogleFonts.inter(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'BPM',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.65),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Baris status koneksi sensor (BLE / dummy)
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hrService.sensorStatus ==
                              HrSensorStatus.disconnected &&
                          _hrService.currentMode == Mode.ble
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF1ECE9F),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              if (measurementStateLabel.isNotEmpty)
                Flexible(
                  child: Text(
                    measurementStateLabel,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
            ],
          ),
          if (lastReadingAt != null) ...[
            const SizedBox(height: 6),
            LastUpdatedBpmText(lastReadingAt: lastReadingAt),
          ],
          if (_hrService.needsDeviceRepair) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PairDeviceScreen(
                        childId: _activeChild?.id,
                        childNickname: _activeChild?.nickname,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.bluetooth_searching_rounded, size: 16),
                label: Text(
                  'Pasang ulang perangkat',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),

          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 14),

          // Baris ringkasan baseline
          Row(
            children: [
              Icon(
                Icons.query_stats_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  baselineSummaryText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),

          // Detail baseline p25-p75, median, jumlah sampel, dan posisi BPM terkini terhadap rentang
          if (baselineSufficient &&
              median != null &&
              p25 != null &&
              p75 != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildBaselineMetricItem(
                          label: 'Rentang p25–p75',
                          value: '${p25.round()}–${p75.round()} BPM',
                        ),
                      ),
                      Expanded(
                        child: _buildBaselineMetricItem(
                          label: 'Median',
                          value: '${median.round()} BPM',
                        ),
                      ),
                      Expanded(
                        child: _buildBaselineMetricItem(
                          label: 'Sampel baseline',
                          value: '$sampleCount sampel',
                        ),
                      ),
                    ],
                  ),
                  if (effectiveBpm != null) ...[
                    const SizedBox(height: 10),
                    _buildBaselinePositionBar(
                      currentBpm: effectiveBpm.toDouble(),
                      p25: p25,
                      median: median,
                      p75: p75,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      positionDescription,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBaselineMetricItem({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBaselinePositionBar({
    required double currentBpm,
    required double p25,
    required double median,
    required double p75,
  }) {
    final double minScale = math.min(p25 - 15, currentBpm - 5).clamp(40.0, 180.0);
    final double maxScale =
        math.max(p75 + 25, currentBpm + 5).clamp(minScale + 10.0, 200.0);
    final double span = maxScale - minScale;

    final double p25Ratio = ((p25 - minScale) / span).clamp(0.0, 1.0);
    final double p75Ratio = ((p75 - minScale) / span).clamp(0.0, 1.0);
    final double currentRatio =
        ((currentBpm - minScale) / span).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final bandLeft = p25Ratio * totalWidth;
        final bandWidth = math.max(4.0, (p75Ratio - p25Ratio) * totalWidth);
        final double dotLeft = (currentRatio * totalWidth - 6)
            .clamp(0.0, math.max(0.0, totalWidth - 12))
            .toDouble();

        return SizedBox(
          height: 14,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 6,
                width: totalWidth,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                left: bandLeft,
                width: bandWidth,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3EEDF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: dotLeft,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: currentBpm > p75
                        ? const Color(0xFFE8A24F)
                        : const Color(0xFF1ECE9F),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Ringkasan Episode Kenaikan BPM yang ringkas untuk Beranda
  Widget _buildEpisodesSummaryCard() {
    final analysis = _analysisData;
    if (analysis == null) return const SizedBox.shrink();

    final episodes = analysis.episodes;
    final baselineSufficient = analysis.baseline.sufficient;
    final visibleEpisodes =
        episodes.length > 3 ? episodes.sublist(0, 3) : episodes;
    final remainingCount = episodes.length - visibleEpisodes.length;

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Ringkasan episode kenaikan',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E2A24),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: episodes.isNotEmpty
                      ? const Color(0xFFE8A24F).withValues(alpha: 0.18)
                      : const Color(0xFFE3EEDF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${episodes.length} episode',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: episodes.isNotEmpty
                        ? const Color(0xFFB45309)
                        : const Color(0xFF1F5C4A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!baselineSufficient)
            Text(
              'Deteksi episode membutuhkan minimal ${analysis.baseline.minSamples} sampel baseline (saat ini ${analysis.baseline.sampleCount} sampel).',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF6F7B74),
                height: 1.35,
              ),
            )
          else if (episodes.isEmpty)
            Text(
              'Tidak ada episode kenaikan di atas ambang baseline pada rentang ini.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF6F7B74),
                height: 1.35,
              ),
            )
          else ...[
            ...List.generate(visibleEpisodes.length, (idx) {
              final ep = visibleEpisodes[idx];
              final startStr = _formatTimeWib(ep.start);
              final endStr = _formatTimeWib(ep.end);
              final durationStr = _formatDuration(ep.durationSeconds);
              final note = ep.note;
              final epKey = '${ep.index}_${ep.start}';
              final shouldAnimate = !_animatedEpisodeKeys.contains(epKey);

              return EpisodeEntryFadeIn(
                key: ValueKey<String>('episode_fade_$epKey'),
                episodeKey: epKey,
                staggerIndex: idx,
                animateOnMount: shouldAnimate,
                onAnimationStarted: () {
                  _animatedEpisodeKeys.add(epKey);
                },
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: idx == visibleEpisodes.length - 1 ? 0 : 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F4EF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E0D5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$startStr–$endStr ($durationStr)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E2A24),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8A24F)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Puncak ${ep.peakBpm} BPM (+${ep.deltaFromMedian.round()})',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    if (note != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            getEventTypeIcon(note.type),
                            size: 14,
                            color: const Color(0xFF1F5C4A),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${getEventTypeName(note.type)}${note.textPreview.isNotEmpty ? ' · ${note.textPreview}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E2A24),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Belum dicatat',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _activeChild == null
                                ? null
                                : () async {
                                    final childId = _activeChild!.id;
                                    final parsedStart =
                                        DateTime.tryParse(ep.start)?.toLocal();
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EventNoteScreen(
                                          childId: childId,
                                          initialOccurredAt: parsedStart,
                                        ),
                                      ),
                                    );
                                    if (result == true &&
                                        _activeChild != null) {
                                      _fetchStatsForChild(_activeChild!.id);
                                    }
                                  },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF1F5C4A),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Tambah catatan',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                ),
              );
            }),
            if (remainingCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '+$remainingCount episode lainnya tercatat hari ini',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6F7B74),
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GuideCalmingScreen(
                      childId: _activeChild?.id,
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1F5C4A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Lihat panduan menenangkan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventNoteButton() {
    return Column(
      children: [
        Semantics(
          label: '+ Catatan kejadian',
          button: true,
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (_activeChild == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Pilih atau tambahkan anak terlebih dahulu',
                      ),
                    ),
                  );
                  return;
                }
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EventNoteScreen(childId: _activeChild!.id),
                  ),
                );
                if (result == true && _activeChild != null) {
                  _fetchStatsForChild(_activeChild!.id);
                }
              },
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                '+ Catatan kejadian',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F5C4A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Perubahan detak jantung bukan bukti stres.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6F7B74),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChildrenView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE3EEDF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.child_care_rounded,
                size: 54,
                color: Color(0xFF1F5C4A),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tambah anak',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E2A24),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Silakan daftarkan anak Anda untuk mulai memantau detak jantung dan mencatat kejadian.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF6F7B74),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showAddChildDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Tambah Anak',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F5C4A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 54,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Terjadi kesalahan',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E2A24),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Gagal memuat data anak. Silakan coba lagi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF6F7B74),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _retryInit,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  'Coba lagi',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F5C4A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingChildren && _errorMessage == null && _children.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1F5C4A)),
      );
    }

    if (_errorMessage != null && _children.isEmpty) {
      return SafeArea(
        child: SizedBox.expand(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: _buildHeader(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildErrorView(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_children.isEmpty) {
      return SafeArea(
        child: SizedBox.expand(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: _buildHeader(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildEmptyChildrenView(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: SizedBox.expand(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth * 0.06;

            return Stack(
              children: [
                Positioned.fill(
                  child: RefreshIndicator(
                    color: const Color(0xFF1F5C4A),
                    onRefresh: _handlePullToRefresh,
                    child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      88,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        _buildHeader(),
                        const SizedBox(height: 20),

                        // Sapaan
                        _buildGreeting(),
                        const SizedBox(height: 18),

                        // Banner Yuk Memahami Anak
                        _buildBanner(),
                        const SizedBox(height: 18),

                        // Kartu Hijau PEMANTAUAN DETAK JANTUNG (Kartu Detak Jantung Sekarang)
                        _buildMonitoringCard(),
                        const SizedBox(height: 18),

                        // Grafik Pemantauan Time-Series BPM
                        HomeMonitoringChartCard(
                          analysisData: _analysisData,
                          baselineData: _baselineData,
                          hourlyAverages: _hourlyAverages,
                          isLoadingAnalysis: _isLoadingAnalysis,
                        ),
                        if (_analysisLoadFailed) ...[
                          const SizedBox(height: 8),
                          _buildAnalysisErrorNotice(),
                        ],
                        const SizedBox(height: 18),

                        // Ringkasan Episode Kenaikan BPM yang ringkas (jika data analisis tersedia)
                        if (_analysisData != null) ...[
                          _buildEpisodesSummaryCard(),
                          const SizedBox(height: 18),
                        ] else
                          const SizedBox(height: 2),

                        // Tombol + Catatan kejadian dan teks keterangan
                        _buildEventNoteButton(),
                        const SizedBox(height: 16),
                      ],
                    ),
                    ),
                  ),
                ),
                if (widget.isActiveTab && _activeChild != null)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                      key: const Key('fab_catat_kejadian'),
                      heroTag: null,
                      backgroundColor: const Color(0xFF1F5C4A),
                      foregroundColor: Colors.white,
                      elevation: 3,
                      onPressed: () async {
                        final child = _activeChild;
                        if (child == null) return;
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EventNoteScreen(childId: child.id),
                          ),
                        );
                        if (result == true && _activeChild != null) {
                          _fetchStatsForChild(_activeChild!.id);
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(
                        'Catat kejadian',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnalysisErrorNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data analisis belum bisa dimuat',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          TextButton(
            onPressed: (_activeChild == null || _isRetryingAnalysis)
                ? null
                : () => _fetchStatsForChild(_activeChild!.id),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1F5C4A),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Coba lagi',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget kecil tersendiri untuk menampilkan waktu pembaruan bacaan terakhir
/// ("Diperbarui baru saja", "Diperbarui N dtk lalu", "Diperbarui N mnt lalu")
/// yang diperbarui tiap 10 detik tanpa membangun ulang seluruh Beranda.
class LastUpdatedBpmText extends StatefulWidget {
  final DateTime lastReadingAt;

  const LastUpdatedBpmText({
    super.key,
    required this.lastReadingAt,
  });

  static String formatLabel(DateTime lastReadingAt, {DateTime? now}) {
    final diffSec = math.max(
      0,
      (now ?? DateTime.now()).difference(lastReadingAt).inSeconds,
    );
    if (diffSec < 10) {
      return 'Diperbarui baru saja';
    }
    if (diffSec < 60) {
      return 'Diperbarui $diffSec dtk lalu';
    }
    return 'Diperbarui ${diffSec ~/ 60} mnt lalu';
  }

  @override
  State<LastUpdatedBpmText> createState() => _LastUpdatedBpmTextState();
}

class _LastUpdatedBpmTextState extends State<LastUpdatedBpmText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      LastUpdatedBpmText.formatLabel(widget.lastReadingAt),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.72),
      ),
    );
  }
}

/// Pembungkus fade-in berurutan (jeda 60 ms per kartu) untuk kartu episode
/// yang hanya memutar animasi saat pertama kali kartu tersebut tampil.
class EpisodeEntryFadeIn extends StatefulWidget {
  final String episodeKey;
  final int staggerIndex;
  final bool animateOnMount;
  final VoidCallback onAnimationStarted;
  final Widget child;

  @visibleForTesting
  static int animationTriggerCount = 0;

  const EpisodeEntryFadeIn({
    super.key,
    required this.episodeKey,
    required this.staggerIndex,
    required this.animateOnMount,
    required this.onAnimationStarted,
    required this.child,
  });

  @override
  State<EpisodeEntryFadeIn> createState() => _EpisodeEntryFadeInState();
}

class _EpisodeEntryFadeInState extends State<EpisodeEntryFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final delayMs = widget.staggerIndex * 60;
    final totalMs = 240 + delayMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    final beginFraction = totalMs > 0 ? delayMs / totalMs : 0.0;
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Interval(beginFraction, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.animateOnMount) {
      widget.onAnimationStarted();
      if (disableAnimations) {
        _controller.value = 1.0;
      } else {
        EpisodeEntryFadeIn.animationTriggerCount++;
        _controller.forward(from: 0.0);
      }
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}
