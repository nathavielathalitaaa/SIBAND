import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/ble_service.dart';
import 'login_screen.dart';

enum Mode { dummy, ble }
enum HrSensorStatus { measuring, resting, disconnected }

class BpmDashboardScreen extends StatefulWidget {
  const BpmDashboardScreen({super.key});

  @override
  State<BpmDashboardScreen> createState() => _BpmDashboardScreenState();
}

class _BpmDashboardScreenState extends State<BpmDashboardScreen> {
  final ApiService _apiService = ApiService();
  final BleService _bleService = BleService();
  final Random _random = Random();

  Mode _currentMode = Mode.dummy;
  Timer? _dummyTimer;

  StreamSubscription<int>? _bleBpmSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  BluetoothConnectionState _currentBleState = BluetoothConnectionState.connected;
  String _bleStatus = '';
  bool _isConnectingBle = false;

  DateTime? _lastBpmReceivedAt;
  Timer? _staleCheckTimer;
  int _secondsSinceLastBpm = 0;

  int _currentBpm = 75;
  final List<FlSpot> _spots = [];
  int _pointCounter = 0;
  bool _isLoadingHistory = false;

  HrSensorStatus get _sensorStatus {
    if (_currentBleState != BluetoothConnectionState.connected) {
      return HrSensorStatus.disconnected;
    }
    if (_secondsSinceLastBpm > 6) {
      return HrSensorStatus.resting; // bukan "sleeping"/error lagi
    }
    return HrSensorStatus.measuring;
  }

  Widget _buildStatusIndicator() {
    final status = _sensorStatus;
    final (label, color, icon) = switch (status) {
      HrSensorStatus.measuring => ('Mengukur...', Colors.green, Icons.favorite),
      HrSensorStatus.resting => (
          'Sensor istirahat sejenak (normal)',
          Colors.orange,
          Icons.pause_circle_outline
        ),
      HrSensorStatus.disconnected => (
          'Terputus dari device',
          Colors.red,
          Icons.bluetooth_disabled
        ),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _startDummyMode();

    // Cek tiap detik: udah berapa lama sejak BPM terakhir masuk
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_lastBpmReceivedAt != null) {
        final diff = DateTime.now().difference(_lastBpmReceivedAt!).inSeconds;
        setState(() {
          _secondsSinceLastBpm = diff;
        });
      }
    });
  }

  @override
  void dispose() {
    _staleCheckTimer?.cancel();
    _dummyTimer?.cancel();
    _bleBpmSubscription?.cancel();
    _deviceStateSubscription?.cancel();
    _bleService.disconnect();
    super.dispose();
  }

  void _startDummyMode() {
    _currentBleState = BluetoothConnectionState.connected;
    _dummyTimer?.cancel();
    _dummyTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || _currentMode != Mode.dummy) return;

      // 80% chance 60-100 BPM, 20% chance 101-120 BPM
      int nextBpm;
      if (_random.nextDouble() < 0.8) {
        nextBpm = 60 + _random.nextInt(41); // 60-100
      } else {
        nextBpm = 101 + _random.nextInt(20); // 101-120
      }

      setState(() {
        _currentBpm = nextBpm;
        _lastBpmReceivedAt = DateTime.now();
        _pointCounter++;

        _spots.add(FlSpot(_pointCounter.toDouble(), _currentBpm.toDouble()));

        // Keep maximum 20 points
        if (_spots.length > 20) {
          _spots.removeAt(0);
        }
      });

      // Post to backend asynchronously
      _apiService.postHeartRate(
        bpm: nextBpm,
        deviceName: 'XWATCH_DUMMY',
        deviceMac: 'AA:BB:CC:DD:EE:FF',
      );
    });
  }

  void _switchMode(Mode mode) {
    setState(() {
      _currentMode = mode;
    });

    if (mode == Mode.dummy) {
      _bleBpmSubscription?.cancel();
      _deviceStateSubscription?.cancel();
      _bleService.disconnect();
      setState(() {
        _bleStatus = '';
        _isConnectingBle = false;
        _currentBleState = BluetoothConnectionState.connected;
      });
      _startDummyMode();
    } else {
      setState(() {
        _currentBleState = BluetoothConnectionState.disconnected;
      });
      _dummyTimer?.cancel();
      _showDevicePickerAndConnect();
    }
  }

  Future<void> _showDevicePickerAndConnect() async {
    setState(() {
      _isConnectingBle = true;
      _bleStatus = 'Memuat perangkat Bluetooth terpasang...';
    });

    final devices = await _bleService.getBondedDevices();

    if (!mounted) return;

    if (devices.isEmpty) {
      setState(() {
        _isConnectingBle = false;
        _bleStatus = 'Tidak ada device Bluetooth terpasang.';
      });

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tidak Ada Perangkat'),
          content: const Text(
            'Tidak ada device Bluetooth yang terpasang. Pasangkan smartband dulu lewat Pengaturan Bluetooth HP.',
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
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Device Bluetooth'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final d = devices[index];
                final name = d.platformName.isNotEmpty
                    ? d.platformName
                    : 'Perangkat Tanpa Nama';
                final mac = d.remoteId.str;
                return ListTile(
                  leading: const Icon(Icons.watch),
                  title: Text(name),
                  subtitle: Text(mac),
                  onTap: () {
                    Navigator.of(context).pop(d);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (chosenDevice == null) {
      setState(() {
        _isConnectingBle = false;
        _bleStatus = 'Koneksi dibatalkan oleh pengguna.';
      });
      return;
    }

    final deviceName = chosenDevice.platformName.isNotEmpty
        ? chosenDevice.platformName
        : chosenDevice.remoteId.str;

    setState(() {
      _isConnectingBle = true;
      _bleStatus = 'Menghubungkan ke $deviceName...';
    });

    _startBleListening(chosenDevice);
  }

  void _startBleListening(BluetoothDevice device) {
    _bleBpmSubscription?.cancel();
    _deviceStateSubscription?.cancel();

    final deviceName = device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.str;

    // Listen ke event perubahan koneksi fisik dari device Bluetooth
    _deviceStateSubscription = device.connectionState.listen((state) {
      if (!mounted || _currentMode != Mode.ble) return;
      setState(() {
        _currentBleState = state;
        if (state == BluetoothConnectionState.connected) {
          _isConnectingBle = false;
          _bleStatus = 'Terhubung ke $deviceName, menunggu data...';
        } else if (state == BluetoothConnectionState.disconnected) {
          _isConnectingBle = false;
          _bleStatus = 'Terputus dari $deviceName';
        }
      });
    });

    final bpmStream = _bleService.connectAndListenBpm(device);

    _bleBpmSubscription = bpmStream.listen(
      (bpm) {
        if (!mounted || _currentMode != Mode.ble) return;
        debugPrint('[DASHBOARD] Menerima BPM dari stream: $bpm, akan setState...');
        setState(() {
          _isConnectingBle = false;
          _bleStatus = 'Terhubung ke $deviceName';
          _currentBpm = bpm;
          _lastBpmReceivedAt = DateTime.now();
          _pointCounter++;
          _spots.add(FlSpot(_pointCounter.toDouble(), bpm.toDouble()));
          if (_spots.length > 20) {
            _spots.removeAt(0);
          }
        });

        // Post to backend asynchronously
        _apiService.postHeartRate(
          bpm: bpm,
          deviceName: deviceName,
          deviceMac: device.remoteId.str,
        );
      },
      onError: (error) {
        if (!mounted || _currentMode != Mode.ble) return;
        final errText = error.toString().replaceAll('Exception: ', '');
        setState(() {
          _isConnectingBle = false;
          _bleStatus = 'Gagal: $errText';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Koneksi BLE Gagal: $errText'),
            backgroundColor: Colors.red,
          ),
        );
      },
      onDone: () {
        // Status koneksi fisik tetap dikendalikan oleh connectionState.listen
      },
    );
  }

  Future<void> _fetchHistoryFromServer() async {
    setState(() {
      _isLoadingHistory = true;
    });

    final history = await _apiService.getHeartRateHistory();

    if (!mounted) return;

    setState(() {
      _isLoadingHistory = false;
      if (history.isNotEmpty) {
        _spots.clear();
        // Server returns newest first, so reverse to display chronologically
        final reversedList = history.reversed.toList();
        for (int i = 0; i < reversedList.length; i++) {
          final bpmVal = (reversedList[i]['bpm'] as num).toDouble();
          _spots.add(FlSpot(i.toDouble(), bpmVal));
        }
        _pointCounter = reversedList.length;
        if (reversedList.isNotEmpty) {
          _currentBpm = (reversedList.last['bpm'] as num).toInt();
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          history.isNotEmpty
              ? 'Berhasil memuat ${history.length} data riwayat dari server'
              : 'Gagal atau tidak ada data riwayat dari server',
        ),
        backgroundColor: history.isNotEmpty ? Colors.teal : Colors.orange,
      ),
    );
  }

  Color _getBpmColor(int bpm) {
    if (bpm >= 60 && bpm <= 100) {
      return Colors.green;
    } else if ((bpm >= 50 && bpm < 60) || (bpm > 100 && bpm <= 150)) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bpmColor = _getBpmColor(_currentBpm);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CalmiBand Monitor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SegmentedButton<Mode>(
              segments: const [
                ButtonSegment<Mode>(
                  value: Mode.dummy,
                  label: Text('Dummy'),
                  icon: Icon(Icons.bolt),
                ),
                ButtonSegment<Mode>(
                  value: Mode.ble,
                  label: Text('BLE Asli'),
                  icon: Icon(Icons.bluetooth),
                ),
              ],
              selected: {_currentMode},
              onSelectionChanged: (Set<Mode> newSelection) {
                _switchMode(newSelection.first);
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_currentMode == Mode.ble)
              Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: _bleStatus.contains('Terhubung')
                      ? Colors.green.shade50
                      : (_bleStatus.contains('Gagal') || _bleStatus.contains('Error') || _bleStatus.contains('Terputus'))
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: _bleStatus.contains('Terhubung')
                        ? Colors.green.shade300
                        : (_bleStatus.contains('Gagal') || _bleStatus.contains('Error') || _bleStatus.contains('Terputus'))
                            ? Colors.red.shade300
                            : Colors.blue.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    if (_isConnectingBle)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      Icon(
                        _bleStatus.contains('Terhubung')
                            ? Icons.bluetooth_connected
                            : (_bleStatus.contains('Gagal') || _bleStatus.contains('Error') || _bleStatus.contains('Terputus'))
                                ? Icons.bluetooth_disabled
                                : Icons.bluetooth_searching,
                        color: _bleStatus.contains('Terhubung')
                            ? Colors.green
                            : (_bleStatus.contains('Gagal') || _bleStatus.contains('Error') || _bleStatus.contains('Terputus'))
                                ? Colors.red
                                : Colors.blue,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _bleStatus.isNotEmpty ? _bleStatus : 'Mode BLE Aktif',
                        style: TextStyle(
                          color: _bleStatus.contains('Terhubung')
                              ? Colors.green.shade900
                              : (_bleStatus.contains('Gagal') || _bleStatus.contains('Error') || _bleStatus.contains('Terputus'))
                                  ? Colors.red.shade900
                                  : Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Pilih Perangkat Lain',
                      onPressed: _showDevicePickerAndConnect,
                    ),
                  ],
                ),
              ),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    Text(
                      'Denyut Jantung Terkini',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_currentBpm',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: bpmColor,
                      ),
                    ),
                    Text(
                      'BPM',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: bpmColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusIndicator(),
                    if (_lastBpmReceivedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Update terakhir: ${_secondsSinceLastBpm}s lalu',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text(
                  'Grafik Riwayat BPM',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoadingHistory ? null : _fetchHistoryFromServer,
                  icon: _isLoadingHistory
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Muat Riwayat dari Server'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: 20.0,
                    left: 12.0,
                    top: 24.0,
                    bottom: 12.0,
                  ),
                  child: _spots.isEmpty
                      ? const Center(
                          child: Text('Belum ada data BPM untuk ditampilkan'),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                ),
                              ),
                              bottomTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            minY: 40,
                            maxY: 160,
                            lineBarsData: [
                              LineChartBarData(
                                spots: _spots,
                                isCurved: true,
                                color: Theme.of(context).colorScheme.primary,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.15),
                                ),
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
    );
  }
}
