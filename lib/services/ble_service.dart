import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  static const heartRateServiceUuid = "0000180d-0000-1000-8000-00805f9b34fb";
  static const heartRateCharUuid = "00002a37-0000-1000-8000-00805f9b34fb";
  static const targetMac = "A3:23:78:8B:2F:A5";

  Future<void> scanAndConnect() async {
  print("[BLE] Minta izin...");
  Map<Permission, PermissionStatus> statuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
  ].request();

  bool allGranted = statuses.values.every((s) => s.isGranted);
  if (!allGranted) {
    print("[BLE] ADA IZIN YANG DITOLAK, scan dibatalkan.");
    return;
  }

  print("[BLE] Ambil daftar system/bonded devices...");
  List<BluetoothDevice> systemDevices = await FlutterBluePlus.systemDevices([]);

  for (var d in systemDevices) {
    print("[BLE] System device: id=${d.remoteId} name='${d.platformName}'");
  }

  BluetoothDevice? watch;
  for (var d in systemDevices) {
    if (d.platformName.toUpperCase().contains("XWATCH")) {
      watch = d;
      break;
    }
  }

  if (watch == null) {
    print("[BLE] XWatch H4 gak ketemu di system devices. Pastikan udah pernah di-pair via Settings Bluetooth HP.");
    return;
  }

  print("[BLE] Ketemu di system: ${watch.platformName}. Connecting...");
  await watch.connect();
  print("[BLE] Connected. Discovering services...");
  _discoverHeartRate(watch);
}

  Future<void> _discoverHeartRate(BluetoothDevice device) async {
  List<BluetoothService> services = await device.discoverServices();
  print("[BLE] Jumlah service ditemukan: ${services.length}");
  for (var service in services) {
    print("[BLE] Service: ${service.uuid}");
    if (service.uuid.toString().toLowerCase() == "180d") {
      print("[BLE] Heart Rate service ketemu!");
      for (var char in service.characteristics) {
        print("[BLE] Char di dalam HR service: ${char.uuid}");
        if (char.uuid.toString().toLowerCase() == "2a37") {
  print("[BLE] Subscribing ke Heart Rate Measurement...");
  await char.setNotifyValue(true);
  char.lastValueStream.listen((value) {
    int? bpm = _parseHeartRate(value);
    if (bpm != null) {
      print("[BLE] BPM: $bpm");
    }
  });
}
        }
      }
    }
  }
}

  int? _parseHeartRate(List<int> value) {
  if (value.isEmpty) {
    print("[BLE] Notifikasi kosong, dilewati.");
    return null;
  }
  int flags = value[0];
  bool isUint16 = (flags & 0x01) == 1;
  if (isUint16) {
    if (value.length < 3) return null;
    return value[1] | (value[2] << 8);
  } else {
    if (value.length < 2) return null;
    return value[1];
  }
}