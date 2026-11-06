import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/event_note_screen.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/screens/main_navigation_screen.dart';
import 'package:siband/screens/profile_screen.dart';
import 'package:siband/services/auth_service.dart';
import 'package:siband/services/config_service.dart';
import 'package:siband/services/heart_rate_service.dart';

class _MockProfileHttpOverrides extends HttpOverrides {
  final Future<void> Function(HttpClientRequest request) onRequest;
  _MockProfileHttpOverrides(this.onRequest);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient(onRequest);
  }
}

class _FakeHttpClient implements HttpClient {
  final Future<void> Function(HttpClientRequest request) onRequest;
  _FakeHttpClient(this.onRequest);

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeHttpClientRequest(method, url, onRequest);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  final Future<void> Function(HttpClientRequest request) onRequest;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();
  final BytesBuilder _body = BytesBuilder();

  int responseStatusCode = 200;
  String responseBody = '{}';

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  int contentLength = -1;

  _FakeHttpClientRequest(this.method, this.uri, this.onRequest);

  String get bodyText => utf8.decode(_body.toBytes());

  @override
  void add(List<int> data) {
    _body.add(data);
  }

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _body.add(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    await onRequest(this);
    return _FakeHttpClientResponse(responseStatusCode, utf8.encode(responseBody));
  }

  @override
  late final Future<HttpClientResponse> done = close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final List<int> _bytes;

  _FakeHttpClientResponse(this.statusCode, this._bytes);

  @override
  int get contentLength => _bytes.length;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => true;
  @override
  String get reasonPhrase => 'OK';
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _map.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _map.forEach(action);
  }

  @override
  String? value(String name) => _map[name.toLowerCase()]?.first;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final mockChildren = [
    ChildModel(id: 1, userId: 1, nickname: 'Bima', birthYear: 2018),
  ];

  Widget buildTestable(Widget child, {Size size = const Size(412, 915)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child is Scaffold || child is MainNavigationScreen
            ? child
            : Scaffold(backgroundColor: const Color(0xFFF6F4EF), body: child),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    HeartRateService.instance.stop();
  });

  group('MainNavigationScreen & HomeScreen Tests', () {
    testWidgets('Renders MainNavigationScreen without overflow on 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(MainNavigationScreen(initialChildren: mockChildren), size: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MainNavigationScreen), findsOneWidget);
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Panduan'), findsOneWidget);
      expect(find.text('Rekap'), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets('Renders MainNavigationScreen without overflow on 412x915', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(MainNavigationScreen(initialChildren: mockChildren), size: const Size(412, 915)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Beranda'), findsOneWidget);
    });

    testWidgets('Bottom navigation switches tabs', (tester) async {
      await tester.pumpWidget(buildTestable(MainNavigationScreen(initialChildren: mockChildren)));
      await tester.pumpAndSettle();

      // Tap Panduan
      await tester.tap(find.text('Panduan'));
      await tester.pumpAndSettle();
      expect(find.text('Panduan menenangkan'), findsOneWidget);

      // Tap Rekap
      await tester.tap(find.text('Rekap'));
      await tester.pumpAndSettle();
      expect(find.text('Riwayat & Rekap'), findsOneWidget);

      // Tap GPS
      await tester.tap(find.text('GPS'));
      await tester.pumpAndSettle();
      expect(find.text('Segera hadir'), findsOneWidget);

      // Tap Profil
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Kelola anak'), findsOneWidget);
      expect(find.text('Sumber data'), findsOneWidget);
      expect(find.text('Layar teknis (lama)'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);

      // Return to Beranda
      await tester.tap(find.text('Beranda'));
      await tester.pumpAndSettle();
    });

    testWidgets('HomeScreen displays dummy monitoring data and elements', (tester) async {
      HeartRateService.instance.switchMode(Mode.dummy);

      await tester.pumpWidget(buildTestable(HomeScreen(initialChildren: mockChildren, initialUserName: 'Bunda')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Greeting
      expect(find.textContaining('Bunda'), findsOneWidget);
      expect(find.textContaining('Bima'), findsAtLeastNWidgets(1));

      // Banner text
      expect(find.text('Yuk Memahami Anak'), findsOneWidget);

      // Check monitoring elements
      expect(find.text('PEMANTAUAN DETAK JANTUNG'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.text('Data demo · tersambung'), findsOneWidget);

      // Trend card
      expect(find.text('Tren detak jantung'), findsOneWidget);
      expect(find.text('Rata-rata per jam · bukan diagnosis'), findsOneWidget);

      // Event note button & warning text
      expect(find.text('+ Catatan kejadian'), findsOneWidget);
      expect(find.text('Perubahan detak jantung bukan bukti stres.'), findsOneWidget);
    });

    testWidgets('HomeScreen displays Tambah anak when no children exist', (tester) async {
      await tester.pumpWidget(buildTestable(const HomeScreen(initialChildren: [])));
      await tester.pumpAndSettle();

      expect(find.text('Tambah anak'), findsOneWidget);
      expect(find.text('Tambah Anak'), findsOneWidget);
    });

    testWidgets('Tapping notification icon shows SnackBar', (tester) async {
      await tester.pumpWidget(buildTestable(HomeScreen(initialChildren: mockChildren)));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Notifikasi'));
      await tester.pump();

      expect(find.text('Notifikasi belum tersedia'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('Banner tap triggers navigation to Panduan', (tester) async {
      bool navigated = false;
      await tester.pumpWidget(buildTestable(HomeScreen(
        initialChildren: mockChildren,
        onNavigateToPanduan: () {
          navigated = true;
        },
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yuk Memahami Anak'));
      await tester.pumpAndSettle();

      expect(navigated, isTrue);
    });
  });

  group('EventNoteScreen Tests', () {
    testWidgets('Renders EventNoteScreen and does not overflow on 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(const EventNoteScreen(childId: 1), size: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Catatan kejadian'), findsOneWidget);
      expect(find.text('Tambahkan konteks untuk memahami perubahan detak jantung.'), findsOneWidget);
      expect(find.text('WAKTU KEJADIAN'), findsOneWidget);
      expect(find.text('Apa yang terjadi?'), findsOneWidget);
      expect(find.text('Suara keras'), findsOneWidget);
      expect(find.text('Perubahan aktivitas'), findsOneWidget);
      expect(find.text('Transisi kegiatan'), findsOneWidget);
      expect(find.text('Aktivitas sulit'), findsOneWidget);
      expect(find.text('Interaksi sosial'), findsOneWidget);
      expect(find.text('Lainnya'), findsOneWidget);
      expect(find.text('Catatan tambahan (opsional)'), findsOneWidget);
      expect(find.text('Simpan catatan'), findsOneWidget);
    });

    testWidgets('Renders EventNoteScreen and does not overflow on 412x915', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(const EventNoteScreen(childId: 1), size: const Size(412, 915)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Catatan kejadian'), findsOneWidget);
    });

    testWidgets('Event note selection changes active tile and typing works', (tester) async {
      await tester.pumpWidget(buildTestable(const EventNoteScreen(childId: 1)));
      await tester.pumpAndSettle();

      // Tap "Perubahan aktivitas"
      await tester.tap(find.text('Perubahan aktivitas'));
      await tester.pumpAndSettle();

      // Enter text into additional notes
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Anak tampak gelisah setelah mendengar pengumuman');
      await tester.pumpAndSettle();

      expect(find.text('Anak tampak gelisah setelah mendengar pengumuman'), findsOneWidget);

      // Verify Button & Semantics
      expect(find.widgetWithText(ElevatedButton, 'Simpan catatan'), findsOneWidget);
      expect(find.bySemanticsLabel('Kembali'), findsOneWidget);
    });
  });

  group('MainNavigationScreen with Anak Demo & Error States Tests', () {
    final anakDemoChildren = [
      ChildModel(id: 1, userId: 1, nickname: 'Anak Demo', birthYear: 2018),
    ];

    testWidgets('Layar utama dengan data tiruan Anak Demo memverifikasi nama anak, PEMANTAUAN DETAK JANTUNG, dan bar navigasi di 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(
        MainNavigationScreen(initialChildren: anakDemoChildren),
        size: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Anak Demo'), findsAtLeastNWidgets(1));
      expect(find.text('PEMANTAUAN DETAK JANTUNG'), findsOneWidget);
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Panduan'), findsOneWidget);
      expect(find.text('Rekap'), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets('Layar utama dengan data tiruan Anak Demo memverifikasi nama anak, PEMANTAUAN DETAK JANTUNG, dan bar navigasi di 412x915', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(
        MainNavigationScreen(initialChildren: anakDemoChildren),
        size: const Size(412, 915),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Anak Demo'), findsAtLeastNWidgets(1));
      expect(find.text('PEMANTAUAN DETAK JANTUNG'), findsOneWidget);
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Panduan'), findsOneWidget);
      expect(find.text('Rekap'), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets('Layar utama dalam kondisi error menampilkan pesan error dan tombol Coba lagi di 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(
        const MainNavigationScreen(
          initialErrorMessage: 'Gagal memuat data anak. Periksa koneksi internet Anda.',
        ),
        size: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Terjadi kesalahan'), findsOneWidget);
      expect(find.text('Gagal memuat data anak. Periksa koneksi internet Anda.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Coba lagi'), findsOneWidget);
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Panduan'), findsOneWidget);
      expect(find.text('Rekap'), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets('Layar utama dalam kondisi error menampilkan pesan error dan tombol Coba lagi di 412x915', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(
        const MainNavigationScreen(
          initialErrorMessage: 'Gagal memuat data anak. Periksa koneksi internet Anda.',
        ),
        size: const Size(412, 915),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Terjadi kesalahan'), findsOneWidget);
      expect(find.text('Gagal memuat data anak. Periksa koneksi internet Anda.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Coba lagi'), findsOneWidget);
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets('Tombol Coba lagi pada kondisi error memicu reload data anak hingga berhasil', (tester) async {
      bool retried = false;
      await tester.pumpWidget(buildTestable(
        MainNavigationScreen(
          initialErrorMessage: 'Koneksi terputus',
          onFetchChildren: () async {
            retried = true;
            return anakDemoChildren;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Terjadi kesalahan'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Coba lagi'), findsOneWidget);

      final retryBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Coba lagi'));
      retryBtn.onPressed?.call();
      await tester.pumpAndSettle();

      expect(retried, isTrue);
      expect(find.textContaining('Anak Demo'), findsAtLeastNWidgets(1));
      expect(find.text('PEMANTAUAN DETAK JANTUNG'), findsOneWidget);
    });
  });

  group('ProfileScreen Tests', () {
    testWidgets('Renders ProfileScreen options', (tester) async {
      await tester.pumpWidget(buildTestable(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Informasi pendamping'), findsOneWidget);
      expect(find.text('Kelola anak'), findsOneWidget);
      expect(find.text('Sumber data'), findsOneWidget);
      expect(find.text('Layar teknis (lama)'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
    });

    const profileTestSizes = [
      Size(360, 640),
      Size(412, 915),
      Size(1280, 720),
    ];

    for (final size in profileTestSizes) {
      testWidgets(
        'Tab Profil tata letak di ${size.width.toInt()}x${size.height.toInt()}: bar bawah menempel & <=96, Edit profil & Keluar terlihat setelah scroll',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            HttpOverrides.global = null;
          });

          SharedPreferences.setMockInitialValues({
            AuthService.tokenKey: 'mock_token',
            ConfigService.apiBaseUrlKey: 'http://127.0.0.1:8000/api',
          });

          HttpOverrides.global = _MockProfileHttpOverrides((req) async {
            final fakeReq = req as _FakeHttpClientRequest;
            if (req.uri.path.endsWith('/user')) {
              fakeReq.responseStatusCode = 200;
              fakeReq.responseBody = jsonEncode({
                'name': 'Bunda Sari',
                'email': 'sari@example.com',
              });
            } else if (req.uri.path.endsWith('/children')) {
              fakeReq.responseStatusCode = 200;
              fakeReq.responseBody = jsonEncode([
                {'id': 1, 'user_id': 1, 'nickname': 'Bima', 'birth_year': 2018},
              ]);
            } else {
              fakeReq.responseStatusCode = 200;
              fakeReq.responseBody = '[]';
            }
          });

          await tester.pumpWidget(
            buildTestable(
              MainNavigationScreen(
                initialIndex: 4,
                initialChildren: mockChildren,
                onFetchChildren: () async => mockChildren,
              ),
              size: size,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          final mainScaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
          expect(mainScaffold.bottomNavigationBar, isNotNull);
          final bottomNavFinder = find.byWidget(mainScaffold.bottomNavigationBar!);
          final bottomNavRect = tester.getRect(bottomNavFinder);

          expect(bottomNavRect.height, lessThanOrEqualTo(96.0));
          expect(bottomNavRect.bottom, equals(size.height));

          final bodyFinder = find.byType(IndexedStack);
          final bodyRect = tester.getRect(bodyFinder);
          expect(bodyRect.height, greaterThan(0));
          expect(bodyRect.bottom, lessThanOrEqualTo(bottomNavRect.top));

          // Pastikan tombol Edit profil terlihat di dalam layar
          final editBtnFinder = find.widgetWithText(TextButton, 'Edit profil');
          expect(editBtnFinder, findsOneWidget);
          await tester.ensureVisible(editBtnFinder);
          await tester.pumpAndSettle();
          final editRect = tester.getRect(editBtnFinder);
          expect(editRect.top, greaterThanOrEqualTo(0));
          expect(editRect.bottom, lessThanOrEqualTo(bottomNavRect.top));

          // Pastikan tombol Keluar terlihat di dalam layar setelah scroll
          final keluarBtnFinder = find.widgetWithText(ElevatedButton, 'Keluar');
          expect(keluarBtnFinder, findsOneWidget);
          await tester.ensureVisible(keluarBtnFinder);
          await tester.pumpAndSettle();
          final keluarRect = tester.getRect(keluarBtnFinder);
          expect(keluarRect.top, greaterThanOrEqualTo(0));
          expect(keluarRect.bottom, lessThanOrEqualTo(bottomNavRect.top));
        },
      );
    }

    testWidgets(
      'Profil menampilkan nama anak HURUF BESAR, umur dari birth_year, informasi pendamping, dan tanpa teks sekolah / Siswa SLB',
      (tester) async {
        addTearDown(() {
          HttpOverrides.global = null;
        });

        SharedPreferences.setMockInitialValues({
          AuthService.tokenKey: 'mock_token',
          ConfigService.apiBaseUrlKey: 'http://127.0.0.1:8000/api',
        });

        HttpOverrides.global = _MockProfileHttpOverrides((req) async {
          final fakeReq = req as _FakeHttpClientRequest;
          if (req.uri.path.endsWith('/user')) {
            fakeReq.responseStatusCode = 200;
            fakeReq.responseBody = jsonEncode({
              'name': 'Ibu Ratna',
              'email': 'ratna@example.com',
            });
          } else if (req.uri.path.endsWith('/children')) {
            fakeReq.responseStatusCode = 200;
            fakeReq.responseBody = jsonEncode([
              {'id': 7, 'user_id': 1, 'nickname': 'Arka', 'birth_year': 2019},
            ]);
          }
        });

        await tester.pumpWidget(buildTestable(const ProfileScreen()));
        await tester.pumpAndSettle();

        final expectedAge = DateTime.now().year - 2019;
        expect(find.text('ARKA'), findsOneWidget);
        expect(find.text('$expectedAge tahun'), findsOneWidget);
        expect(find.text('Ibu Ratna'), findsOneWidget);
        expect(find.text('ratna@example.com'), findsOneWidget);
        expect(find.textContaining('Siswa SLB'), findsNothing);
        expect(find.textContaining('SLB'), findsNothing);
        expect(find.textContaining('Sekolah'), findsNothing);
      },
    );

    testWidgets(
      'Edit profil memvalidasi input tidak valid dan memanggil updateChild dengan nilai benar',
      (tester) async {
        addTearDown(() {
          HttpOverrides.global = null;
        });

        SharedPreferences.setMockInitialValues({
          AuthService.tokenKey: 'mock_token',
          ConfigService.apiBaseUrlKey: 'http://127.0.0.1:8000/api',
        });

        String currentNickname = 'Bima';
        int currentBirthYear = 2018;
        String? putMethod;
        String? putPath;
        Map<String, dynamic>? putPayload;

        HttpOverrides.global = _MockProfileHttpOverrides((req) async {
          final fakeReq = req as _FakeHttpClientRequest;
          if (req.uri.path.endsWith('/user')) {
            fakeReq.responseStatusCode = 200;
            fakeReq.responseBody = jsonEncode({
              'name': 'Orang Tua',
              'email': 'ortu@example.com',
            });
          } else if (req.method == 'GET' && req.uri.path.endsWith('/children')) {
            fakeReq.responseStatusCode = 200;
            fakeReq.responseBody = jsonEncode([
              {
                'id': 10,
                'user_id': 1,
                'nickname': currentNickname,
                'birth_year': currentBirthYear,
              },
            ]);
          } else if (req.method == 'PUT' && req.uri.path.endsWith('/children/10')) {
            putMethod = req.method;
            putPath = req.uri.path;
            putPayload = jsonDecode(fakeReq.bodyText) as Map<String, dynamic>;
            currentNickname = putPayload!['nickname'].toString();
            currentBirthYear = putPayload!['birth_year'] as int;
            fakeReq.responseStatusCode = 200;
            fakeReq.responseBody = jsonEncode({
              'id': 10,
              'user_id': 1,
              'nickname': currentNickname,
              'birth_year': currentBirthYear,
            });
          }
        });

        await tester.pumpWidget(buildTestable(const ProfileScreen()));
        await tester.pumpAndSettle();

        expect(find.text('BIMA'), findsOneWidget);

        // Buka bottom sheet Edit profil
        await tester.tap(find.widgetWithText(TextButton, 'Edit profil'));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        expect(textFields, findsNWidgets(2));
        expect(find.text('Kelola anak'), findsAtLeastNWidgets(1));

        // 1. Validasi nama kosong ditolak
        await tester.enterText(textFields.at(0), '   ');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();
        expect(find.text('Nama tidak boleh kosong'), findsOneWidget);
        expect(putPayload, isNull);

        // 2. Validasi tahun di luar rentang (< 1900 dan > tahun sekarang) ditolak
        await tester.enterText(textFields.at(0), 'Damar');
        await tester.enterText(textFields.at(1), '1850');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();
        expect(find.text('Masukkan tahun yang valid'), findsOneWidget);
        expect(putPayload, isNull);

        final nextYear = DateTime.now().year + 1;
        await tester.enterText(textFields.at(1), nextYear.toString());
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();
        expect(find.text('Masukkan tahun yang valid'), findsOneWidget);
        expect(putPayload, isNull);

        // 3. Input valid memanggil PUT /api/children/10 dan memperbarui kartu profil
        await tester.enterText(textFields.at(0), 'Damar');
        await tester.enterText(textFields.at(1), '2020');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        expect(putMethod, equals('PUT'));
        expect(putPath, endsWith('/children/10'));
        expect(putPayload, isNotNull);
        expect(putPayload!['nickname'], equals('Damar'));
        expect(putPayload!['birth_year'], equals(2020));

        final expectedUpdatedAge = DateTime.now().year - 2020;
        expect(find.text('DAMAR'), findsOneWidget);
        expect(find.text('$expectedUpdatedAge tahun'), findsOneWidget);
      },
    );
  });
}

