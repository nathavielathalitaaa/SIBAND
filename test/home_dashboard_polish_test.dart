import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/analysis_model.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/services/heart_rate_service.dart';

AnalysisModel _buildHomeAnalysis() {
  return AnalysisModel.fromJson({
    'child': {'id': 1, 'name': 'Bima', 'nickname': 'Bima'},
    'window': {
      'from': '2026-11-20T00:00:00+07:00',
      'to': '2026-11-20T12:00:00+07:00',
      'timezone': 'Asia/Jakarta',
    },
    'baseline': {
      'sufficient': true,
      'sample_count': 140,
      'min_samples': 100,
      'median': 80,
      'p25': 72,
      'p75': 88,
    },
    'current': {
      'bpm': 84,
      'recorded_at': '2026-11-20T11:59:00+07:00',
      'age_seconds': 30,
      'status': 'dalam_rentang',
      'measurement_state': 'mengukur',
      'expected_rest_seconds': 300,
    },
    'series': [
      {'t': '2026-11-20T09:00:00+07:00', 'bpm': 80},
      {'t': '2026-11-20T09:02:00+07:00', 'bpm': 115},
    ],
    'resolution_seconds': 60,
    'sensor_gaps': <dynamic>[],
    'notes': [
      {
        'id': 1,
        'type': 'suara_keras',
        'at': '2026-11-20T09:01:00+07:00',
        'text_preview': 'Bel sekolah',
      },
      {
        'id': 2,
        'type': 'transisi',
        'at': '2026-11-20T10:15:00+07:00',
        'text_preview': 'Ganti kelas',
      },
      {
        'id': 3,
        'type': 'lainnya',
        'at': '2026-11-20T11:00:00+07:00',
        'text_preview': 'Istirahat',
      },
    ],
    'episodes': [
      {
        'index': 1,
        'start': '2026-11-20T09:00:00+07:00',
        'end': '2026-11-20T09:03:00+07:00',
        'duration_seconds': 180,
        'peak_bpm': 115,
        'delta_from_median': 35,
        'has_sensor_gap': false,
        'note': null,
      },
      {
        'index': 2,
        'start': '2026-11-20T10:10:00+07:00',
        'end': '2026-11-20T10:14:00+07:00',
        'duration_seconds': 240,
        'peak_bpm': 112,
        'delta_from_median': 32,
        'has_sensor_gap': false,
        'note': null,
      },
    ],
    'patterns': {
      'sufficient': true,
      'hourly': [
        for (int h = 0; h < 24; h++)
          {'hour': h, 'episode_count': h == 9 ? 2 : 0},
      ],
      'by_note_type': <dynamic>[],
    },
    'quality': {
      'window_seconds': 43200,
      'measured_seconds': 29376,
      'coverage_percent': 68.0,
      'sample_count': 240,
      'gap_count': 2,
      'gap_total_seconds': 600,
      'per_hour': <dynamic>[],
    },
    'meta': {
      'parameters': {'episode_margin_bpm': 10},
      'limitations': <dynamic>[],
    },
  });
}

void main() {
  final mockChildren = [
    ChildModel(id: 1, userId: 1, nickname: 'Bima', birthYear: 2018),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({'active_child_id': 1});
    HeartRateService.instance.switchMode(Mode.dummy);
  });

  group('Fase 7 Dashboard dan Permukaan tests', () {
    testWidgets(
      'urutan vertikal Beranda sesuai spesifikasi dan tiga chip ringkas memuat angka dari analisis',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final analysis = _buildHomeAnalysis();
        bool openedRekap = false;
        bool openedPanduan = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                initialChildren: mockChildren,
                initialAnalysisData: analysis,
                onNavigateToPanduan: () => openedPanduan = true,
                onNavigateToRekap: () => openedRekap = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Tiga chip ringkas menampilkan angka nyata dari analisis
        expect(find.text('Episode 2'), findsOneWidget);
        expect(find.text('Catatan 3'), findsOneWidget);
        expect(find.text('Cakupan 68%'), findsOneWidget);

        // Banner lama tidak lagi tampil
        expect(find.text('Yuk Memahami Anak'), findsNothing);

        // Verifikasi urutan vertikal lewat posisi Y
        final yHeader = tester.getTopLeft(find.byKey(const Key('home_header'))).dy;
        final yBpm = tester.getTopLeft(find.byKey(const Key('home_bpm_card'))).dy;
        final yChips =
            tester.getTopLeft(find.byKey(const Key('home_summary_chips'))).dy;
        final yChart =
            tester.getTopLeft(find.byKey(const Key('home_chart_section'))).dy;
        final yEpisodes =
            tester.getTopLeft(find.byKey(const Key('home_episodes_card'))).dy;
        final yPattern = tester
            .getTopLeft(find.byKey(const Key('home_pattern_entry_card')))
            .dy;
        final yShortcut =
            tester.getTopLeft(find.byKey(const Key('home_shortcut_row'))).dy;

        expect(yHeader, lessThan(yBpm));
        expect(yBpm, lessThan(yChips));
        expect(yChips, lessThan(yChart));
        expect(yChart, lessThan(yEpisodes));
        expect(yEpisodes, lessThan(yPattern));
        expect(yPattern, lessThan(yShortcut));

        // Kartu BPM memakai gradien hijau tua ke hijau tua alpha 85%
        final bpmContainer =
            tester.widget<Container>(find.byKey(const Key('home_bpm_card')));
        final bpmDeco = bpmContainer.decoration as BoxDecoration;
        expect(bpmDeco.gradient, isA<LinearGradient>());

        // Ketuk pintasan Panduan dan Rekap
        await tester.ensureVisible(find.byKey(const Key('home_shortcut_row')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('home_shortcut_panduan')));
        await tester.tap(find.byKey(const Key('home_shortcut_rekap')));
        expect(openedPanduan, isTrue);
        expect(openedRekap, isTrue);
      },
    );

    testWidgets(
      'keadaan belum ada anak memiliki tombol aksi Tambah Anak',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HomeScreen(initialChildren: []),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.ancestor(
            of: find.text('Tambah Anak'),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'keadaan galat memiliki tombol aksi Coba lagi',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                initialChildren: [],
                initialErrorMessage: 'Gagal memuat data',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.ancestor(
            of: find.text('Coba lagi'),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'keadaan belum ada jam terpasang memiliki tombol aksi Pasang jam',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                initialChildren: mockChildren,
                initialAnalysisData: _buildHomeAnalysis(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('home_pair_watch_action')), findsOneWidget);
      },
    );

    for (final size in const [
      Size(360, 640),
      Size(412, 915),
      Size(1280, 720),
    ]) {
      testWidgets(
        'Beranda tanpa overflow pada ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HomeScreen(
                  initialChildren: mockChildren,
                  initialAnalysisData: _buildHomeAnalysis(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final chipsRect =
              tester.getRect(find.byKey(const Key('home_summary_chips')));
          expect(chipsRect.right, lessThanOrEqualTo(size.width));
        },
      );
    }
  });
}
