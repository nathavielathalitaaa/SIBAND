import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:siband/models/child_model.dart';
import 'package:siband/screens/login_screen.dart';
import 'package:siband/screens/onboarding_screen.dart';
import 'package:siband/screens/pair_device_screen.dart';
import 'package:siband/screens/register_screen.dart';
import 'package:siband/services/api_service.dart';
import 'package:siband/services/auth_service.dart';
import 'package:siband/services/heart_rate_service.dart';

Widget buildTestable(Widget child, {Size size = const Size(360, 640)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AuthService.tokenKey: 'test_token_123',
    });
    HeartRateService.instance.clearPairedDevice();
  });

  group('PairDeviceScreen Widget Tests', () {
    final mockChild = ChildModel(
      id: 1,
      userId: 1,
      nickname: 'Bima',
      birthYear: 2018,
    );

    testWidgets('Daftar jam contoh dan banner mode contoh tampil di non-Android pada 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(
        PairDeviceScreen(
          childId: mockChild.id,
          childNickname: mockChild.nickname,
          isAndroidOverride: false,
        ),
        size: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Pasang jam'), findsOneWidget);
      expect(find.text('Pilih jam yang sudah terhubung lewat Bluetooth HP.'), findsOneWidget);
      expect(find.text('Mode contoh: Bluetooth tidak tersedia di perangkat ini'), findsOneWidget);
      expect(find.text('Infinix XWatch H4 (contoh)'), findsOneWidget);
      expect(find.text('AA:BB:••:••:EE:FF'), findsOneWidget);
      expect(find.text('Pasang ke Bima'), findsOneWidget);
    });

    testWidgets('Tampil tanpa overflow pada ukuran layar 412x915', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(
        PairDeviceScreen(
          childId: mockChild.id,
          childNickname: mockChild.nickname,
          isAndroidOverride: false,
        ),
        size: const Size(412, 915),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Pasang jam'), findsOneWidget);
      expect(find.text('Pasang ke Bima'), findsOneWidget);
    });

    testWidgets('Memilih jam lalu memasangkan memanggil POST /api/devices/pair dengan data benar', (tester) async {
      String? recordedMethod;
      String? recordedPath;
      Map<String, dynamic>? recordedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/devices/pair')) {
          recordedMethod = request.method;
          recordedPath = request.url.path;
          recordedBody = jsonDecode(request.body) as Map<String, dynamic>;

          return http.Response(
            jsonEncode({
              'id': 42,
              'name': recordedBody?['name'],
              'mac': recordedBody?['mac'],
              'child_id': recordedBody?['child_id'],
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"message": "Not Found"}', 404);
      });

      final apiService = ApiService(client: mockClient);

      await tester.pumpWidget(buildTestable(
        PairDeviceScreen(
          childId: mockChild.id,
          childNickname: mockChild.nickname,
          apiService: apiService,
          isAndroidOverride: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap the item to ensure it is selected
      await tester.tap(find.text('Infinix XWatch H4 (contoh)'));
      await tester.pumpAndSettle();

      // Tap "Pasang ke Bima"
      await tester.tap(find.text('Pasang ke Bima'));
      await tester.pump(); // Start pairing, spinner shown
      await tester.pumpAndSettle(); // Finish request and SnackBar

      expect(recordedMethod, 'POST');
      expect(recordedPath, contains('/devices/pair'));
      expect(recordedBody?['mac'], 'AA:BB:CC:DD:EE:FF');
      expect(recordedBody?['name'], 'Infinix XWatch H4 (contoh)');
      expect(recordedBody?['child_id'], 1);

      // Verify state saved in HeartRateService
      expect(HeartRateService.instance.activeDeviceId, 42);
      expect(HeartRateService.instance.pairedDeviceName, 'Infinix XWatch H4 (contoh)');
    });

    testWidgets('Pairing ulang jam ke anak lain memanggil pair dengan child_id baru', (tester) async {
      final child2 = ChildModel(id: 2, userId: 1, nickname: 'Siti', birthYear: 2020);
      Map<String, dynamic>? recordedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/devices/pair')) {
          recordedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 42,
              'name': recordedBody?['name'],
              'mac': recordedBody?['mac'],
              'child_id': recordedBody?['child_id'],
            }),
            200, // 200 re-assigned
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final apiService = ApiService(client: mockClient);

      await tester.pumpWidget(buildTestable(
        PairDeviceScreen(
          childId: child2.id,
          childNickname: child2.nickname,
          apiService: apiService,
          isAndroidOverride: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pasang ke Siti'), findsOneWidget);

      await tester.tap(find.text('Pasang ke Siti'));
      await tester.pumpAndSettle();

      expect(recordedBody?['child_id'], 2);
      expect(HeartRateService.instance.activeChildId, 2);
      expect(HeartRateService.instance.activeDeviceId, 42);
    });

    testWidgets('Kondisi kosong menampilkan pesan belum ada jam dan tombol Coba lagi', (tester) async {
      await tester.pumpWidget(buildTestable(
        PairDeviceScreen(
          childId: mockChild.id,
          childNickname: mockChild.nickname,
          initialDevices: const [], // Empty devices list
          isAndroidOverride: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Belum ada jam yang terpasang di HP ini. Pasangkan jam lewat pengaturan Bluetooth lebih dulu.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Coba lagi'), findsOneWidget);
    });

    testWidgets('Kondisi error menampilkan pesan error dan tombol Coba lagi', (tester) async {
      int fetchCallCount = 0;
      final mockClient = MockClient((request) async {
        fetchCallCount++;
        return http.Response('{"message": "Internal Server Error"}', 500);
      });

      await tester.pumpWidget(buildTestable(
        PairDeviceScreen(
          childId: mockChild.id,
          childNickname: mockChild.nickname,
          apiService: ApiService(client: mockClient),
          initialDevices: [
            const DiscoveredWatch(
              name: 'Jam Rusak',
              mac: '11:22:33:44:55:66',
            ),
          ],
          isAndroidOverride: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap pair to trigger error from server
      await tester.tap(find.text('Pasang ke Bima'));
      await tester.pumpAndSettle();

      expect(find.text('Internal Server Error'), findsOneWidget);
      expect(fetchCallCount, greaterThan(0));
    });

    testWidgets('Kondisi 401 Unauthenticated melakukan alur logout dan navigasi ke OnboardingScreen', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/devices/pair')) {
          return http.Response(
            '{"message": "Unauthenticated"}',
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final authService = AuthService(client: mockClient);
      final apiService = ApiService(authService: authService, client: mockClient);

      await tester.pumpWidget(MaterialApp(
        home: PairDeviceScreen(
          childId: mockChild.id,
          childNickname: mockChild.nickname,
          apiService: apiService,
          authService: authService,
          isAndroidOverride: false,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pasang ke Bima'));
      await tester.pumpAndSettle();

      // Verify navigated to OnboardingScreen
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });

  group('Timeout and Connection Error Tests', () {
    test('ApiService.pairDevice handles TimeoutException gracefully', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Koneksi timeout');
      });

      final apiService = ApiService(client: mockClient);
      final result = await apiService.pairDevice(
        mac: 'AA:BB:CC:DD:EE:FF',
        name: 'Device X',
        childId: 1,
      );

      expect(result['success'], false);
      expect(
        result['message'],
        'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
      );
    });

    test('ApiService.pairDevice handles SocketException gracefully', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Network unreachable');
      });

      final apiService = ApiService(client: mockClient);
      final result = await apiService.pairDevice(
        mac: 'AA:BB:CC:DD:EE:FF',
        name: 'Device X',
        childId: 1,
      );

      expect(result['success'], false);
      expect(
        result['message'],
        'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
      );
    });

    test('ApiService.getChildren handles TimeoutException with localized message', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });

      final apiService = ApiService(client: mockClient);
      expect(
        () => apiService.getChildren(),
        throwsA(
          predicate((e) =>
              e.toString().contains('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.')),
        ),
      );
    });

    test('ApiService.getChildren handles SocketException with localized message', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final apiService = ApiService(client: mockClient);
      expect(
        () => apiService.getChildren(),
        throwsA(
          predicate((e) =>
              e.toString().contains('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.')),
        ),
      );
    });

    test('AuthService.login handles TimeoutException and SocketException', () async {
      final timeoutClient = MockClient((request) async {
        throw TimeoutException('Timeout');
      });
      final authTimeout = AuthService(client: timeoutClient);
      final resTimeout = await authTimeout.login(email: 'a@b.com', password: 'password');
      expect(resTimeout['success'], false);
      expect(resTimeout['message'], 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');

      final socketClient = MockClient((request) async {
        throw const SocketException('Offline');
      });
      final authSocket = AuthService(client: socketClient);
      final resSocket = await authSocket.login(email: 'a@b.com', password: 'password');
      expect(resSocket['success'], false);
      expect(resSocket['message'], 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    });

    test('AuthService.register handles TimeoutException and SocketException', () async {
      final timeoutClient = MockClient((request) async {
        throw TimeoutException('Timeout');
      });
      final authTimeout = AuthService(client: timeoutClient);
      final resTimeout = await authTimeout.register(
        name: 'Budi',
        email: 'budi@mail.com',
        password: 'password',
        passwordConfirmation: 'password',
      );
      expect(resTimeout['success'], false);
      expect(resTimeout['message'], 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');

      final socketClient = MockClient((request) async {
        throw const SocketException('Offline');
      });
      final authSocket = AuthService(client: socketClient);
      final resSocket = await authSocket.register(
        name: 'Budi',
        email: 'budi@mail.com',
        password: 'password',
        passwordConfirmation: 'password',
      );
      expect(resSocket['success'], false);
      expect(resSocket['message'], 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    });

    testWidgets('LoginScreen menampilkan SnackBar saat timeout dan tombol login aktif kembali', (tester) async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Connection timed out');
      });

      final authService = AuthService(client: mockClient);

      await tester.pumpWidget(buildTestable(LoginScreen(authService: authService)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'bunda@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pumpAndSettle();

      // Tap LOGIN
      await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
      await tester.pump(); // starts loading
      await tester.pumpAndSettle(); // completes timeout handling

      // SnackBar with required error message
      expect(
        find.text('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.'),
        findsOneWidget,
      );

      // Loading indicator stopped, LOGIN button is active again
      expect(find.widgetWithText(ElevatedButton, 'LOGIN'), findsOneWidget);
    });

    testWidgets('RegisterScreen menampilkan SnackBar saat koneksi gagal dan tombol daftar aktif kembali', (tester) async {
      final mockClient = MockClient((request) async {
        throw const SocketException('No route to host');
      });

      final authService = AuthService(client: mockClient);

      await tester.pumpWidget(buildTestable(RegisterScreen(authService: authService)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Bunda Ani');
      await tester.enterText(find.byType(TextFormField).at(1), 'ani@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'password123');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'SIGN UP'));
      await tester.pump(); // starts loading
      await tester.pumpAndSettle(); // completes error handling

      expect(
        find.text('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.'),
        findsOneWidget,
      );

      // Loading indicator stopped, SIGN UP button active again
      expect(find.widgetWithText(ElevatedButton, 'SIGN UP'), findsOneWidget);
    });

    testWidgets('PairDeviceScreen menampilkan SnackBar saat timeout dan tombol pasang aktif kembali', (tester) async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Pair timeout');
      });

      final apiService = ApiService(client: mockClient);

      await tester.pumpWidget(buildTestable(
        PairDeviceScreen(
          childId: 1,
          childNickname: 'Bima',
          apiService: apiService,
          isAndroidOverride: false,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pasang ke Bima'));
      await tester.pump(); // spinner
      await tester.pumpAndSettle(); // timeout

      expect(
        find.text('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.'),
        findsOneWidget,
      );

      // Button is re-enabled with "Pasang ke Bima" text
      expect(find.widgetWithText(ElevatedButton, 'Pasang ke Bima'), findsOneWidget);
    });
  });
}
