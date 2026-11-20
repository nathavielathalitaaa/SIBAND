import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/analysis_model.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/event_note_screen.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/screens/pattern_screen.dart';

AnalysisModel _buildFixture({
  bool baselineSufficient = true,
  int sampleCount = 120,
  int minSamples = 100,
  List<Map<String, dynamic>>? hourly,
  List<Map<String, dynamic>>? byNoteType,
  double coveragePercent = 72.5,
  int gapCount = 4,
  int qualitySamples = 320,
  List<Map<String, dynamic>>? perHour,
  List<Map<String, dynamic>>? episodes,
}) {
  return AnalysisModel.fromJson({
    'child': {'id': 1, 'name': 'Bima', 'nickname': 'Bima'},
    'window': {
      'from': '2026-11-20T00:00:00+07:00',
      'to': '2026-11-20T12:00:00+07:00',
      'timezone': 'Asia/Jakarta',
    },
    'baseline': {
      'sufficient': baselineSufficient,
      'sample_count': sampleCount,
      'min_samples': minSamples,
      'median': baselineSufficient ? 80 : null,
      'p25': baselineSufficient ? 72 : null,
      'p75': baselineSufficient ? 88 : null,
    },
    'current': {
      'bpm': 82,
      'recorded_at': '2026-11-20T11:59:00+07:00',
      'age_seconds': 30,
      'status': baselineSufficient ? 'dalam_rentang' : 'belum_ada_baseline',
      'measurement_state': 'mengukur',
      'expected_rest_seconds': 300,
    },
    'series': [
      {'t': '2026-11-20T09:00:00+07:00', 'bpm': 80},
      {'t': '2026-11-20T09:01:00+07:00', 'bpm': 112},
    ],
    'resolution_seconds': 60,
    'sensor_gaps': <dynamic>[],
    'notes': <dynamic>[],
    'episodes': episodes ??
        [
          {
            'index': 1,
            'start': '2026-11-20T09:00:00+07:00',
            'end': '2026-11-20T09:04:00+07:00',
            'duration_seconds': 240,
            'peak_bpm': 118,
            'delta_from_median': 38,
            'has_sensor_gap': false,
            'note': null,
          },
        ],
    'patterns': {
      'sufficient': baselineSufficient,
      'hourly': hourly ??
          [
            for (int h = 0; h < 24; h++)
              {
                'hour': h,
                'episode_count': h == 9
                    ? 4
                    : (h == 14 ? 2 : 0),
              },
          ],
      'by_note_type': byNoteType ??
          [
            {
              'type': 'transisi',
              'avg_rise_bpm': 18,
              'notes_used': 3,
              'notes_total': 3,
              'enough': false,
            },
            {
              'type': 'suara_keras',
              'avg_rise_bpm': 32,
              'notes_used': 6,
              'notes_total': 6,
              'enough': true,
            },
            {
              'type': 'aktivitas_fisik',
              'avg_rise_bpm': 45,
              'notes_used': 7,
              'notes_total': 7,
              'enough': true,
            },
            {
              'type': 'lainnya',
              'avg_rise_bpm': null,
              'notes_used': 1,
              'notes_total': 2,
              'enough': false,
            },
          ],
    },
    'quality': {
      'window_seconds': 43200,
      'measured_seconds': 31320,
      'coverage_percent': coveragePercent,
      'sample_count': qualitySamples,
      'gap_count': gapCount,
      'gap_total_seconds': 1200,
      'per_hour': perHour ??
          [
            for (int h = 0; h < 24; h++)
              {'hour': h, 'coverage_percent': h == 9 ? 90.0 : 40.0},
          ],
    },
    'meta': {
      'parameters': {
        'min_notes_per_type': 5,
        'episode_margin_bpm': 10,
      },
      'limitations': <dynamic>[],
    },
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'active_child_id': 1});
  });

  group('PatternScreen tests', () {
    testWidgets(
      '(a) tinggi batang jam proporsional, jam terbanyak berlabel, ketuk menampilkan detail',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final analysis = _buildFixture();
        await tester.pumpWidget(
          MaterialApp(home: PatternScreen(analysis: analysis, childId: 1)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pola'), findsOneWidget);
        expect(find.text('Paling sering naik sekitar 09.00'), findsOneWidget);
        expect(find.byKey(const Key('pattern_hour_peak_label')), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('pattern_hour_peak_label')))
              .data,
          '4',
        );

        final h9 = tester.getSize(find.byKey(const Key('hour_bar_9'))).height;
        final h14 = tester.getSize(find.byKey(const Key('hour_bar_14'))).height;
        final h0 = tester.getSize(find.byKey(const Key('hour_bar_0'))).height;

        expect(h9, closeTo(80.0, 0.5));
        expect(h14, closeTo(40.0, 0.5));
        expect(h0, closeTo(2.0, 0.5));
        expect(h9, greaterThan(h14));
        expect(h14, greaterThan(h0));

        // Ketuk batang jam 14 menampilkan "14.00 · 2 kenaikan"
        await tester.tap(find.byKey(const Key('hour_bar_14')));
        await tester.pump();
        expect(find.text('14.00 · 2 kenaikan'), findsOneWidget);
      },
    );

    testWidgets(
      '(b & c) enough=false tampil chip Belum cukup dan alpha beda; urutan jenis menurun & aktivitas_fisik tidak tampil',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final analysis = _buildFixture();
        await tester.pumpWidget(
          MaterialApp(home: PatternScreen(analysis: analysis, childId: 1)),
        );
        await tester.pumpAndSettle();

        // aktivitas_fisik tidak boleh tampil
        expect(find.text('Aktivitas fisik'), findsNothing);
        expect(find.byKey(const Key('type_row_aktivitas_fisik')), findsNothing);

        // Chip Belum cukup
        expect(find.text('Belum cukup (3/5)'), findsOneWidget);
        expect(find.text('Belum cukup (1/5)'), findsOneWidget);

        // Urutan vertikal menurun: suara_keras (32) < transisi (18) < lainnya (null)
        final ySuara =
            tester.getTopLeft(find.byKey(const Key('type_row_suara_keras'))).dy;
        final yTransisi =
            tester.getTopLeft(find.byKey(const Key('type_row_transisi'))).dy;
        final yLainnya =
            tester.getTopLeft(find.byKey(const Key('type_row_lainnya'))).dy;
        expect(ySuara, lessThan(yTransisi));
        expect(yTransisi, lessThan(yLainnya));

        // Alpha batang berbeda antara enough=true vs enough=false
        final barEnough = tester.widget<Container>(
          find.byKey(const Key('type_bar_suara_keras')),
        );
        final barNotEnough = tester.widget<Container>(
          find.byKey(const Key('type_bar_transisi')),
        );
        final colorEnough = (barEnough.decoration as BoxDecoration).color!;
        final colorNotEnough =
            (barNotEnough.decoration as BoxDecoration).color!;
        expect(colorEnough.a, greaterThan(colorNotEnough.a));
      },
    );

    testWidgets(
      '(d) keadaan kosong jenis catatan menampilkan Belum ada catatan dan membuka EventNoteScreen',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final analysis = _buildFixture(
          baselineSufficient: false,
          sampleCount: 40,
          minSamples: 100,
          byNoteType: [
            {
              'type': 'aktivitas_fisik',
              'avg_rise_bpm': 30,
              'notes_used': 6,
              'notes_total': 6,
              'enough': true,
            },
          ],
          episodes: const [],
        );

        await tester.pumpWidget(
          MaterialApp(home: PatternScreen(analysis: analysis, childId: 1)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Baseline belum cukup'), findsOneWidget);
        expect(find.text('40/100 sampel'), findsOneWidget);
        expect(find.text('Belum ada catatan'), findsOneWidget);
        expect(find.text('Tambah catatan'), findsOneWidget);

        await tester.ensureVisible(find.text('Tambah catatan'));
        await tester.tap(find.text('Tambah catatan'));
        await tester.pumpAndSettle();
        expect(find.byType(EventNoteScreen), findsOneWidget);
      },
    );

    testWidgets(
      '(e) kartu Kualitas menampilkan persen, jeda, sampel, bar per jam, dan kalimat batasan',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final analysis = _buildFixture(
          coveragePercent: 72.5,
          gapCount: 4,
          qualitySamples: 320,
        );

        await tester.pumpWidget(
          MaterialApp(home: PatternScreen(analysis: analysis, childId: 1)),
        );
        await tester.pumpAndSettle();

        expect(find.text('72.5%'), findsOneWidget);
        expect(find.text('4 jeda · 320 sampel'), findsOneWidget);
        expect(
          find.text(
            'Jam beristirahat sebentar di antara pengukuran, jadi kejadian singkat bisa terlewat.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('quality_bar_9')), findsOneWidget);
        expect(find.text('Siband bukan alat diagnosis.'), findsOneWidget);
      },
    );

    for (final size in const [
      Size(360, 640),
      Size(412, 915),
      Size(1280, 720),
    ]) {
      testWidgets(
        '(f) PatternScreen tanpa overflow pada ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final analysis = _buildFixture();
          await tester.pumpWidget(
            MaterialApp(home: PatternScreen(analysis: analysis, childId: 1)),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final cardRect =
              tester.getRect(find.byKey(const Key('pattern_hour_card')));
          expect(cardRect.right, lessThanOrEqualTo(size.width));
        },
      );
    }

    testWidgets(
      '(g) ketuk kartu Lihat pola di Beranda membuka PatternScreen',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final analysis = _buildFixture();
        final children = [
          ChildModel(id: 1, userId: 1, nickname: 'Bima', birthYear: 2018),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                initialChildren: children,
                initialAnalysisData: analysis,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final entryFinder = find.byKey(const Key('home_pattern_entry_card'));
        expect(entryFinder, findsOneWidget);
        expect(find.text('Lihat pola'), findsOneWidget);

        await tester.ensureVisible(entryFinder);
        await tester.pumpAndSettle();
        await tester.tap(entryFinder);
        await tester.pumpAndSettle();

        expect(find.byType(PatternScreen), findsOneWidget);
      },
    );
  });
}
