import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/event_note_screen.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/screens/main_navigation_screen.dart';
import 'package:siband/screens/profile_screen.dart';
import 'package:siband/services/heart_rate_service.dart';

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
      expect(find.text('Segera hadir'), findsOneWidget);

      // Tap Rekap
      await tester.tap(find.text('Rekap'));
      await tester.pumpAndSettle();
      expect(find.text('Segera hadir'), findsOneWidget);

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
      expect(find.text('Kelola anak'), findsOneWidget);
      expect(find.text('Sumber data'), findsOneWidget);
      expect(find.text('Layar teknis (lama)'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
    });
  });
}

