import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/event_type_helper.dart';
import '../utils/share_helper.dart';
import 'onboarding_screen.dart';

class RecapScreen extends StatefulWidget {
  final List<ChildModel>? initialChildren;
  final Map<String, dynamic>? initialRecapData;
  final List<Map<String, dynamic>>? initialShareLinks;
  final int? activeChildId;

  const RecapScreen({
    super.key,
    this.initialChildren,
    this.initialRecapData,
    this.initialShareLinks,
    this.activeChildId,
  });

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  String? _errorMessage;

  List<ChildModel> _children = [];
  ChildModel? _activeChild;

  // Mode: false = 7 hari terakhir, true = Bulanan
  bool _isMonthlyMode = false;
  late DateTime _selectedMonth;

  // Data recap yang sudah diolah
  Map<String, dynamic>? _recapData;
  List<Map<String, dynamic>> _shareLinks = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);

    if (widget.initialChildren != null) {
      _children = widget.initialChildren!;
      if (_children.isNotEmpty) {
        if (widget.activeChildId != null) {
          _activeChild = _children.firstWhere(
            (c) => c.id == widget.activeChildId,
            orElse: () => _children.first,
          );
        } else {
          _activeChild = _children.first;
        }
      }
    }

    if (widget.initialRecapData != null) {
      _recapData = widget.initialRecapData;
      _shareLinks = widget.initialShareLinks ?? [];
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(covariant RecapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRecapData != oldWidget.initialRecapData) {
      setState(() {
        _recapData = widget.initialRecapData;
        _isLoading = false;
      });
    }
    if (widget.initialShareLinks != oldWidget.initialShareLinks) {
      setState(() {
        _shareLinks = widget.initialShareLinks ?? [];
      });
    }
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
      if (_children.isEmpty) {
        final list = await _apiService.getChildren();
        if (!mounted) return;
        _children = list;
        if (_children.isNotEmpty) {
          _activeChild = _children.first;
        }
      }

      if (_activeChild == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      await _fetchRecapAndShares();
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('Unauthenticated')) {
        await _handleAuthError();
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat rekap: ${e.toString().replaceAll("Exception: ", "")}';
      });
    }
  }

  String _formatMonthYear(DateTime dt) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _monthQueryString(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchRecapAndShares() async {
    if (_activeChild == null) return;
    final childId = _activeChild!.id;

    try {
      final shareLinks = await _apiService.getShareLinks(childId);

      if (!_isMonthlyMode) {
        // Mode 7 hari terakhir berakhir hari ini
        final now = DateTime.now();
        final currentMonthStr = _monthQueryString(now);
        final currentRecap = await _apiService.getRecap(childId, month: currentMonthStr);

        final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        Map<String, dynamic>? prevRecap;

        if (startDate.month != now.month) {
          final prevMonthStr = _monthQueryString(startDate);
          prevRecap = await _apiService.getRecap(childId, month: prevMonthStr);
        }

        final combined = _combineSevenDaysRecap(
          currentRecap: currentRecap,
          prevRecap: prevRecap,
          startDate: startDate,
          endDate: DateTime(now.year, now.month, now.day),
        );

        if (!mounted) return;
        setState(() {
          _recapData = combined;
          _shareLinks = shareLinks;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        // Mode bulanan
        final monthStr = _monthQueryString(_selectedMonth);
        final recap = await _apiService.getRecap(childId, month: monthStr);

        if (!mounted) return;
        setState(() {
          _recapData = recap;
          _shareLinks = shareLinks;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('Unauthenticated')) {
        await _handleAuthError();
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat rekap: ${e.toString().replaceAll("Exception: ", "")}';
      });
    }
  }

  /// Menggabungkan data rekap 7 hari terakhir dari rekap bulan ini dan bulan sebelumnya bila ada
  Map<String, dynamic> _combineSevenDaysRecap({
    Map<String, dynamic>? currentRecap,
    Map<String, dynamic>? prevRecap,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final startStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    final List<dynamic> allDaySummaries = [];
    final List<dynamic> allNotes = [];

    if (prevRecap != null) {
      if (prevRecap['ringkasan_per_hari'] is List) {
        allDaySummaries.addAll(prevRecap['ringkasan_per_hari'] as List);
      }
      final prevNotes = prevRecap['catatan_kejadian']?['daftar'] ?? prevRecap['daftar_catatan'];
      if (prevNotes is List) {
        allNotes.addAll(prevNotes);
      }
    }

    if (currentRecap != null) {
      if (currentRecap['ringkasan_per_hari'] is List) {
        allDaySummaries.addAll(currentRecap['ringkasan_per_hari'] as List);
      }
      final curNotes = currentRecap['catatan_kejadian']?['daftar'] ?? currentRecap['daftar_catatan'];
      if (curNotes is List) {
        allNotes.addAll(curNotes);
      }
    }

    // Filter ringkasan_per_hari yang berada di rentang 7 hari
    final filteredDays = allDaySummaries.where((item) {
      if (item is! Map) return false;
      final tgl = item['tanggal']?.toString();
      if (tgl == null) return false;
      return tgl.compareTo(startStr) >= 0 && tgl.compareTo(endStr) <= 0;
    }).toList();

    // Filter event notes yang berada di rentang 7 hari
    final filteredNotes = allNotes.where((item) {
      if (item is! Map) return false;
      final waktuStr = item['waktu']?.toString();
      if (waktuStr == null) return false;
      try {
        final dt = DateTime.parse(waktuStr);
        final dtDate = DateTime(dt.year, dt.month, dt.day);
        return !dtDate.isBefore(startDate) && !dtDate.isAfter(endDate);
      } catch (_) {
        return false;
      }
    }).toList();

    // Hitung total di sisi klien
    int clientTotalSamples = 0;
    int clientDaysWithData = 0;
    int clientTotalAboveP75 = 0;

    final baseline = currentRecap?['baseline'] ?? prevRecap?['baseline'] ?? {};
    final bool isBaselineSufficient = baseline['sufficient'] == true && baseline['p75'] != null;

    for (final day in filteredDays) {
      if (day is Map) {
        final samples = (day['jumlah_sampel'] as num?)?.toInt() ?? 0;
        clientTotalSamples += samples;
        if (samples > 0) {
          clientDaysWithData++;
        }
        final above = (day['bacaan_di_atas_p75'] as num?)?.toInt();
        if (isBaselineSufficient && above != null) {
          clientTotalAboveP75 += above;
        }
      }
    }

    return {
      'periode': '7_hari',
      'jumlah_sampel': clientTotalSamples,
      'jumlah_hari': clientDaysWithData,
      'ringkasan_per_hari': filteredDays,
      'baseline': baseline,
      'bacaan_di_atas_p75': isBaselineSufficient ? clientTotalAboveP75 : null,
      'catatan_kejadian': {
        'daftar': filteredNotes,
      },
    };
  }

  void _onPrevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _fetchRecapAndShares();
  }

  void _onNextMonth() {
    final now = DateTime.now();
    final isCurrent = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    if (isCurrent) return; // Tidak boleh melewati bulan ini

    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _fetchRecapAndShares();
  }

  String _getDayInitial(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'S';
      case DateTime.tuesday:
        return 'S';
      case DateTime.wednesday:
        return 'R';
      case DateTime.thursday:
        return 'K';
      case DateTime.friday:
        return 'J';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'M';
      default:
        return '';
    }
  }

  Future<void> _openCreateShareSheet() async {
    if (_activeChild == null) return;
    int selectedDays = 7;
    String? createdToken;
    String? createdUrl;
    bool isSubmitting = false;
    String? sheetError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Buat Tautan Berbagi',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E2A24),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pilih masa berlaku tautan rekap untuk terapis anak.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6F7B74),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (createdUrl == null) ...[
                    // Pilihan Masa Berlaku (1, 7, 14, 30 hari)
                    Text(
                      'Masa berlaku:',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E2A24),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: [1, 7, 14, 30].map((days) {
                        final isSel = selectedDays == days;
                        return ChoiceChip(
                          label: Text('$days Hari'),
                          selected: isSel,
                          selectedColor: const Color(0xFFE3EEDF),
                          backgroundColor: Colors.white,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                            color: isSel ? const Color(0xFF1F5C4A) : const Color(0xFF6F7B74),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSel ? const Color(0xFF1F5C4A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() => selectedDays = days);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    if (sheetError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        sheetError!,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setSheetState(() {
                                  isSubmitting = true;
                                  sheetError = null;
                                });
                                try {
                                  final res = await _apiService.createShareLink(
                                    _activeChild!.id,
                                    days: selectedDays,
                                  );
                                  if (res != null && res['token'] != null) {
                                    final token = res['token'].toString();
                                    final url = await shareUrl(token);
                                    setSheetState(() {
                                      createdToken = token;
                                      createdUrl = url;
                                      isSubmitting = false;
                                    });
                                  } else {
                                    setSheetState(() {
                                      sheetError = 'Gagal membuat tautan';
                                      isSubmitting = false;
                                    });
                                  }
                                } catch (e) {
                                  setSheetState(() {
                                    sheetError = 'Terjadi kesalahan: $e';
                                    isSubmitting = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F5C4A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Buat Tautan Aman',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    // Tampilan respons Token Asli Hanya Sekali
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tautan ini hanya ditampilkan sekali. Simpan sekarang.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: SelectableText(
                        createdUrl!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E2A24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: createdUrl!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tautan berhasil disalin ke clipboard'),
                              backgroundColor: Color(0xFF1F5C4A),
                            ),
                          );
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                        label: Text(
                          'Salin Tautan',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F5C4A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );

    // Refresh daftar tautan setelah bottom sheet ditutup bila token dibuat
    if (createdToken != null && _activeChild != null) {
      try {
        final links = await _apiService.getShareLinks(_activeChild!.id);
        if (mounted) {
          setState(() {
            _shareLinks = links;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _confirmRevokeLink(Map<String, dynamic> link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Cabut tautan berbagi?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          content: Text(
            'Terapis tidak akan bisa mengakses rekap melalui tautan ini lagi.',
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6F7B74)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(
                'Batal',
                style: GoogleFonts.inter(color: const Color(0xFF6F7B74), fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Cabut',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final linkId = link['id'] as int;
      try {
        await _apiService.deleteShareLink(linkId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tautan berbagi berhasil dicabut'),
            backgroundColor: Color(0xFF1F5C4A),
          ),
        );
        if (_activeChild != null) {
          final updatedLinks = await _apiService.getShareLinks(_activeChild!.id);
          if (mounted) {
            setState(() {
              _shareLinks = updatedLinks;
            });
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencabut tautan: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _formatDateTimeString(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year, $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1F5C4A)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                'Terjadi kesalahan',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6F7B74)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                label: Text(
                  'Coba lagi',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F5C4A)),
              ),
            ],
          ),
        ),
      );
    }

    if (_activeChild == null) {
      return Center(
        child: Text(
          'Belum ada data anak aktif',
          style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF6F7B74)),
        ),
      );
    }

    return Material(
      color: const Color(0xFFF6F4EF),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalPadding = width * 0.06;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildModeSelector(),
                  const SizedBox(height: 18),
                  if (_isMonthlyMode) ...[
                    _buildMonthNavigator(),
                    const SizedBox(height: 16),
                  ],
                  _buildMonitoringSummaryCard(),
                  const SizedBox(height: 16),
                  _buildHeartRateChartCard(),
                  const SizedBox(height: 16),
                  _buildRecentEventNotesCard(),
                  const SizedBox(height: 16),
                  _buildShareRecapCard(),
                  const SizedBox(height: 16),
                  _buildShareLinksListCard(),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'Data anak bersifat pribadi. Bagikan seperlunya.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riwayat & Rekap',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E2A24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pahami pola dari waktu ke waktu',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF6F7B74),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEAE4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Mode 7 hari terakhir',
              selected: !_isMonthlyMode,
              button: true,
              child: InkWell(
                onTap: () {
                  if (_isMonthlyMode) {
                    setState(() {
                      _isMonthlyMode = false;
                    });
                    _fetchRecapAndShares();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_isMonthlyMode ? const Color(0xFF1F5C4A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '7 hari terakhir',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !_isMonthlyMode ? Colors.white : const Color(0xFF6F7B74),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              label: 'Mode Bulanan',
              selected: _isMonthlyMode,
              button: true,
              child: InkWell(
                onTap: () {
                  if (!_isMonthlyMode) {
                    setState(() {
                      _isMonthlyMode = true;
                    });
                    _fetchRecapAndShares();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _isMonthlyMode ? const Color(0xFF1F5C4A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Bulanan ->',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isMonthlyMode ? Colors.white : const Color(0xFF6F7B74),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    final now = DateTime.now();
    final isCurrent = _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _onPrevMonth,
            icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1E2A24)),
            tooltip: 'Bulan sebelumnya',
          ),
          Text(
            _formatMonthYear(_selectedMonth),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E2A24),
            ),
          ),
          IconButton(
            onPressed: isCurrent ? null : _onNextMonth,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: isCurrent ? const Color(0xFFCBD5E1) : const Color(0xFF1E2A24),
            ),
            tooltip: 'Bulan berikutnya',
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringSummaryCard() {
    final sampleCount = (_recapData?['jumlah_sampel'] as num?)?.toInt() ?? 0;
    final dayCount = (_recapData?['jumlah_hari'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            'Ringkasan pemantauan',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E2A24),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data tercatat',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6F7B74),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$sampleCount',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F5C4A),
                      ),
                    ),
                    Text(
                      'bacaan',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1F5C4A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 48, color: const Color(0xFFE2E8F0)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hari tersinkron',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6F7B74),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dayCount',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F5C4A),
                      ),
                    ),
                    Text(
                      'hari',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1F5C4A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateChartCard() {
    final rawRingkasan = _recapData?['ringkasan_per_hari'] as List?;
    final baseline = _recapData?['baseline'];
    final bool isBaselineSufficient = baseline is Map && baseline['sufficient'] == true && baseline['p75'] != null;

    final now = DateTime.now();
    // 7 hari terakhir berakhir hari ini (today - 6 to today)
    final List<DateTime> sevenDays = List.generate(7, (i) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
    });

    final Map<String, Map> mapByDate = {};
    if (rawRingkasan != null) {
      for (final day in rawRingkasan) {
        if (day is Map) {
          final tgl = day['tanggal']?.toString();
          if (tgl != null) {
            mapByDate[tgl] = day;
          }
        }
      }
    }

    // Hitung min dan max rata-rata BPM untuk skala
    double minAvg = 200;
    double maxAvg = 40;
    bool hasAnyData = false;

    for (final dt in sevenDays) {
      final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final dayData = mapByDate[dateStr];
      final avg = (dayData?['rata_rata'] as num?)?.toDouble();
      if (avg != null && avg > 0) {
        hasAnyData = true;
        if (avg < minAvg) minAvg = avg;
        if (avg > maxAvg) maxAvg = avg;
      }
    }

    if (!hasAnyData) {
      minAvg = 60;
      maxAvg = 100;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            'Detak jantung (BPM)',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E2A24),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: sevenDays.map((dt) {
                final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                final dayData = mapByDate[dateStr];
                final avg = (dayData?['rata_rata'] as num?)?.toDouble();
                final aboveP75 = (dayData?['bacaan_di_atas_p75'] as num?)?.toInt() ?? 0;

                // Bar oranye bila bacaan_di_atas_p75 > 0 (HANYA jika baseline.sufficient true), selain itu hijau muda
                final bool isOrange = isBaselineSufficient && aboveP75 > 0;
                final Color barColor = isOrange ? const Color(0xFFE8A24F) : const Color(0xFFE3EEDF);

                double barHeight = 8.0;
                if (avg != null && avg > 0) {
                  final range = (maxAvg - minAvg).abs();
                  if (range < 5) {
                    barHeight = 40.0;
                  } else {
                    final normalized = (avg - minAvg) / range;
                    barHeight = 20.0 + (normalized * 45.0);
                  }
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (avg != null && avg > 0)
                      Text(
                        avg.round().toString(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6F7B74),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    const SizedBox(height: 4),
                    Container(
                      width: 22,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: avg != null && avg > 0 ? barColor : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getDayInitial(dt.weekday),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E2A24),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Rata-rata harian · bukan diagnosis',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEventNotesCard() {
    final rawNotes = (_recapData?['catatan_kejadian']?['daftar'] ?? _recapData?['daftar_catatan']) as List?;
    final List<Map<String, dynamic>> notes = [];

    if (rawNotes != null) {
      for (final n in rawNotes) {
        if (n is Map) {
          notes.add(n.cast<String, dynamic>());
        }
      }
    }

    // Urutkan catatan dari yang paling baru
    notes.sort((a, b) {
      final aTime = a['waktu']?.toString() ?? '';
      final bTime = b['waktu']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });

    final recentNotes = notes.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            'Catatan kejadian terbaru',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E2A24),
            ),
          ),
          const SizedBox(height: 14),
          if (recentNotes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada catatan kejadian',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6F7B74),
                ),
              ),
            )
          else
            ...List.generate(recentNotes.length, (idx) {
              final note = recentNotes[idx];
              final rawType = note['tipe']?.toString() ?? 'lainnya';
              final typeName = getEventTypeName(rawType);
              final timeStr = note['waktu']?.toString();
              String timeFormatted = '--:--';
              if (timeStr != null) {
                try {
                  final dt = DateTime.parse(timeStr).toLocal();
                  final h = dt.hour.toString().padLeft(2, '0');
                  final m = dt.minute.toString().padLeft(2, '0');
                  timeFormatted = '$h:$m';
                } catch (_) {}
              }

              final content = note['catatan']?.toString();
              final hasContent = content != null && content.trim().isNotEmpty;
              final contentText = hasContent ? content.trim() : 'Tanpa catatan tambahan';

              return Padding(
                padding: EdgeInsets.only(bottom: idx == recentNotes.length - 1 ? 0 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$timeFormatted · $typeName',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E2A24),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contentText,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6F7B74),
                        height: 1.35,
                      ),
                    ),
                    if (idx < recentNotes.length - 1)
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildShareRecapCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE3EEDF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.share_outlined, color: Color(0xFF1F5C4A), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bagikan rekap ke terapis',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F5C4A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tautan baca-saja, kedaluwarsa dan dapat dicabut.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF1E2A24),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: Semantics(
              label: 'Buat tautan aman',
              button: true,
              child: ElevatedButton.icon(
                onPressed: _openCreateShareSheet,
                icon: const Icon(Icons.add_link_rounded, color: Colors.white, size: 18),
                label: Text(
                  'Buat tautan aman',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F5C4A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareLinksListCard() {
    if (_shareLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            'Tautan Berbagi Aktif',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E2A24),
            ),
          ),
          const SizedBox(height: 12),
          ..._shareLinks.map((link) {
            final status = link['status']?.toString() ?? 'active';
            final expiresAt = link['expires_at']?.toString();
            final lastAccessedAt = link['last_accessed_at']?.toString();
            final isRevoked = link['revoked_at'] != null || status == 'revoked';
            final isActive = status == 'active' && !isRevoked;

            Color statusColor = const Color(0xFF1F5C4A);
            String statusLabel = 'Aktif';
            if (isRevoked) {
              statusColor = Colors.redAccent;
              statusLabel = 'Dicabut';
            } else if (status == 'expired') {
              statusColor = const Color(0xFFE8A24F);
              statusLabel = 'Kedaluwarsa';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Kedaluwarsa: ${_formatDateTimeString(expiresAt)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF6F7B74),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastAccessedAt != null
                              ? 'Terakhir diakses: ${_formatDateTimeString(lastAccessedAt)}'
                              : 'Belum pernah diakses',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Semantics(
                      label: 'Cabut tautan',
                      button: true,
                      child: TextButton(
                        onPressed: () => _confirmRevokeLink(link),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          'Cabut',
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
          }),
        ],
      ),
    );
  }
}
