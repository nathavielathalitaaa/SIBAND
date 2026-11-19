import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/screens/pair_device_screen.dart';
import 'package:siband/services/heart_rate_service.dart';
import 'package:siband/widgets/watch_status_chip.dart';

/// Seam uji minimal turunan [HeartRateService.forTesting] tanpa mengubah lib/services/.
class _FakeHeartRateService extends HeartRateService {
  _FakeHeartRateService() : super.forTesting();

  int? fakeActiveDeviceId;
  String? fakePairedDeviceName;
  Mode fakeMode = Mode.dummy;
  bool fakeIsConnectingBle = false;
  BluetoothDevice? fakeConnectedDevice;
  BluetoothConnectionState fakeBleState = BluetoothConnectionState.connected;
  DateTime? fakeLastBpmReceivedAt;
  int fakeSecondsSinceLastBpm = 0;
  int fakeCurrentBpm = 78;

  @override
  int? get activeDeviceId => fakeActiveDeviceId;

  @override
  String? get pairedDeviceName => fakePairedDeviceName;

  @override
  Mode get currentMode => fakeMode;

  @override
  bool get isConnectingBle => fakeIsConnectingBle;

  @override
  BluetoothDevice? get connectedDevice => fakeConnectedDevice;

  @override
  BluetoothConnectionState get currentBleState => fakeBleState;

  @override
  DateTime? get lastBpmReceivedAt => fakeLastBpmReceivedAt;

  @override
  int get secondsSinceLastBpm => fakeSecondsSinceLastBpm;

  @override
  int get currentBpm => fakeCurrentBpm;

  @override
  void start() {}

  @override
  void stop() {}

  void notify() => notifyListeners();
}

void main() {
  final mockChildren = [
    ChildModel(id: 1, userId: 1, nickname: 'Bima', birthYear: 2018),
  ];

  final dummyBleDevice = BluetoothDevice(
    remoteId: const DeviceIdentifier('AA:BB:CC:DD:EE:FF'),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({'active_child_id': 1});
  });

  tearDown(() {
    HeartRateService.instance.switchMode(Mode.dummy);
    HeartRateService.instance.stop();
  });

  testWidgets(
    '(a) tiap keadaan a-f menampilkan teks, titik indikator, semantics, dan lebar <= 150 yang benar',
    (tester) async {
      final fake = _FakeHeartRateService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WatchStatusChip(heartRateService: fake),
            ),
          ),
        ),
      );

      // a. Belum ada jam terpasang -> "Pasang jam"
      expect(find.text('Pasang jam'), findsOneWidget);
      expect(find.bySemanticsLabel('Status jam: pasang jam'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('watch_status_chip'))).width,
        lessThanOrEqualTo(150.0),
      );

      // b. Mode Dummy dengan jam terpasang -> "Simulasi" (tanpa titik hijau)
      fake
        ..fakeActiveDeviceId = 10
        ..fakePairedDeviceName = 'Infinix XWatch H4'
        ..fakeMode = Mode.dummy
        ..fakeBleState = BluetoothConnectionState.connected
        ..notify();
      await tester.pump();

      expect(find.text('Simulasi'), findsOneWidget);
      expect(find.bySemanticsLabel('Status jam: simulasi'), findsOneWidget);
      expect(find.byKey(const Key('watch_chip_dot_green')), findsNothing);

      // c. isConnectingBle true -> "Menghubungkan…", titik berdenyut
      fake
        ..fakeMode = Mode.ble
        ..fakeIsConnectingBle = true
        ..notify();
      await tester.pump();

      expect(find.text('Menghubungkan…'), findsOneWidget);
      expect(find.bySemanticsLabel('Status jam: menghubungkan'), findsOneWidget);
      expect(
        find.byKey(const Key('watch_chip_dot_connecting')),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isTrue);

      // d. Mode BLE, connectedDevice != null, connected, bacaan segar -> "Terhubung", titik hijau
      fake
        ..fakeIsConnectingBle = false
        ..fakeConnectedDevice = dummyBleDevice
        ..fakeBleState = BluetoothConnectionState.connected
        ..fakeLastBpmReceivedAt = DateTime.now()
        ..fakeCurrentBpm = 84
        ..fakeSecondsSinceLastBpm = 12
        ..notify();
      await tester.pump();

      expect(find.text('Terhubung'), findsOneWidget);
      expect(find.bySemanticsLabel('Status jam: terhubung'), findsOneWidget);
      expect(find.byKey(const Key('watch_chip_dot_green')), findsOneWidget);

      // e. Mode BLE, connected, tetapi bacaan tidak segar (> staleAfterSeconds) -> "Terhubung · menunggu data", titik amber
      fake
        ..fakeSecondsSinceLastBpm = 500
        ..notify();
      await tester.pump();

      expect(find.text('Terhubung · menunggu data'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Status jam: terhubung, menunggu data'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('watch_chip_dot_amber')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('watch_status_chip'))).width,
        lessThanOrEqualTo(150.0),
      );

      // f. Selain itu (terputus) -> "Jam terputus", titik abu-abu
      fake
        ..fakeBleState = BluetoothConnectionState.disconnected
        ..notify();
      await tester.pump();

      expect(find.text('Jam terputus'), findsOneWidget);
      expect(find.bySemanticsLabel('Status jam: jam terputus'), findsOneWidget);
      expect(find.byKey(const Key('watch_chip_dot_grey')), findsOneWidget);
    },
  );

  testWidgets(
    '(b) Mode Dummy TIDAK PERNAH menampilkan Terhubung walau currentBleState connected dan connectedDevice ada',
    (tester) async {
      final fake = _FakeHeartRateService()
        ..fakeActiveDeviceId = 1
        ..fakePairedDeviceName = 'XWatch H4'
        ..fakeMode = Mode.dummy
        ..fakeConnectedDevice = dummyBleDevice
        ..fakeBleState = BluetoothConnectionState.connected
        ..fakeLastBpmReceivedAt = DateTime.now()
        ..fakeCurrentBpm = 80
        ..fakeSecondsSinceLastBpm = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatchStatusChip(heartRateService: fake),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Simulasi'), findsOneWidget);
      expect(find.text('Terhubung'), findsNothing);
      expect(find.byKey(const Key('watch_chip_dot_green')), findsNothing);
    },
  );

  testWidgets(
    '(c) tanpa jam terpasang TIDAK PERNAH menampilkan Terhubung walau BLE connected dan bacaan segar',
    (tester) async {
      final fake = _FakeHeartRateService()
        ..fakeActiveDeviceId = null
        ..fakePairedDeviceName = null
        ..fakeMode = Mode.ble
        ..fakeConnectedDevice = dummyBleDevice
        ..fakeBleState = BluetoothConnectionState.connected
        ..fakeLastBpmReceivedAt = DateTime.now()
        ..fakeCurrentBpm = 85
        ..fakeSecondsSinceLastBpm = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatchStatusChip(heartRateService: fake),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pasang jam'), findsOneWidget);
      expect(find.text('Terhubung'), findsNothing);
    },
  );

  for (final size in const [
    Size(360, 640),
    Size(412, 915),
    Size(1280, 720),
  ]) {
    testWidgets(
      '(d) chip terlihat di header Beranda pada ${size.width.toInt()}x${size.height.toInt()}, tepi kanan di dalam layar, tanpa overflow',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final fake = _FakeHeartRateService()
          ..fakeActiveDeviceId = 1
          ..fakePairedDeviceName = 'Infinix XWatch H4'
          ..fakeMode = Mode.ble
          ..fakeConnectedDevice = dummyBleDevice
          ..fakeBleState = BluetoothConnectionState.connected
          ..fakeLastBpmReceivedAt = DateTime.now()
          ..fakeCurrentBpm = 80
          ..fakeSecondsSinceLastBpm = 500; // label terpanjang: "Terhubung · menunggu data"

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: Scaffold(
                body: HomeScreen(
                  initialChildren: mockChildren,
                  heartRateService: fake,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final chipFinder = find.byKey(const Key('watch_status_chip'));
        expect(chipFinder, findsOneWidget);

        final chipRect = tester.getRect(chipFinder);
        expect(chipRect.width, greaterThan(0));
        expect(chipRect.width, lessThanOrEqualTo(150.0));
        expect(chipRect.left, greaterThanOrEqualTo(0));
        expect(chipRect.right, lessThanOrEqualTo(size.width));
      },
    );
  }

  testWidgets(
    '(e) mengetuk chip membuka bottom sheet Status jam dan tombol Pasang atau ganti jam membuka PairDeviceScreen',
    (tester) async {
      const size = Size(360, 640);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fake = _FakeHeartRateService()
        ..fakeActiveDeviceId = 1
        ..fakePairedDeviceName = 'Infinix XWatch H4'
        ..fakeMode = Mode.ble
        ..fakeConnectedDevice = dummyBleDevice
        ..fakeBleState = BluetoothConnectionState.connected
        ..fakeLastBpmReceivedAt = DateTime.now()
        ..fakeCurrentBpm = 82
        ..fakeSecondsSinceLastBpm = 15;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              initialChildren: mockChildren,
              heartRateService: fake,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('watch_status_chip')));
      await tester.pumpAndSettle();

      expect(find.text('Status jam'), findsOneWidget);
      expect(find.text('Infinix XWatch H4'), findsOneWidget);
      expect(
        find.text('Jam terhubung dan mengirim bacaan detak jantung terbaru.'),
        findsOneWidget,
      );
      expect(find.text('Data terakhir: 15 detik lalu'), findsOneWidget);

      final pairBtn = find.widgetWithText(
        ElevatedButton,
        'Pasang atau ganti jam',
      );
      expect(pairBtn, findsOneWidget);

      await tester.tap(pairBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PairDeviceScreen), findsOneWidget);
    },
  );
}
