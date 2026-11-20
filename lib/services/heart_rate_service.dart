import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'ble_service.dart';

enum Mode { dummy, ble }

enum HrSensorStatus { measuring, resting, disconnected }

class HeartRateService extends ChangeNotifier {
  static final HeartRateService instance = HeartRateService._internal();

  HeartRateService._internal()
      : _apiService = ApiService(),
        _bleService = BleService(),
        _onRetriggerOverride = null,
        _onReconnectOverride = null {
    unawaited(loadSavedDevice());
  }

  @visibleForTesting
  HeartRateService.forTesting({
    ApiService? apiService,
    BleService? bleService,
    Future<void> Function()? onRetrigger,
    Future<void> Function()? onReconnect,
  })  : _apiService = apiService ?? ApiService(),
        _bleService = bleService ?? BleService(),
        _onRetriggerOverride = onRetrigger,
        _onReconnectOverride = onReconnect;

  static const int retriggerFirstThresholdSeconds = 240;
  static const int retriggerSecondThresholdSeconds = 300;
  static const int reconnectThresholdSeconds = 360;
  static const int staleTimeoutSeconds = 420;

  final ApiService _apiService;
  final BleService _bleService;
  final Future<void> Function()? _onRetriggerOverride;
  final Future<void> Function()? _onReconnectOverride;
  final Random _random = Random();

  // Dummy hanya untuk tampilan; kirim ke server hanya untuk uji sengaja.
  bool sendDummyToBackend = false;

  Mode _currentMode = Mode.dummy;
  Mode get currentMode => _currentMode;

  Timer? _dummyTimer;
  Timer? _staleCheckTimer;

  StreamSubscription<int>? _bleBpmSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  BluetoothConnectionState _currentBleState = BluetoothConnectionState.connected;
  BluetoothConnectionState get currentBleState => _currentBleState;

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  String _bleStatus = '';
  String get bleStatus => _bleStatus;

  bool _isConnectingBle = false;
  bool get isConnectingBle => _isConnectingBle;

  DateTime? _lastBpmReceivedAt;
  DateTime? get lastBpmReceivedAt => _lastBpmReceivedAt;

  int _secondsSinceLastBpm = 0;
  int get secondsSinceLastBpm => _secondsSinceLastBpm;
  int _secondsWaitingFirstBpm = 0;

  int _currentBpm = 75;
  int get currentBpm => _currentBpm;

  int? _activeChildId;
  int? get activeChildId => _activeChildId;

  int? _activeDeviceId;
  int? get activeDeviceId => _activeDeviceId;

  String? _pairedDeviceName;
  String? get pairedDeviceName => _pairedDeviceName;

  bool _isStarted = false;
  final Set<int> _attemptedRecoveryStages = <int>{};
  bool _isRecoveringBle = false;
  bool _needsDeviceRepair = false;
  bool get needsDeviceRepair => _needsDeviceRepair;

  void setActiveChild(int? childId) {
    _activeChildId = childId;
    notifyListeners();
  }

  void setActiveDevice(int? deviceId) {
    _activeDeviceId = deviceId;
    notifyListeners();
  }

  Future<void> setPairedDevice({required int deviceId, required String deviceName}) async {
    _activeDeviceId = deviceId;
    _pairedDeviceName = deviceName;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_device_id', deviceId);
      await prefs.setString('active_device_name', deviceName);
    } catch (_) {}
  }

  Future<void> loadSavedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt('active_device_id');
      final savedName = prefs.getString('active_device_name');
      if (savedId != null) {
        _activeDeviceId = savedId;
      }
      if (savedName != null) {
        _pairedDeviceName = savedName;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearPairedDevice() async {
    _activeDeviceId = null;
    _pairedDeviceName = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_device_id');
      await prefs.remove('active_device_name');
    } catch (_) {}
  }

  HrSensorStatus get sensorStatus {
    if (_currentBleState != BluetoothConnectionState.connected) {
      return HrSensorStatus.disconnected;
    }
    if (_secondsSinceLastBpm > 6) {
      return HrSensorStatus.resting;
    }
    return HrSensorStatus.measuring;
  }

  String get statusText {
    if (_currentMode == Mode.dummy) {
      return 'Data demo · tersambung';
    }
    switch (sensorStatus) {
      case HrSensorStatus.measuring:
        return 'Jam · mengukur';
      case HrSensorStatus.resting:
        return 'Jam · sensor istirahat (normal)';
      case HrSensorStatus.disconnected:
        return 'Jam · terputus';
    }
  }

  void start() {
    if (_isStarted) return;
    _isStarted = true;
    _startStaleChecker();
    if (_currentMode == Mode.dummy) {
      _startDummyMode();
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        _onRetriggerOverride == null) {
      unawaited(_autoConnectIfPaired());
    }
  }

  Future<void> _autoConnectIfPaired() async {
    try {
      await loadSavedDevice();
      if (_pairedDeviceName == null || _pairedDeviceName!.trim().isEmpty) {
        return;
      }
      await reconnectSavedWatch();
    } catch (e) {
      debugPrint('[HeartRateService] Gagal auto-connect jam tersimpan: $e');
    }
  }

  /// Menyambungkan ulang smartwatch yang tersimpan / sudah bonded di HP.
  Future<bool> reconnectSavedWatch() async {
    if (_isConnectingBle) return false;
    try {
      await loadSavedDevice();
      if (_connectedDevice != null) {
        await _bleService.disconnect();
      }
      final bonded = await _bleService.getBondedDevices();
      if (bonded.isEmpty) {
        _bleStatus = 'Jam tidak ditemukan di Bluetooth HP';
        notifyListeners();
        return false;
      }

      BluetoothDevice target = bonded.first;
      final saved = (_pairedDeviceName ?? '').trim().toLowerCase();
      for (final d in bonded) {
        final name = d.platformName.trim().toLowerCase();
        if (saved.isNotEmpty && name == saved) {
          target = d;
          break;
        }
        if (name.contains('xwatch') || name.contains('h4')) {
          target = d;
        }
      }

      final resolvedName = target.platformName.isNotEmpty
          ? target.platformName
          : (_pairedDeviceName ?? target.remoteId.str);
      if (_activeDeviceId != null) {
        await setPairedDevice(
          deviceId: _activeDeviceId!,
          deviceName: resolvedName,
        );
      }
      await connectToDevice(target);
      return true;
    } catch (e) {
      debugPrint('[HeartRateService] Gagal sambungkan ulang jam: $e');
      _bleStatus = 'Gagal menyambungkan ulang jam';
      notifyListeners();
      return false;
    }
  }

  /// Memutus koneksi BLE dan menghapus pengaturan jam tersimpan untuk pasang ulang.
  Future<void> resetPairedWatch() async {
    await _bleBpmSubscription?.cancel();
    _bleBpmSubscription = null;
    await _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
    await _bleService.disconnect();

    _connectedDevice = null;
    _isConnectingBle = false;
    _needsDeviceRepair = false;
    _attemptedRecoveryStages.clear();
    _currentBleState = BluetoothConnectionState.disconnected;
    _bleStatus = 'Belum ada jam terpasang';

    await clearPairedDevice();
  }

  void stop() {
    _dummyTimer?.cancel();
    _dummyTimer = null;
    _staleCheckTimer?.cancel();
    _staleCheckTimer = null;
    _isStarted = false;
  }

  void _startStaleChecker() {
    _staleCheckTimer?.cancel();
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lastBpmReceivedAt != null) {
        _secondsWaitingFirstBpm = 0;
        final diff = DateTime.now().difference(_lastBpmReceivedAt!).inSeconds;
        if (_secondsSinceLastBpm != diff) {
          _secondsSinceLastBpm = diff;
          notifyListeners();
        }
        if (_currentMode == Mode.ble) {
          if (_connectedDevice != null &&
              _onRetriggerOverride == null &&
              !_isRecoveringBle &&
              diff > 0) {
            if (diff % 180 == 0) {
              unawaited(_reconnectCurrentDevice());
            } else if (diff % 45 == 0) {
              unawaited(_retriggerCurrentDevice());
            }
          }
          unawaited(_evaluateBleRecovery(diff));
        }
      } else if (_currentMode == Mode.ble &&
          _connectedDevice != null &&
          _onRetriggerOverride == null) {
        _secondsWaitingFirstBpm++;
        if (!_isRecoveringBle &&
            _secondsWaitingFirstBpm > 0 &&
            _secondsWaitingFirstBpm % 35 == 0) {
          unawaited(_retriggerCurrentDevice());
        }
      }
    });
  }

  Future<void> _evaluateBleRecovery(int silentSeconds) async {
    if (_currentMode != Mode.ble || _isRecoveringBle) return;
    if (_connectedDevice == null &&
        _onRetriggerOverride == null &&
        _onReconnectOverride == null) {
      return;
    }

    if (silentSeconds >= staleTimeoutSeconds) {
      if (!_needsDeviceRepair) {
        _needsDeviceRepair = true;
        _bleStatus = 'Perlu hubungkan ulang perangkat';
        notifyListeners();
      }
      return;
    }

    if (silentSeconds >= reconnectThresholdSeconds &&
        !_attemptedRecoveryStages.contains(reconnectThresholdSeconds)) {
      _attemptedRecoveryStages.add(reconnectThresholdSeconds);
      await _runRecoveryAction(
        () => _onReconnectOverride != null
            ? _onReconnectOverride()
            : _reconnectCurrentDevice(),
        'reconnect',
      );
    } else if (silentSeconds >= retriggerSecondThresholdSeconds &&
        !_attemptedRecoveryStages.contains(retriggerSecondThresholdSeconds)) {
      _attemptedRecoveryStages.add(retriggerSecondThresholdSeconds);
      await _runRecoveryAction(
        () => _onRetriggerOverride != null
            ? _onRetriggerOverride()
            : _retriggerCurrentDevice(),
        'retrigger-5m',
      );
    } else if (silentSeconds >= retriggerFirstThresholdSeconds &&
        !_attemptedRecoveryStages.contains(retriggerFirstThresholdSeconds)) {
      _attemptedRecoveryStages.add(retriggerFirstThresholdSeconds);
      await _runRecoveryAction(
        () => _onRetriggerOverride != null
            ? _onRetriggerOverride()
            : _retriggerCurrentDevice(),
        'retrigger-4m',
      );
    }
  }

  Future<void> _runRecoveryAction(
    Future<void> Function() action,
    String label,
  ) async {
    _isRecoveringBle = true;
    try {
      debugPrint('[HeartRateService] Menjalankan pemulihan BLE ($label)...');
      await action();
    } catch (e) {
      debugPrint('[HeartRateService] Pemulihan BLE ($label) gagal: $e');
    } finally {
      _isRecoveringBle = false;
    }
  }

  Future<void> _retriggerCurrentDevice() async {
    final device = _connectedDevice;
    if (device == null) return;
    if (_currentBleState != BluetoothConnectionState.connected) {
      await _reconnectCurrentDevice();
      return;
    }
    await _bleService.retriggerHrMeasurement();
  }

  Future<void> _reconnectCurrentDevice() async {
    final device = _connectedDevice;
    if (device == null) return;
    await _bleService.disconnect();
    await connectToDevice(device, preserveRecoveryStages: true);
  }

  @visibleForTesting
  Future<void> evaluateBleRecoveryForTest(int silentSeconds) =>
      _evaluateBleRecovery(silentSeconds);

  void _startDummyMode() {
    _currentBleState = BluetoothConnectionState.connected;
    _dummyTimer?.cancel();
    _dummyTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_currentMode != Mode.dummy) return;

      int nextBpm;
      if (_random.nextDouble() < 0.8) {
        nextBpm = 60 + _random.nextInt(41); // 60-100
      } else {
        nextBpm = 101 + _random.nextInt(20); // 101-120
      }

      _currentBpm = nextBpm;
      _lastBpmReceivedAt = DateTime.now();
      _secondsSinceLastBpm = 0;
      notifyListeners();

      if (sendDummyToBackend) {
        _apiService.postHeartRate(
          bpm: nextBpm,
          deviceName: 'XWATCH_DUMMY',
          deviceMac: 'AA:BB:CC:DD:EE:FF',
          childId: _activeChildId,
          deviceId: _activeDeviceId,
        );
      }
    });
  }

  void switchMode(Mode mode) {
    if (_currentMode == mode) return;
    _currentMode = mode;

    if (mode == Mode.dummy) {
      _bleBpmSubscription?.cancel();
      _deviceStateSubscription?.cancel();
      _bleService.disconnect();
      _connectedDevice = null;
      _bleStatus = '';
      _isConnectingBle = false;
      _attemptedRecoveryStages.clear();
      _needsDeviceRepair = false;
      _currentBleState = BluetoothConnectionState.connected;
      _startDummyMode();
    } else {
      _dummyTimer?.cancel();
      _currentBleState = BluetoothConnectionState.disconnected;
    }
    notifyListeners();
  }

  Future<void> connectToDevice(
    BluetoothDevice device, {
    bool preserveRecoveryStages = false,
  }) async {
    _bleBpmSubscription?.cancel();
    _deviceStateSubscription?.cancel();

    _currentMode = Mode.ble;
    _connectedDevice = device;
    _isConnectingBle = true;
    _needsDeviceRepair = false;
    if (!preserveRecoveryStages) {
      _attemptedRecoveryStages.clear();
    }

    final deviceName = device.platformName.isNotEmpty ? device.platformName : device.remoteId.str;
    _bleStatus = 'Menghubungkan ke $deviceName...';
    notifyListeners();

    _deviceStateSubscription = device.connectionState.listen((state) {
      if (_currentMode != Mode.ble) return;
      _currentBleState = state;
      if (state == BluetoothConnectionState.connected) {
        _isConnectingBle = false;
        _bleStatus = 'Terhubung ke $deviceName, menunggu data...';
      } else if (state == BluetoothConnectionState.disconnected) {
        _isConnectingBle = false;
        _bleStatus = 'Terputus dari $deviceName';
      }
      notifyListeners();
    });

    final bpmStream = _bleService.connectAndListenBpm(device);

    _bleBpmSubscription = bpmStream.listen(
      (bpm) {
        if (_currentMode != Mode.ble) return;
        _isConnectingBle = false;
        _bleStatus = 'Terhubung ke $deviceName';
        _currentBpm = bpm;
        _lastBpmReceivedAt = DateTime.now();
        _secondsSinceLastBpm = 0;
        _attemptedRecoveryStages.clear();
        _needsDeviceRepair = false;
        notifyListeners();

        _apiService.postHeartRate(
          bpm: bpm,
          deviceName: deviceName,
          deviceMac: device.remoteId.str,
          childId: _activeChildId,
          deviceId: _activeDeviceId,
        );
      },
      onError: (error) {
        if (_currentMode != Mode.ble) return;
        final errText = error.toString().replaceAll('Exception: ', '');
        _isConnectingBle = false;
        _bleStatus = 'Gagal membaca sensor: $errText';
        notifyListeners();
      },
    );
  }

  void disconnectBle() {
    _bleBpmSubscription?.cancel();
    _deviceStateSubscription?.cancel();
    _bleService.disconnect();
    _connectedDevice = null;
    _currentBleState = BluetoothConnectionState.disconnected;
    _bleStatus = 'Terputus';
    _attemptedRecoveryStages.clear();
    _needsDeviceRepair = false;
    notifyListeners();
  }

  @visibleForTesting
  void setBleTestState({
    required Mode mode,
    BluetoothConnectionState bleState = BluetoothConnectionState.connected,
    int bpm = 75,
    DateTime? lastBpmReceivedAt,
    int secondsSinceLastBpm = 0,
    bool needsDeviceRepair = false,
  }) {
    _dummyTimer?.cancel();
    _currentMode = mode;
    _currentBleState = bleState;
    _currentBpm = bpm;
    _lastBpmReceivedAt = lastBpmReceivedAt;
    _secondsSinceLastBpm = secondsSinceLastBpm;
    _attemptedRecoveryStages.clear();
    _needsDeviceRepair = needsDeviceRepair;
    notifyListeners();
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
}
