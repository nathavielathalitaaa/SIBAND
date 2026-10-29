import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  static const String feeaServiceUuid = "0000feea-0000-1000-8000-00805f9b34fb";
  static const List<int> triggerHrPayload = [
    0xfe, 0xea, 0x20, 0x08, 0xb9, 0x09, 0x01, 0x01
  ];
  static const List<int> stopHrPayload = [
    0xfe, 0xea, 0x20, 0x07, 0xb9, 0x10, 0x00
  ];

  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<List<int>>? _feeaNotifySubscription;
  StreamController<int>? _bpmController;

  BluetoothCharacteristic? _feeaWriteChar;
  BluetoothCharacteristic? _feeaNotifyChar;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<List<BluetoothDevice>> getBondedDevices() async {
    debugPrint("[BLE] Minta izin...");
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = statuses.values.every((s) => s.isGranted);
    if (!allGranted) {
      debugPrint("[BLE] ADA IZIN YANG DITOLAK, scan dibatalkan.");
      return [];
    }

    debugPrint("[BLE] Ambil daftar system/bonded devices...");
    try {
      List<BluetoothDevice> systemDevices = await FlutterBluePlus.systemDevices([]);
      for (var d in systemDevices) {
        debugPrint("[BLE] System device: id=${d.remoteId} name='${d.platformName}'");
      }
      return systemDevices;
    } catch (e) {
      debugPrint("[BLE] Error getting bonded devices: $e");
      return [];
    }
  }

  /// Cari characteristic write & notify di dalam service 0xFEEA,
  /// berdasarkan PROPERTI (bukan UUID hardcoded, karena UUID persisnya
  /// masih ambigu antara FEE1/FEE2 di device ini).
  Future<void> _resolveFeeaCharacteristics(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();

    BluetoothService? feeaService;
    for (final s in services) {
      if (s.uuid.toString().toLowerCase() == feeaServiceUuid ||
          s.uuid.toString().toLowerCase().contains("feea")) {
        feeaService = s;
        break;
      }
    }

    if (feeaService == null) {
      throw Exception("[BLE] Service 0xFEEA tidak ditemukan di device ini");
    }

    for (final c in feeaService.characteristics) {
      debugPrint(
        "[BLE][FEEA] Char ${c.uuid} | write=${c.properties.writeWithoutResponse} "
        "notify=${c.properties.notify}",
      );
      if (c.properties.writeWithoutResponse && _feeaWriteChar == null) {
        _feeaWriteChar = c;
      }
      if (c.properties.notify && _feeaNotifyChar == null) {
        _feeaNotifyChar = c;
      }
    }

    if (_feeaWriteChar == null) {
      throw Exception(
        "[BLE] Tidak ketemu characteristic write di service 0xFEEA — "
        "cek log [BLE][FEEA] di atas buat lihat properti yang kebaca",
      );
    }
  }

  /// Panggil ini SEBELUM subscribe ke 0x2A37, supaya jam mulai
  /// ngukur HR secara realtime (meniru apa yang dilakukan My Health
  /// pas tombol "Ukur HR" ditap).
  Future<void> triggerContinuousHrMeasurement(BluetoothDevice device) async {
    await _resolveFeeaCharacteristics(device);

    debugPrint("[BLE] Mengirim trigger start measurement: $triggerHrPayload");
    await _feeaWriteChar!.write(
      triggerHrPayload,
      withoutResponse: true,
    );

    // Kalau ada notify characteristic di 0xFEEA, subscribe juga
    // buat jaga-jaga ada handshake/ack yang perlu direspons.
    if (_feeaNotifyChar != null) {
      await _feeaNotifyChar!.setNotifyValue(true);
      _feeaNotifySubscription?.cancel();
      _feeaNotifySubscription = _feeaNotifyChar!.onValueReceived.listen((value) {
        debugPrint("[BLE][FEEA] Notify balik: ${value.toString()}");
      });
    }
  }

  /// Panggil ini pas disconnect, biar jam berhenti ngukur terus-terusan
  /// (hemat baterai jam).
  Future<void> stopHrMeasurement() async {
    if (_feeaWriteChar == null) return;
    debugPrint("[BLE] Mengirim stop measurement: $stopHrPayload");
    await _feeaWriteChar!.write(stopHrPayload, withoutResponse: true);
  }

  Stream<int> connectAndListenBpm(BluetoothDevice device) {
    _notifySubscription?.cancel();
    _notifySubscription = null;

    if (_bpmController != null && !_bpmController!.isClosed) {
      _bpmController!.close();
    }

    _bpmController = StreamController<int>.broadcast();

    _startBpmConnection(device);

    return _bpmController!.stream;
  }

  Future<void> _startBpmConnection(BluetoothDevice device) async {
    try {
      if (_connectedDevice != null && _connectedDevice!.remoteId != device.remoteId) {
        debugPrint("[BLE] Memutus perangkat sebelumnya (${_connectedDevice!.remoteId})...");
        await _connectedDevice!.disconnect();
      }

      debugPrint("[BLE] Connecting to ${device.platformName} (${device.remoteId})...");
      _connectedDevice = device;
      await device.connect(autoConnect: false, mtu: null).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Koneksi ke device Bluetooth timed out.');
        },
      );

      debugPrint("[BLE] Connected. Discovering services...");
      List<BluetoothService> services = await device.discoverServices();
      debugPrint("[BLE] Jumlah service ditemukan: ${services.length}");

      // Trigger pengukuran kontinu via 0xFEEA custom service
      await triggerContinuousHrMeasurement(device);

      BluetoothService? hrService;
      for (var service in services) {
        final uuidStr = service.uuid.toString().toLowerCase();
        if (uuidStr.contains("180d")) {
          hrService = service;
          break;
        }
      }

      if (hrService == null) {
        throw Exception('Device "${device.platformName.isNotEmpty ? device.platformName : device.remoteId}" tidak mendukung Heart Rate Service (0x180D).');
      }

      debugPrint("[BLE] Heart Rate service (0x180D) ketemu!");

      BluetoothCharacteristic? hrChar;
      for (var char in hrService.characteristics) {
        final charUuidStr = char.uuid.toString().toLowerCase();
        if (charUuidStr.contains("2a37")) {
          hrChar = char;
          break;
        }
      }

      if (hrChar == null) {
        throw Exception('Heart Rate Measurement Characteristic (0x2A37) tidak ditemukan.');
      }

      debugPrint("[BLE] Subscribing ke Heart Rate Measurement (0x2A37)...");

      _notifySubscription = hrChar.onValueReceived.listen(
        (value) {
          debugPrint('[BLE] Raw bytes: $value, length: ${value.length}');
          int? bpm = _parseHeartRate(value);
          if (bpm != null) {
            debugPrint("[BLE] Parsed BPM: $bpm");
            if (_bpmController != null && !_bpmController!.isClosed) {
              _bpmController!.add(bpm);
            }
          }
        },
        onError: (err) {
          debugPrint("[BLE] Error pada notify stream onValueReceived: $err");
          if (_bpmController != null && !_bpmController!.isClosed) {
            _bpmController!.addError(err);
          }
        },
      );

      await hrChar.setNotifyValue(true);

      // Explorasi service & characteristic untuk investigasi suhu tubuh & sensor lain
      // (dijalankan setelah listener HR utama aktif agar tidak bersaing dengan setup awal)
      unawaited(exploreServices(services));

    } catch (e) {
      debugPrint("[BLE] Error koneksi BLE: $e");
      if (_bpmController != null && !_bpmController!.isClosed) {
        _bpmController!.addError(e);
      }
    }
  }

  Future<void> disconnect() async {
    try {
      await stopHrMeasurement();

      await _notifySubscription?.cancel();
      _notifySubscription = null;

      await _feeaNotifySubscription?.cancel();
      _feeaNotifySubscription = null;

      _feeaWriteChar = null;
      _feeaNotifyChar = null;

      if (_connectedDevice != null) {
        debugPrint("[BLE] Disconnecting dari ${_connectedDevice!.remoteId}...");
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
      }

      if (_bpmController != null && !_bpmController!.isClosed) {
        await _bpmController!.close();
        _bpmController = null;
      }
    } catch (e) {
      debugPrint("[BLE] Error memutus koneksi: $e");
    }
  }

  /// Explorasi lengkap semua service & characteristic (khususnya 0xFEE7, 0x190E, 0xAE00, dll)
  Future<void> exploreServices(List<BluetoothService> services) async {
    debugPrint("[BLE][EXPLORE] === START ENUMERASI SERVICES & CHARACTERISTICS ===");
    for (final service in services) {
      final sUuid = service.uuid.toString().toLowerCase();
      debugPrint("[BLE][EXPLORE] Service Found: $sUuid");

      for (final c in service.characteristics) {
        final cUuid = c.uuid.toString().toLowerCase();
        final read = c.properties.read;
        final write = c.properties.write || c.properties.writeWithoutResponse;
        final notify = c.properties.notify;
        final indicate = c.properties.indicate;

        debugPrint(
          "[BLE][EXPLORE] Service $sUuid > Char $cUuid | props: read=$read write=$write notify=$notify indicate=$indicate",
        );

        if (read) {
          try {
            final value = await c.read();
            final hex = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
            debugPrint("[BLE][EXPLORE] Char $cUuid value: $hex (raw: $value)");
          } catch (e) {
            debugPrint("[BLE][EXPLORE] Gagal read Char $cUuid: $e");
          }
        }

        if (notify || indicate) {
          try {
            await c.setNotifyValue(true);
            final sub = c.onValueReceived.listen((value) {
              final hex = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
              debugPrint("[BLE][EXPLORE] NOTIFY Char $cUuid value: $hex (raw: $value)");
            });

            // Auto-unsubscribe setelah 30 detik untuk explorasi sementara
            Future.delayed(const Duration(seconds: 30), () async {
              try {
                await sub.cancel();
                await c.setNotifyValue(false);
                debugPrint("[BLE][EXPLORE] Unsubscribed notify Char $cUuid");
              } catch (_) {}
            });
          } catch (e) {
            debugPrint("[BLE][EXPLORE] Gagal setNotifyValue Char $cUuid: $e");
          }
        }
      }
    }
    debugPrint("[BLE][EXPLORE] === SELESAI ENUMERASI SERVICES ===");
  }

  int? _parseHeartRate(List<int> value) {
    if (value.isEmpty) {
      debugPrint("[BLE] Notifikasi kosong (0 bytes), dilewati.");
      return null;
    }
    if (value.length < 2) {
      debugPrint("[BLE] Data terlalu pendek (${value.length} byte), minimal butuh 2 byte.");
      return null;
    }

    int flags = value[0];
    final String flagsBin = flags.toRadixString(2).padLeft(8, '0');
    final bool isUint16 = (flags & 0x01) != 0;
    final bool hasEnergyExpended = (flags & 0x08) != 0;
    final bool hasRrInterval = (flags & 0x10) != 0;

    debugPrint("[BLE][EXPLORE][RR] Full Flags Byte: $flagsBin (0x${flags.toRadixString(16).padLeft(2, '0')})");
    debugPrint("[BLE][EXPLORE][RR] Bit 0x10 set (RR-Interval Present): $hasRrInterval");

    int bpm;
    int offset = 1;

    if (isUint16) {
      if (value.length < 3) {
        debugPrint("[BLE] Flags mengindikasikan UINT16 tetapi panjang data < 3 byte.");
        return null;
      }
      bpm = value[1] | (value[2] << 8);
      offset += 2;
    } else {
      bpm = value[1];
      offset += 1;
    }

    if (hasEnergyExpended) {
      offset += 2;
    }

    if (hasRrInterval) {
      List<int> rrIntervals = [];
      while (offset + 1 < value.length) {
        int rr = value[offset] | (value[offset + 1] << 8);
        rrIntervals.add(rr);
        offset += 2;
      }
      debugPrint("[BLE][EXPLORE][RR] Parsed RR-Interval values (1/1024s): $rrIntervals");
    } else {
      debugPrint("[BLE][EXPLORE][RR] Tidak ada RR-Interval pada paket data ini.");
    }

    return bpm;
  }
}