import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import '../services/api_service.dart';
import '../services/heart_rate_service.dart';
import 'event_note_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToPanduan;
  final List<ChildModel>? initialChildren;
  final String? initialUserName;
  final String? initialErrorMessage;
  final Future<List<ChildModel>> Function()? onFetchChildren;

  const HomeScreen({
    super.key,
    this.onNavigateToPanduan,
    this.initialChildren,
    this.initialUserName,
    this.initialErrorMessage,
    this.onFetchChildren,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final HeartRateService _hrService = HeartRateService.instance;

  static const String activeChildIdKey = 'active_child_id';

  List<ChildModel> _children = [];
  ChildModel? _activeChild;
  bool _isLoadingChildren = true;
  String? _errorMessage;

  String _userName = 'Orang Tua';
  Map<String, dynamic>? _baselineData;
  List<Map<String, dynamic>> _hourlyAverages = [];

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
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
    } else if (_activeChild != null) {
      futures.add(_fetchStatsForChild(_activeChild!.id));
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
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
        _fetchStatsForChild(selectedChild.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingChildren = false;
        _errorMessage = 'Gagal memuat data anak: ${e.toString().replaceAll("Exception: ", "")}';
      });
    }
  }

  Future<void> _selectChild(ChildModel child) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(activeChildIdKey, child.id);
    _hrService.setActiveChild(child.id);

    setState(() {
      _activeChild = child;
    });

    _fetchStatsForChild(child.id);
  }

  Future<void> _fetchStatsForChild(int childId) async {
    try {
      final baselineFuture = _apiService.getBaseline(childId, days: 7);
      final historyFuture = _apiService.getHeartRateHistory(hours: 24);

      final results = await Future.wait([baselineFuture, historyFuture]);

      if (!mounted) return;

      final baseline = results[0] as Map<String, dynamic>?;
      final history = results[1] as List<Map<String, dynamic>>;

      // Process hourly averages for the last 7 hours that have data
      final hourly = _computeHourlyAverages(history);

      setState(() {
        _baselineData = baseline;
        _hourlyAverages = hourly;
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> _computeHourlyAverages(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return [];

    // Group logs by hour
    final Map<int, List<int>> hourBuckets = {};

    for (final item in history) {
      final bpm = item['bpm'];
      final recordedAtStr = item['recorded_at'];
      if (bpm == null || recordedAtStr == null) continue;

      final dt = DateTime.tryParse(recordedAtStr.toString());
      if (dt == null) continue;

      // Use epoch hour key: milliseconds / 3,600,000
      final hourKey = DateTime(dt.year, dt.month, dt.day, dt.hour).millisecondsSinceEpoch;
      hourBuckets.putIfAbsent(hourKey, () => []).add((bpm as num).toInt());
    }

    if (hourBuckets.isEmpty) return [];

    // Sort hour keys ascending
    final sortedKeys = hourBuckets.keys.toList()..sort();

    // Take the last 7 hours
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE3EEDF) : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.face_rounded,
                          color: isSelected ? const Color(0xFF1F5C4A) : Colors.grey.shade600,
                        ),
                      ),
                      title: Text(
                        child.nickname,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: const Color(0xFF1E2A24),
                        ),
                      ),
                      subtitle: Text(
                        'Tahun lahir: ${child.birthYear}',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6F7B74)),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1F5C4A))
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Nama tidak boleh kosong';
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Tahun lahir tidak boleh kosong';
                        final year = int.tryParse(val.trim());
                        if (year == null || year < 1900 || year > DateTime.now().year) {
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
                  child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF6F7B74))),
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
                          final birthYear = int.parse(birthYearController.text.trim());

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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1F5C4A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'CalmiBand',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F5C4A),
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    final activeChildName = _activeChild?.nickname ?? 'Pilih anak';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo kiri
        Flexible(
          child: _buildLogo(),
        ),
        const SizedBox(width: 8),

        // Kanan: Lonceng notifikasi & Chip anak
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Notifikasi',
              button: true,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF1E2A24),
                  size: 24,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifikasi belum tersedia'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 6),

            // Chip anak aktif + panah
            Semantics(
              label: 'Ganti Anak Aktif: $activeChildName',
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showChildSwitcherSheet,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 130),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        Icons.face_rounded,
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
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: Color(0xFF6F7B74),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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

  Widget _buildMonitoringCard() {
    final currentBpm = _hrService.currentBpm;
    final statusText = _hrService.statusText;

    String baselineText = 'Baseline belum cukup data';
    if (_baselineData != null && _baselineData!['sufficient'] == true && _baselineData!['median'] != null) {
      baselineText = 'Baseline pribadi ${_baselineData!['median']} BPM';
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
              const Icon(
                Icons.favorite_rounded,
                color: Colors.redAccent,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Angka BPM besar
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$currentBpm',
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1,
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
          const SizedBox(height: 12),

          // Baris status dari logika BLE / dummy
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hrService.sensorStatus == HrSensorStatus.disconnected && _hrService.currentMode == Mode.ble
                      ? Colors.redAccent
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
            ],
          ),
          const SizedBox(height: 14),

          // Divider halus
          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 14),

          // Baris bawah dari GET baseline
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
                  baselineText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard() {
    final p75 = (_baselineData != null && _baselineData!['sufficient'] == true)
        ? (_baselineData!['p75'] as num?)?.toDouble()
        : null;

    final hasData = _hourlyAverages.isNotEmpty;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tren detak jantung',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E2A24),
            ),
          ),
          const SizedBox(height: 16),

          // Area 7 Bar
          SizedBox(
            height: 130,
            child: hasData
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _hourlyAverages.map((item) {
                      final avg = (item['avg'] as num).toDouble();
                      final label = item['label'].toString();

                      final isAboveP75 = p75 != null && avg > p75;
                      final barColor = isAboveP75 ? const Color(0xFFE8A24F) : const Color(0xFFE3EEDF);

                      // Proportional bar height (scale 40..140 BPM to 20..100 px)
                      final heightRatio = ((avg - 40) / 100).clamp(0.15, 1.0);
                      final barHeight = heightRatio * 90;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            avg.round().toString(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6F7B74),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 24,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF6F7B74),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(7, (index) {
                            return Container(
                              width: 24,
                              height: 40 + (index % 3) * 15.0,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F4EF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFD9DED6)),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Belum ada data',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6F7B74),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 14),

          // Label kecil
          Center(
            child: Text(
              'Rata-rata per jam · bukan diagnosis',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6F7B74),
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
                    const SnackBar(content: Text('Pilih atau tambahkan anak terlebih dahulu')),
                  );
                  return;
                }
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventNoteScreen(childId: _activeChild!.id),
                  ),
                );
                if (result == true && _activeChild != null) {
                  _fetchStatsForChild(_activeChild!.id);
                }
              },
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
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

                  // Kartu Hijau PEMANTAUAN DETAK JANTUNG
                  _buildMonitoringCard(),
                  const SizedBox(height: 18),

                  // Kartu Tren detak jantung
                  _buildTrendCard(),
                  const SizedBox(height: 20),

                  // Tombol + Catatan kejadian dan teks keterangan
                  _buildEventNoteButton(),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
