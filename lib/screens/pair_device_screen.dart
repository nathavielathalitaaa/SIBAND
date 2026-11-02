import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/child_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/ble_service.dart';
import '../services/heart_rate_service.dart';
import 'onboarding_screen.dart';

class DiscoveredWatch {
  final String name;
  final String mac;
  final BluetoothDevice? bluetoothDevice;

  const DiscoveredWatch({
    required this.name,
    required this.mac,
    this.bluetoothDevice,
  });
}

class PairDeviceScreen extends StatefulWidget {
  final int? childId;
  final String? childNickname;
  final List<ChildModel>? initialChildren;
  final ApiService? apiService;
  final AuthService? authService;
  final BleService? bleService;
  final List<DiscoveredWatch>? initialDevices;
  final bool? isAndroidOverride;

  const PairDeviceScreen({
    super.key,
    this.childId,
    this.childNickname,
    this.initialChildren,
    this.apiService,
    this.authService,
    this.bleService,
    this.initialDevices,
    this.isAndroidOverride,
  });

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  late final ApiService _apiService;
  late final AuthService _authService;
  late final BleService _bleService;

  List<DiscoveredWatch> _devices = [];
  DiscoveredWatch? _selectedWatch;
  bool _isLoadingDevices = true;
  String? _devicesErrorMessage;
  bool _permissionDenied = false;

  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
  bool _isLoadingChildren = false;

  bool _isPairing = false;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _authService = widget.authService ?? AuthService();
    _bleService = widget.bleService ?? BleService();

    _setupChildren();
    _loadDevices();
  }

  bool _isAndroidPlatform() {
    if (widget.isAndroidOverride != null) {
      return widget.isAndroidOverride!;
    }
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setupChildren() async {
    if (widget.childId != null && widget.childNickname != null) {
      final child = ChildModel(
        id: widget.childId!,
        userId: 0,
        nickname: widget.childNickname!,
        birthYear: 2018,
      );
      setState(() {
        _children = [child];
        _selectedChild = child;
      });
      return;
    }

    if (widget.initialChildren != null && widget.initialChildren!.isNotEmpty) {
      _children = widget.initialChildren!;
      final activeId = HeartRateService.instance.activeChildId;
      _selectedChild = _children.firstWhere(
        (c) => c.id == activeId,
        orElse: () => _children.first,
      );
      setState(() {});
      return;
    }

    setState(() {
      _isLoadingChildren = true;
    });

    try {
      final list = await _apiService.getChildren();
      if (!mounted) return;
      setState(() {
        _children = list;
        if (list.isNotEmpty) {
          final activeId = HeartRateService.instance.activeChildId;
          _selectedChild = list.firstWhere(
            (c) => c.id == activeId,
            orElse: () => list.first,
          );
        }
        _isLoadingChildren = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingChildren = false;
      });
    }
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoadingDevices = true;
      _devicesErrorMessage = null;
      _permissionDenied = false;
    });

    if (widget.initialDevices != null) {
      setState(() {
        _devices = widget.initialDevices!;
        if (_devices.isNotEmpty) {
          _selectedWatch = _devices.first;
        } else {
          _selectedWatch = null;
        }
        _isLoadingDevices = false;
      });
      return;
    }

    final isAndroid = _isAndroidPlatform();
    if (!isAndroid) {
      // Non-Android platform: mode contoh
      final exampleDevices = [
        const DiscoveredWatch(
          name: 'Infinix XWatch H4 (contoh)',
          mac: 'AA:BB:CC:DD:EE:FF',
        ),
      ];
      setState(() {
        _devices = exampleDevices;
        _selectedWatch = exampleDevices.first;
        _isLoadingDevices = false;
      });
      return;
    }

    // Android platform
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final allGranted = statuses.values.every((s) => s.isGranted);
      if (!allGranted) {
        setState(() {
          _permissionDenied = true;
          _isLoadingDevices = false;
        });
        return;
      }

      final bonded = await _bleService.getBondedDevices();
      final discovered = bonded.map((d) {
        final name = d.platformName.isNotEmpty ? d.platformName : 'Perangkat Tanpa Nama';
        return DiscoveredWatch(
          name: name,
          mac: d.remoteId.str,
          bluetoothDevice: d,
        );
      }).toList();

      setState(() {
        _devices = discovered;
        if (discovered.isNotEmpty) {
          _selectedWatch = discovered.first;
        } else {
          _selectedWatch = null;
        }
        _isLoadingDevices = false;
      });
    } catch (e) {
      setState(() {
        _devicesErrorMessage = 'Gagal memuat daftar jam: $e';
        _isLoadingDevices = false;
      });
    }
  }

  String _maskMac(String mac) {
    final parts = mac.split(':');
    if (parts.length >= 6) {
      return '${parts[0]}:${parts[1]}:••:••:${parts[parts.length - 2]}:${parts[parts.length - 1]}';
    }
    final dashParts = mac.split('-');
    if (dashParts.length >= 6) {
      return '${dashParts[0]}:${dashParts[1]}:••:••:${dashParts[dashParts.length - 2]}:${dashParts[dashParts.length - 1]}';
    }
    if (mac.length > 8) {
      return '${mac.substring(0, 4)}:••:••:${mac.substring(mac.length - 4)}';
    }
    return mac;
  }

  Future<void> _handlePair() async {
    if (_selectedWatch == null || _selectedChild == null || _isPairing) return;

    setState(() {
      _isPairing = true;
    });

    try {
      final res = await _apiService.pairDevice(
        mac: _selectedWatch!.mac,
        name: _selectedWatch!.name,
        childId: _selectedChild!.id,
      );

      if (!mounted) return;

      if (res['statusCode'] == 401 || res['message'] == 'Unauthenticated') {
        await _authService.logout();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          (route) => false,
        );
        return;
      }

      if (res['success'] == true) {
        final deviceData = res['data'] ?? res['device'] ?? {};
        final int deviceId = deviceData['id'] is int ? deviceData['id'] as int : int.tryParse(deviceData['id']?.toString() ?? '') ?? 1;
        final String deviceName = deviceData['name']?.toString() ?? _selectedWatch!.name;

        // Simpan device_id dan nama jam di state aplikasi
        await HeartRateService.instance.setPairedDevice(
          deviceId: deviceId,
          deviceName: deviceName,
        );
        HeartRateService.instance.setActiveChild(_selectedChild!.id);

        if (_selectedWatch!.bluetoothDevice != null) {
          unawaited(HeartRateService.instance.connectToDevice(_selectedWatch!.bluetoothDevice!));
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Jam "$deviceName" berhasil dipasangkan ke ${_selectedChild!.nickname}'),
            backgroundColor: const Color(0xFF1F5C4A),
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Gagal memasangkan jam'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPairing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = _isAndroidPlatform();
    final childName = _selectedChild?.nickname ?? widget.childNickname ?? 'Anak';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E2A24)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pasang jam',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E2A24),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subjudul
                    Text(
                      'Pilih jam yang sudah terhubung lewat Bluetooth HP.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF6F7B74),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Non-Android Banner (Mode Contoh)
                    if (!isAndroid) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3EEDF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1F5C4A).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF1F5C4A),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Mode contoh: Bluetooth tidak tersedia di perangkat ini',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1F5C4A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Pemilihan Anak (Jika ada lebih dari 1 anak dan bukan dari manage_children langsung)
                    if (_children.length > 1 && widget.childId == null) ...[
                      Text(
                        'Pasangkan untuk anak:',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E2A24),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _children.map((c) {
                          final isSelected = _selectedChild?.id == c.id;
                          return ChoiceChip(
                            label: Text(c.nickname),
                            selected: isSelected,
                            selectedColor: const Color(0xFF1F5C4A),
                            backgroundColor: Colors.white,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? Colors.white : const Color(0xFF1E2A24),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF1F5C4A) : const Color(0xFFD9DED6),
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedChild = c;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Card Utama: Daftar Perangkat
                    _buildDevicesCard(),
                  ],
                ),
              ),
            ),

            // Tombol Pasang di Bawah
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isPairing ||
                          _isLoadingDevices ||
                          _selectedWatch == null ||
                          _selectedChild == null)
                      ? null
                      : _handlePair,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F5C4A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF1F5C4A).withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isPairing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Pasang ke $childName',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesCard() {
    // 1. Kondisi Loading
    if (_isLoadingDevices || _isLoadingChildren) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1F5C4A)),
            const SizedBox(height: 16),
            Text(
              'Memeriksa perangkat...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF6F7B74),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Kondisi Izin Bluetooth Ditolak
    if (_permissionDenied) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFE3EEDF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth_disabled_rounded,
                size: 36,
                color: Color(0xFF1F5C4A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Izin Bluetooth Diperlukan',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E2A24),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Izin Bluetooth dan lokasi diperlukan untuk mendeteksi jam yang terhubung ke HP ini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF6F7B74),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F5C4A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Buka Pengaturan'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadDevices,
              child: Text(
                'Coba lagi',
                style: GoogleFonts.inter(
                  color: const Color(0xFF1F5C4A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Kondisi Error
    if (_devicesErrorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            Text(
              _devicesErrorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDevices,
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
      );
    }

    // 4. Kondisi Kosong
    if (_devices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.watch_off_outlined,
                size: 40,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada jam yang terpasang di HP ini. Pasangkan jam lewat pengaturan Bluetooth lebih dulu.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF6F7B74),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadDevices,
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
      );
    }

    // 5. Kondisi Berisi Daftar Jam
    return Container(
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
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _devices.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            indent: 64,
            endIndent: 20,
            color: Color(0xFFF0F0F0),
          ),
          itemBuilder: (context, index) {
            final watch = _devices[index];
            final isSelected = _selectedWatch?.mac == watch.mac;

            return ListTile(
              tileColor: isSelected ? const Color(0xFFE3EEDF).withValues(alpha: 0.6) : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1F5C4A) : const Color(0xFFE3EEDF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.watch_rounded,
                  color: isSelected ? Colors.white : const Color(0xFF1F5C4A),
                  size: 24,
                ),
              ),
              title: Text(
                watch.name,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E2A24),
                ),
              ),
              subtitle: Text(
                _maskMac(watch.mac),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6F7B74),
                ),
              ),
              trailing: isSelected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF1F5C4A),
                      size: 24,
                    )
                  : const Icon(
                      Icons.radio_button_unchecked_rounded,
                      color: Color(0xFFD9DED6),
                      size: 24,
                    ),
              onTap: () {
                setState(() {
                  _selectedWatch = watch;
                });
              },
            );
          },
        ),
      ),
    );
  }
}
