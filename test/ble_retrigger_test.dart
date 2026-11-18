import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/screens/pair_device_screen.dart';
import 'package:siband/services/api_service.dart';
import 'package:siband/services/heart_rate_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'test-token',
      'active_child_id': 1,
    });
  });

  tearDown(() {
    HeartRateService.instance.switchMode(Mode.dummy);
    HeartRateService.instance.stop();
  });

  test(
    'Pemulihan BLE bertahap memanggil retrigger di 4 & 5 menit, reconnect di 6 menit, lalu needsDeviceRepair di 7 menit',
    () async {
      int retriggerCount = 0;
      int reconnectCount = 0;

      final service = HeartRateService.forTesting(
        onRetrigger: () async {
          retriggerCount++;
        },
        onReconnect: () async {
          reconnectCount++;
        },
      );

      service.setBleTestState(
        mode: Mode.ble,
        bleState: BluetoothConnectionState.connected,
        bpm: 82,
        lastBpmReceivedAt: DateTime.now(),
        secondsSinceLastBpm: 0,
      );

      await service.evaluateBleRecoveryForTest(239);
      expect(retriggerCount, 0);
      expect(reconnectCount, 0);
      expect(service.needsDeviceRepair, isFalse);

      // 4 menit (240 detik) -> retrigger ke-1, tidak berulang di 241 detik
      await service.evaluateBleRecoveryForTest(240);
      await service.evaluateBleRecoveryForTest(241);
      expect(retriggerCount, 1);
      expect(reconnectCount, 0);
      expect(service.needsDeviceRepair, isFalse);

      // 5 menit (300 detik) -> retrigger ke-2, tidak berulang di 301 detik
      await service.evaluateBleRecoveryForTest(300);
      await service.evaluateBleRecoveryForTest(301);
      expect(retriggerCount, 2);
      expect(reconnectCount, 0);
      expect(service.needsDeviceRepair, isFalse);

      // 6 menit (360 detik) -> reconnect 1x, tidak berulang di 361 detik
      await service.evaluateBleRecoveryForTest(360);
      await service.evaluateBleRecoveryForTest(361);
      expect(retriggerCount, 2);
      expect(reconnectCount, 1);
      expect(service.needsDeviceRepair, isFalse);

      // 7 menit (420 detik) -> berhenti mencoba & tandai perlu pasang ulang
      await service.evaluateBleRecoveryForTest(420);
      await service.evaluateBleRecoveryForTest(421);
      expect(retriggerCount, 2);
      expect(reconnectCount, 1);
      expect(service.needsDeviceRepair, isTrue);
      expect(service.bleStatus, 'Perlu hubungkan ulang perangkat');

      // Saat ada pembacaan baru, state pemulihan di-reset
      service.setBleTestState(
        mode: Mode.ble,
        bleState: BluetoothConnectionState.connected,
        bpm: 80,
        lastBpmReceivedAt: DateTime.now(),
        secondsSinceLastBpm: 0,
      );
      expect(service.needsDeviceRepair, isFalse);

      await service.evaluateBleRecoveryForTest(240);
      expect(retriggerCount, 3);
    },
  );

  testWidgets(
    'HomeScreen menampilkan tombol Pasang ulang perangkat saat needsDeviceRepair aktif dan membuka PairDeviceScreen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/heart-rate')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response(jsonEncode({'message': 'Not found'}), 404);
      });

      final apiService = ApiService(client: client);
      final mockChildren = [
        ChildModel(id: 1, userId: 1, nickname: 'Bima', birthYear: 2018),
      ];

      HeartRateService.instance.setBleTestState(
        mode: Mode.ble,
        bleState: BluetoothConnectionState.connected,
        bpm: 80,
        lastBpmReceivedAt: DateTime.now().subtract(const Duration(minutes: 8)),
        secondsSinceLastBpm: 480,
        needsDeviceRepair: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              apiService: apiService,
              initialChildren: mockChildren,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Data tidak terbaru'), findsOneWidget);
      final repairButton = find.text('Pasang ulang perangkat');
      expect(repairButton, findsOneWidget);

      await tester.ensureVisible(repairButton);
      await tester.tap(repairButton);
      await tester.pumpAndSettle();

      expect(find.byType(PairDeviceScreen), findsOneWidget);
    },
  );
}
