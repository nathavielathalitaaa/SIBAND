import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/event_note_screen.dart';
import 'package:siband/screens/help_screen.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/screens/journal_privacy_screen.dart';
import 'package:siband/screens/location_screen.dart';
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
      expect(find.text('Lokasi anak'), findsOneWidget);

      // Tap Profil
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Preferensi pendampingan'), findsOneWidget);
      expect(find.text('Jurnal harian & pengaturan privasi'), findsOneWidget);
      expect(find.text('Pengingat jurnal & zona aman'), findsOneWidget);
      expect(find.text('Bantuan dan dukungan'), findsOneWidget);
      expect(find.text('Perangkat & sumber data'), findsOneWidget);
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
      expect(find.text('Preferensi pendampingan'), findsOneWidget);
      expect(find.text('Jurnal harian & pengaturan privasi'), findsOneWidget);
      expect(find.text('Pengingat jurnal & zona aman'), findsOneWidget);
      expect(find.text('Bantuan dan dukungan'), findsOneWidget);
      expect(find.text('Perangkat & sumber data'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
    });

    const profileTestSizes = [
      Size(360, 640),
      Size(412, 915),
      Size(1280, 720),
    ];

    for (final size in profileTestSizes) {
      testWidgets(
        'Tab Profil tata letak di ${size.width.toInt()}x${size.height.toInt()}: bar bawah menempel & <=96, 4 menu preferensi, Edit profil & Keluar terlihat setelah scroll',
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

          // Pastikan keempat baris menu ada dan masuk di dalam viewport setelah scroll
          for (final menuLabel in [
            'Jurnal harian & pengaturan privasi',
            'Pengingat jurnal & zona aman',
            'Bantuan dan dukungan',
            'Perangkat & sumber data',
          ]) {
            final menuFinder = find.text(menuLabel);
            expect(menuFinder, findsOneWidget);
            await tester.ensureVisible(menuFinder);
            await tester.pumpAndSettle();
            final menuRect = tester.getRect(menuFinder);
            expect(menuRect.top, greaterThanOrEqualTo(0));
            expect(menuRect.bottom, lessThanOrEqualTo(bottomNavRect.top));
          }

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
      'Keempat baris Preferensi pendampingan bisa diketuk, termasuk Perangkat & sumber data membuka Pasang jam',
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
            fakeReq.responseBody = jsonEncode({'name': 'Bunda', 'email': 'bunda@example.com'});
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

        await tester.pumpWidget(buildTestable(const ProfileScreen()));
        await tester.pumpAndSettle();

        // 1. Jurnal harian & pengaturan privasi
        await tester.ensureVisible(find.text('Jurnal harian & pengaturan privasi'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Jurnal harian & pengaturan privasi'));
        await tester.pumpAndSettle();
        expect(find.byType(JournalPrivacyScreen), findsOneWidget);
        expect(find.text('Jurnal catatan kejadian'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        // 2. Pengingat jurnal & zona aman
        await tester.ensureVisible(find.text('Pengingat jurnal & zona aman'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pengingat jurnal & zona aman'));
        await tester.pumpAndSettle();
        expect(find.text('Segera hadir'), findsAtLeastNWidgets(1));
        expect(find.text('Pengingat dan zona aman belum tersedia pada prototipe.'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        // 3. Bantuan dan dukungan
        await tester.ensureVisible(find.text('Bantuan dan dukungan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bantuan dan dukungan'));
        await tester.pumpAndSettle();
        expect(find.byType(HelpScreen), findsOneWidget);
        expect(find.text('Cara kerja singkat'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        // 4. Perangkat & sumber data -> memuat Pasang jam, Sumber data, Layar teknis (lama)
        await tester.ensureVisible(find.text('Perangkat & sumber data'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Perangkat & sumber data'));
        await tester.pumpAndSettle();
        expect(find.text('Sumber data'), findsOneWidget);
        expect(find.text('Pasang jam'), findsOneWidget);
        expect(find.text('Layar teknis (lama)'), findsOneWidget);
      },
    );

    testWidgets(
      'Layar jurnal menampilkan catatan kejadian, menolak hapus saat Batal, dan menghapus catatan saat dikonfirmasi',
      (tester) async {
        addTearDown(() {
          HttpOverrides.global = null;
        });

        SharedPreferences.setMockInitialValues({
          AuthService.tokenKey: 'mock_token',
          ConfigService.apiBaseUrlKey: 'http://127.0.0.1:8000/api',
        });

        final notesList = <Map<String, dynamic>>[
          {
            'id': 101,
            'child_id': 1,
            'type': 'suara_keras',
            'note': 'Suara petir sore hari',
            'occurred_at': '2026-11-05 16:30:00',
          },
          {
            'id': 102,
            'child_id': 1,
            'type': 'transisi',
            'note': 'Pindah dari bermain ke mandi',
            'occurred_at': '2026-11-05 17:00:00',
          },
        ];

        int? deletedNoteId;

        HttpOverrides.global = _MockProfileHttpOverrides((req) async {
          final fakeReq = req as _FakeHttpClientRequest;
          if (req.method == 'GET' && req.uri.path.endsWith('/children/1/event-notes')) {
            fakeReq.responseStatusCode = 200;
            fakeReq.responseBody = jsonEncode(notesList);
          } else if (req.method == 'DELETE' && req.uri.path.contains('/event-notes/')) {
            final idStr = req.uri.pathSegments.last;
            deletedNoteId = int.tryParse(idStr);
            notesList.removeWhere((n) => n['id'] == deletedNoteId);
            fakeReq.responseStatusCode = 200;
            fakeReq.responseBody = jsonEncode({'deleted': true});
          } else {
            fakeReq.responseStatusCode = 200;
            fakeReq.responseBody = '[]';
          }
        });

        await tester.pumpWidget(
          buildTestable(
            JournalPrivacyScreen(
              initialChild: mockChildren.first,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Suara keras'), findsOneWidget);
        expect(find.text('Suara petir sore hari'), findsOneWidget);
        expect(find.text('Transisi kegiatan'), findsOneWidget);
        expect(find.text('Pindah dari bermain ke mandi'), findsOneWidget);

        // Ketuk ikon hapus pada item pertama lalu pilih Batal
        final deleteIcons = find.byIcon(Icons.delete_outline_rounded);
        expect(deleteIcons, findsNWidgets(2));
        await tester.tap(deleteIcons.first);
        await tester.pumpAndSettle();

        expect(find.text('Hapus catatan?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Batal'));
        await tester.pumpAndSettle();

        expect(deletedNoteId, isNull);
        expect(find.text('Suara petir sore hari'), findsOneWidget);

        // Ketuk ikon hapus pada item pertama lalu konfirmasi Hapus
        await tester.tap(deleteIcons.first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
        await tester.pumpAndSettle();

        expect(deletedNoteId, equals(101));
        expect(find.text('Suara petir sore hari'), findsNothing);
        expect(find.text('Pindah dari bermain ke mandi'), findsOneWidget);
      },
    );

    testWidgets(
      'Hapus data anak ini di JournalPrivacyScreen membutuhkan konfirmasi dua langkah',
      (tester) async {
        addTearDown(() {
          HttpOverrides.global = null;
        });

        SharedPreferences.setMockInitialValues({
          AuthService.tokenKey: 'mock_token',
          ConfigService.apiBaseUrlKey: 'http://127.0.0.1:8000/api',
        });

        int? deletedChildId;

        HttpOverrides.global = _MockProfileHttpOverrides((req) async {
          final fakeReq = req as _FakeHttpClientRequest;
          if (req.method == 'GET' && req.uri.path.endsWith('/children/1/event-notes')) {
            fakeReq.responseStatusCode = 200;
            fakeReq.responseBody = '[]';
          } else if (req.method == 'DELETE' && req.uri.path.endsWith('/children/1')) {
            deletedChildId = 1;
            fakeReq.responseStatusCode = 200;
            fakeReq.responseBody = jsonEncode({'deleted': true});
          } else if (req.method == 'GET' && req.uri.path.endsWith('/children')) {
            fakeReq.responseStatusCode = 200;
            fakeReq.responseBody = jsonEncode([
              {'id': 2, 'user_id': 1, 'nickname': 'Siti', 'birth_year': 2020},
            ]);
          }
        });

        await tester.pumpWidget(
          buildTestable(
            JournalPrivacyScreen(
              initialChild: mockChildren.first,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Belum ada catatan kejadian'), findsOneWidget);

        final deleteChildBtn = find.widgetWithText(OutlinedButton, 'Hapus data anak ini');
        await tester.ensureVisible(deleteChildBtn);
        await tester.pumpAndSettle();

        // Percobaan 1: Batal di langkah kedua -> belum terhapus
        await tester.tap(deleteChildBtn);
        await tester.pumpAndSettle();
        expect(find.text('Hapus data anak ini?'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjutkan'));
        await tester.pumpAndSettle();
        expect(find.text('Konfirmasi akhir'), findsOneWidget);
        expect(deletedChildId, isNull);

        await tester.tap(find.widgetWithText(TextButton, 'Batal'));
        await tester.pumpAndSettle();
        expect(deletedChildId, isNull);

        // Percobaan 2: Konfirmasi kedua langkah -> DELETE /api/children/1 terpanggil
        await tester.tap(deleteChildBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjutkan'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Ya, hapus permanen'));
        await tester.pumpAndSettle();

        expect(deletedChildId, equals(1));
      },
    );

    testWidgets(
      'HelpScreen menampilkan Cara kerja singkat & Batasan serta tidak memuat pola nomor telepon',
      (tester) async {
        await tester.pumpWidget(buildTestable(const HelpScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Bantuan dan dukungan'), findsOneWidget);
        expect(find.text('Cara kerja singkat'), findsOneWidget);
        expect(find.text('Batasan'), findsOneWidget);
        expect(
          find.textContaining('Siband bukan alat diagnosis dan bukan pengganti tenaga profesional.'),
          findsOneWidget,
        );
        expect(
          find.text('Jika anak dalam kondisi darurat, hubungi tenaga medis atau layanan darurat setempat.'),
          findsOneWidget,
        );

        final phonePattern = RegExp(r'(\+62|08\d{2,}|\b112\b|\b118\b|\b119\b|\d{3,}-\d{3,})');
        final allTexts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' ');
        expect(phonePattern.hasMatch(allTexts), isFalse);
      },
    );

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

  group('LocationScreen (GPS Tab) Tests', () {
    const gpsTestSizes = [
      Size(360, 640),
      Size(412, 915),
      Size(1280, 720),
    ];

    for (final size in gpsTestSizes) {
      testWidgets(
        'Tab GPS tata letak di ${size.width.toInt()}x${size.height.toInt()}: bar bawah menempel & <=96, tombol Perbarui Lokasi terlihat setelah scroll',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            HttpOverrides.global = null;
          });

          SharedPreferences.setMockInitialValues({});

          await tester.pumpWidget(
            buildTestable(
              MainNavigationScreen(
                initialIndex: 3,
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

          // Pastikan tombol Perbarui Lokasi terlihat di dalam layar setelah scroll bila perlu
          final updateBtnFinder = find.widgetWithText(ElevatedButton, 'Perbarui Lokasi');
          expect(updateBtnFinder, findsOneWidget);
          await tester.ensureVisible(updateBtnFinder);
          await tester.pumpAndSettle();
          final updateRect = tester.getRect(updateBtnFinder);
          expect(updateRect.top, greaterThanOrEqualTo(0));
          expect(updateRect.bottom, lessThanOrEqualTo(bottomNavRect.top));
        },
      );
    }

    testWidgets(
      'LocationScreen tidak memanggil klien HTTP sama sekali, tidak memuat kata terhubung/menit lalu, dan menampilkan SnackBar saat Perbarui Lokasi diketuk',
      (tester) async {
        addTearDown(() {
          HttpOverrides.global = null;
        });

        HttpOverrides.global = _MockProfileHttpOverrides((req) async {
          fail('LocationScreen dilarang melakukan pemanggilan HTTP: ${req.method} ${req.uri}');
        });

        await tester.pumpWidget(buildTestable(const LocationScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Lokasi anak'), findsOneWidget);
        expect(find.text('Mode contoh'), findsOneWidget);
        expect(find.text('Data demo · bukan lokasi sebenarnya'), findsOneWidget);
        expect(find.text('Lokasi terakhir (demo)'), findsOneWidget);
        expect(find.text('Lokasi terakhir diketahui'), findsOneWidget);
        expect(find.text('Koordinat GPS belum tersedia pada prototipe.'), findsOneWidget);
        expect(find.text('Pembaruan: -'), findsOneWidget);
        expect(find.text('Fitur lokasi di luar cakupan versi ini. Tampilan di atas hanya contoh.'), findsOneWidget);

        // Tidak boleh ada teks "terhubung" atau "menit lalu"
        final allTexts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => (t.data ?? '').toLowerCase())
            .join(' ');
        expect(allTexts.contains('terhubung'), isFalse);
        expect(allTexts.contains('menit lalu'), isFalse);

        // Ketuk Perbarui Lokasi -> tampilkan SnackBar tanpa memanggil HTTP
        final updateBtnFinder = find.widgetWithText(ElevatedButton, 'Perbarui Lokasi');
        await tester.ensureVisible(updateBtnFinder);
        await tester.pumpAndSettle();
        await tester.tap(updateBtnFinder);
        await tester.pump();

        expect(find.text('Pelacakan lokasi belum tersedia pada prototipe.'), findsOneWidget);
      },
    );

    testWidgets(
      'Tombol kembali kiri atas pada tab GPS berpindah ke tab Beranda',
      (tester) async {
        await tester.pumpWidget(
          buildTestable(
            MainNavigationScreen(
              initialIndex: 3,
              initialChildren: mockChildren,
              onFetchChildren: () async => mockChildren,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lokasi anak'), findsOneWidget);

        final backBtnFinder = find.descendant(
          of: find.byType(LocationScreen),
          matching: find.byIcon(Icons.arrow_back_rounded),
        );
        expect(backBtnFinder, findsOneWidget);

        await tester.tap(backBtnFinder);
        await tester.pumpAndSettle();

        expect(find.text('PEMANTAUAN DETAK JANTUNG'), findsOneWidget);
      },
    );
  });
}

