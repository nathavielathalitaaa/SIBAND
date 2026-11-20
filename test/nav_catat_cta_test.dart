import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/analysis_model.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/event_note_screen.dart';
import 'package:siband/screens/guide_calming_screen.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/screens/main_navigation_screen.dart';
import 'package:siband/services/heart_rate_service.dart';

Map<String, dynamic> _episodeAnalysisFixture({
  required List<Map<String, dynamic>> episodes,
}) {
  return {
    'child': {'id': 1, 'name': 'Bima', 'nickname': 'Bima'},
    'window': {
      'from': '2026-11-18T00:00:00+07:00',
      'to': '2026-11-18T12:00:00+07:00',
      'timezone': 'Asia/Jakarta',
    },
    'baseline': {
      'sufficient': true,
      'sample_count': 120,
      'min_samples': 100,
      'median': 80,
      'p25': 70,
      'p75': 90,
    },
    'current': {
      'bpm': 84,
      'recorded_at': '2026-11-18T11:59:00+07:00',
      'age_seconds': 60,
      'status': 'dalam_rentang',
      'measurement_state': 'mengukur',
      'expected_rest_seconds': 300,
    },
    'series': [
      {'t': '2026-11-18T09:00:00+07:00', 'bpm': 82},
      {'t': '2026-11-18T09:01:00+07:00', 'bpm': 125},
    ],
    'resolution_seconds': 60,
    'sensor_gaps': <dynamic>[],
    'notes': <dynamic>[],
    'episodes': episodes,
    'patterns': {
      'sufficient': false,
      'hourly': <dynamic>[],
      'by_note_type': <dynamic>[],
    },
    'quality': {
      'window_seconds': 43200,
      'measured_seconds': 120,
      'coverage_percent': 1.0,
      'sample_count': 2,
      'gap_count': 0,
      'gap_total_seconds': 0,
      'per_hour': <dynamic>[],
    },
    'meta': {
      'parameters': {
        'default_timezone': 'Asia/Jakarta',
        'episode_margin_bpm': 10,
      },
      'limitations': <dynamic>[],
    },
  };
}

void main() {
  final mockChildren = [
    ChildModel(id: 1, userId: 1, nickname: 'Bima', birthYear: 2018),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({'active_child_id': 1});
  });

  tearDown(() {
    HeartRateService.instance.switchMode(Mode.dummy);
    HeartRateService.instance.stop();
  });

  Widget buildTestable(Widget child, {Size size = const Size(360, 640)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  group('Bagian A: Navbar 4 tab dan tombol Catat kejadian', () {
    testWidgets(
      '(a) bar bawah memuat tepat 4 label Beranda, Panduan, Rekap, Profil secara berurutan',
      (tester) async {
        const size = Size(360, 640);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestable(
            MainNavigationScreen(
              initialChildren: mockChildren,
              onFetchChildren: () async => mockChildren,
            ),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        final bottomNavFinder = find.byWidget(scaffold.bottomNavigationBar!);
        final navTextFinder = find.descendant(
          of: bottomNavFinder,
          matching: find.byType(Text),
        );

        final labels = tester
            .widgetList<Text>(navTextFinder)
            .map((t) => t.data)
            .toList();
        expect(labels, ['Beranda', 'Panduan', 'Rekap', 'Profil']);

        // Pastikan posisi X keempat tab berurutan dari kiri ke kanan
        final xPositions = List.generate(
          4,
          (i) => tester.getCenter(navTextFinder.at(i)).dx,
        );
        for (int i = 0; i < 3; i++) {
          expect(xPositions[i], lessThan(xPositions[i + 1]));
        }
      },
    );

    testWidgets(
      '(b) tombol Catat kejadian hanya tampil di tab Beranda saat ada anak aktif',
      (tester) async {
        const size = Size(360, 640);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestable(
            MainNavigationScreen(
              initialChildren: mockChildren,
              onFetchChildren: () async => mockChildren,
            ),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        final fabFinder = find.byKey(const Key('fab_catat_kejadian'));
        expect(fabFinder, findsOneWidget);
        expect(find.text('Catat kejadian'), findsOneWidget);
        // Aksi catat berwarna amber (palet proyek), bukan hijau aksi utama
        final fabWidget = tester.widget<FloatingActionButton>(fabFinder);
        expect(fabWidget.backgroundColor, const Color(0xFFE8A24F));

        // Pindah ke tab Panduan, Rekap, Profil -> tombol Catat kejadian tidak ada
        for (final tabLabel in ['Panduan', 'Rekap', 'Profil']) {
          await tester.tap(find.text(tabLabel));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('fab_catat_kejadian'), skipOffstage: false),
            findsNothing,
          );
        }

        // Kembali ke Beranda -> muncul lagi
        await tester.tap(find.text('Beranda'));
        await tester.pumpAndSettle();
        expect(fabFinder, findsOneWidget);

        // Saat tidak ada anak -> tombol Catat kejadian tidak tampil
        await tester.pumpWidget(
          buildTestable(
            MainNavigationScreen(
              initialChildren: const [],
              onFetchChildren: () async => const [],
            ),
            size: size,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('fab_catat_kejadian'), skipOffstage: false),
          findsNothing,
        );
      },
    );

    for (final size in const [
      Size(360, 640),
      Size(412, 915),
      Size(1280, 720),
    ]) {
      testWidgets(
        '(c) posisi tombol Catat kejadian di atas bar bawah dan di dalam layar pada ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            buildTestable(
              MainNavigationScreen(
                initialChildren: mockChildren,
                onFetchChildren: () async => mockChildren,
              ),
              size: size,
            ),
          );
          await tester.pumpAndSettle();

          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
          final bottomNavRect = tester.getRect(
            find.byWidget(scaffold.bottomNavigationBar!),
          );
          final fabRect = tester.getRect(
            find.byKey(const Key('fab_catat_kejadian')),
          );

          expect(fabRect.bottom, lessThanOrEqualTo(bottomNavRect.top));
          expect(fabRect.right, lessThanOrEqualTo(size.width));
          expect(fabRect.left, greaterThanOrEqualTo(0));
        },
      );
    }

    testWidgets(
      '(d) mengetuk tombol Catat kejadian membuka EventNoteScreen dengan childId anak aktif',
      (tester) async {
        const size = Size(360, 640);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestable(
            MainNavigationScreen(
              initialChildren: mockChildren,
              onFetchChildren: () async => mockChildren,
            ),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fab_catat_kejadian')));
        await tester.pumpAndSettle();

        final eventNoteScreen = tester.widget<EventNoteScreen>(
          find.byType(EventNoteScreen),
        );
        expect(eventNoteScreen.childId, 1);
      },
    );
  });

  group('Bagian B: Sambungan dari kartu episode', () {
    testWidgets(
      '(a) episode tanpa catatan menampilkan Belum dicatat & Tambah catatan, sedangkan episode dengan catatan tidak',
      (tester) async {
        const size = Size(360, 640);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final analysisWithNote = AnalysisModel.fromJson(
          _episodeAnalysisFixture(
            episodes: [
              {
                'index': 1,
                'start': '2026-11-18T08:15:00+07:00',
                'end': '2026-11-18T08:18:00+07:00',
                'duration_seconds': 180,
                'peak_bpm': 122,
                'delta_from_median': 42,
                'has_sensor_gap': false,
                'note': {
                  'id': 10,
                  'type': 'suara_keras',
                  'at': '2026-11-18T08:15:00+07:00',
                  'text_preview': 'Suara petir',
                },
              },
            ],
          ),
        );

        await tester.pumpWidget(
          buildTestable(
            Scaffold(
              body: HomeScreen(
                initialChildren: mockChildren,
                initialAnalysisData: analysisWithNote,
              ),
            ),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Belum dicatat'), findsNothing);
        expect(find.text('Tambah catatan'), findsNothing);

        final analysisWithoutNote = AnalysisModel.fromJson(
          _episodeAnalysisFixture(
            episodes: [
              {
                'index': 1,
                'start': '2026-11-18T08:15:00+07:00',
                'end': '2026-11-18T08:18:00+07:00',
                'duration_seconds': 180,
                'peak_bpm': 122,
                'delta_from_median': 42,
                'has_sensor_gap': false,
                'note': null,
              },
            ],
          ),
        );

        await tester.pumpWidget(
          buildTestable(
            Scaffold(
              body: HomeScreen(
                initialChildren: mockChildren,
                initialAnalysisData: analysisWithoutNote,
              ),
            ),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Belum dicatat'), findsOneWidget);
        expect(find.text('Tambah catatan'), findsOneWidget);
      },
    );

    testWidgets(
      '(b) mengetuk Tambah catatan membuka EventNoteScreen dengan waktu mulai episode lokal (bukan waktu sekarang)',
      (tester) async {
        const size = Size(360, 640);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Gunakan tanggal kemarin jam 04:37 lokal supaya pasti berbeda dari DateTime.now()
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final epStartLocal = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          4,
          37,
        );
        final dayStr = epStartLocal.day.toString().padLeft(2, '0');
        final monthStr = epStartLocal.month.toString().padLeft(2, '0');
        final yearStr = epStartLocal.year.toString();
        final expectedFormatted = '$dayStr/$monthStr/$yearStr, 04:37';

        final analysis = AnalysisModel.fromJson(
          _episodeAnalysisFixture(
            episodes: [
              {
                'index': 1,
                'start': epStartLocal.toIso8601String(),
                'end': epStartLocal
                    .add(const Duration(minutes: 3))
                    .toIso8601String(),
                'duration_seconds': 180,
                'peak_bpm': 125,
                'delta_from_median': 45,
                'has_sensor_gap': false,
                'note': null,
              },
            ],
          ),
        );

        await tester.pumpWidget(
          buildTestable(
            Scaffold(
              body: HomeScreen(
                initialChildren: mockChildren,
                initialAnalysisData: analysis,
              ),
            ),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        final addNoteBtn = find.widgetWithText(TextButton, 'Tambah catatan');
        await tester.ensureVisible(addNoteBtn);
        await tester.tap(addNoteBtn);
        await tester.pumpAndSettle();

        expect(find.byType(EventNoteScreen), findsOneWidget);
        expect(find.text(expectedFormatted), findsOneWidget);
      },
    );

    testWidgets(
      '(c) EventNoteScreen tanpa initialOccurredAt tetap memakai waktu sekarang',
      (tester) async {
        final now = DateTime.now();
        final hh = now.hour.toString().padLeft(2, '0');
        final mm = now.minute.toString().padLeft(2, '0');

        await tester.pumpWidget(
          const MaterialApp(
            home: EventNoteScreen(childId: 1),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hari ini, $hh:$mm'), findsOneWidget);
      },
    );

    testWidgets(
      '(d) mengetuk Lihat panduan menenangkan membuka GuideCalmingScreen',
      (tester) async {
        const size = Size(360, 640);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final analysis = AnalysisModel.fromJson(
          _episodeAnalysisFixture(episodes: const []),
        );

        await tester.pumpWidget(
          buildTestable(
            Scaffold(
              body: HomeScreen(
                initialChildren: mockChildren,
                initialAnalysisData: analysis,
              ),
            ),
            size: size,
          ),
        );
        await tester.pumpAndSettle();

        final guideBtn = find.widgetWithText(
          TextButton,
          'Lihat panduan menenangkan',
        );
        expect(guideBtn, findsOneWidget);
        await tester.ensureVisible(guideBtn);
        await tester.tap(guideBtn);
        await tester.pumpAndSettle();

        final guideScreen = tester.widget<GuideCalmingScreen>(
          find.byType(GuideCalmingScreen),
        );
        expect(guideScreen.childId, 1);
      },
    );
  });
}
