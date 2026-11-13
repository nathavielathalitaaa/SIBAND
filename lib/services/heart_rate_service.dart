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

  HeartRateService._internal() : _apiService = ApiService() {
    unawaited(loadSavedDevice());
  }

  @visibleForTesting
  HeartRateService.forTesting({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  final BleService _bleService = BleService();
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

  int _currentBpm = 75;
  int get currentBpm => _currentBpm;

  int? _activeChildId;
  int? get activeChildId => _activeChildId;

  int? _activeDeviceId;
  int? get activeDeviceId => _activeDeviceId;

  String? _pairedDeviceName;
  String? get pairedDeviceName => _pairedDeviceName;

  bool _isStarted = false;

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
        final diff = DateTime.now().difference(_lastBpmReceivedAt!).inSeconds;
        if (_secondsSinceLastBpm != diff) {
          _secondsSinceLastBpm = diff;
          notifyListeners();
        }
      }
    });
  }

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
      _currentBleState = BluetoothConnectionState.connected;
      _startDummyMode();
    } else {
      _dummyTimer?.cancel();
      _currentBleState = BluetoothConnectionState.disconnected;
    }
    notifyListeners();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    _bleBpmSubscription?.cancel();
    _deviceStateSubscription?.cancel();

    _currentMode = Mode.ble;
    _connectedDevice = device;
    _isConnectingBle = true;

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
