import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/analysis_model.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/services/api_service.dart';
import 'package:siband/services/auth_service.dart';
import 'package:siband/services/config_service.dart';
import 'package:siband/services/heart_rate_service.dart';
import 'package:siband/widgets/home_monitoring_chart_card.dart';

Map<String, dynamic> _normalFixture() {
  return {
    'child': {
      'id': 1,
      'name': 'Bima',
      'nickname': 'Bima',
    },
    'window': {
      'from': '2026-11-06T00:00:00+07:00',
      'to': '2026-11-06T12:00:00+07:00',
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
      'recorded_at': '2026-11-06T11:59:00+07:00',
      'age_seconds': 60,
      'status': 'dalam_rentang',
      'measurement_state': 'mengukur',
      'expected_rest_seconds': 300,
    },
    'series': [
      {'t': '2026-11-06T09:00:00+07:00', 'bpm': 82},
      {'t': '2026-11-06T09:01:00+07:00', 'bpm': 105},
      {'t': '2026-11-06T09:02:00+07:00', 'bpm': 125},
      {'t': '2026-11-06T09:04:00+07:00', 'bpm': 112},
    ],
    'resolution_seconds': 0,
    'sensor_gaps': [
      {
        'from': '2026-11-06T09:04:00+07:00',
        'to': '2026-11-06T09:10:00+07:00',
        'duration_seconds': 360,
      },
    ],
    'notes': [
      {
        'id': 10,
        'type': 'suara_keras',
        'at': '2026-11-06T09:00:30+07:00',
        'text_preview': 'Suara petir di dekat rumah',
      },
    ],
    'episodes': [
      {
        'index': 1,
        'start': '2026-11-06T09:01:00+07:00',
        'end': '2026-11-06T09:04:00+07:00',
        'duration_seconds': 180,
        'peak_bpm': 125,
        'delta_from_median': 45,
        'has_sensor_gap': false,
        'note': {
          'id': 10,
          'type': 'suara_keras',
          'at': '2026-11-06T09:00:30+07:00',
          'text_preview': 'Suara petir di dekat rumah',
        },
      },
    ],
    'patterns': {
      'sufficient': true,
      'hourly': [
        for (int h = 0; h < 24; h++)
          {'hour': h, 'episode_count': h == 9 ? 1 : 0},
      ],
      'by_note_type': [
        {
          'type': 'transisi',
          'avg_rise_bpm': null,
          'notes_used': 0,
          'notes_total': 0,
          'enough': false,
        },
        {
          'type': 'suara_keras',
          'avg_rise_bpm': 45,
          'notes_used': 5,
          'notes_total': 5,
          'enough': true,
        },
      ],
    },
    'quality': {
      'window_seconds': 43200,
      'measured_seconds': 180,
      'coverage_percent': 0.4,
      'sample_count': 4,
      'gap_count': 1,
      'gap_total_seconds': 360,
      'per_hour': [
        for (int h = 0; h < 24; h++)
          {'hour': h, 'coverage_percent': h == 9 ? 5.0 : 0.0},
      ],
    },
    'meta': {
      'parameters': {
        'default_timezone': 'Asia/Jakarta',
        'gap_min_seconds': 150,
        'stale_after_seconds': 420,
        'expected_rest_seconds': 300,
        'episode_margin_bpm': 10,
        'episode_min_duration_seconds': 120,
        'note_match_seconds': 300,
        'note_exclusion_minutes': 10,
        'physical_activity_exclusion_minutes': 30,
        'pattern_window_seconds': 600,
        'min_notes_per_type': 5,
        'max_span_days': 7,
        'chart_max_points': 1500,
      },
      'limitations': [
        'Jam beristirahat di antara rangkaian pengukuran sehingga kejadian singkat bisa terlewat.',
        'Detak jantung saja tidak menunjukkan penyebab; konteks dari catatan kejadian.',
        'Bukan alat diagnosis.',
      ],
    },
  };
}

void main() {
  group('AnalysisModel parsing tests', () {
    test('1. Respons normal berhasil di-parse secara lengkap', () {
      final model = AnalysisModel.fromJson(_normalFixture());

      expect(model.child.id, 1);
      expect(model.child.name, 'Bima');
      expect(model.child.nickname, 'Bima');

      expect(model.window.from, '2026-11-06T00:00:00+07:00');
      expect(model.window.to, '2026-11-06T12:00:00+07:00');
      expect(model.window.timezone, 'Asia/Jakarta');

      expect(model.baseline.sufficient, isTrue);
      expect(model.baseline.sampleCount, 120);
      expect(model.baseline.minSamples, 100);
      expect(model.baseline.median, 80.0);
      expect(model.baseline.p25, 70.0);
      expect(model.baseline.p75, 90.0);

      expect(model.current.bpm, 84);
      expect(model.current.recordedAt, '2026-11-06T11:59:00+07:00');
      expect(model.current.ageSeconds, 60);
      expect(model.current.status, 'dalam_rentang');
      expect(model.current.measurementState, 'mengukur');
      expect(model.current.expectedRestSeconds, 300);

      expect(model.series, hasLength(4));
      expect(model.series.first.t, '2026-11-06T09:00:00+07:00');
      expect(model.series.first.bpm, 82);
      expect(model.resolutionSeconds, 0);

      expect(model.sensorGaps, hasLength(1));
      expect(model.sensorGaps.first.durationSeconds, 360);

      expect(model.notes, hasLength(1));
      expect(model.notes.first.id, 10);
      expect(model.notes.first.type, 'suara_keras');
      expect(model.notes.first.textPreview, 'Suara petir di dekat rumah');

      expect(model.episodes, hasLength(1));
      expect(model.episodes.first.index, 1);
      expect(model.episodes.first.peakBpm, 125);
      expect(model.episodes.first.deltaFromMedian, 45.0);
      expect(model.episodes.first.hasSensorGap, isFalse);
      expect(model.episodes.first.note, isNotNull);
      expect(model.episodes.first.note!.id, 10);

      expect(model.patterns.sufficient, isTrue);
      expect(model.patterns.hourly, hasLength(24));
      expect(model.patterns.hourly[9].episodeCount, 1);
      expect(model.patterns.byNoteType, hasLength(2));
      expect(model.patterns.byNoteType[1].type, 'suara_keras');
      expect(model.patterns.byNoteType[1].avgRiseBpm, 45);
      expect(model.patterns.byNoteType[1].enough, isTrue);

      expect(model.quality.windowSeconds, 43200);
      expect(model.quality.measuredSeconds, 180);
      expect(model.quality.coveragePercent, 0.4);
      expect(model.quality.sampleCount, 4);
      expect(model.quality.gapCount, 1);
      expect(model.quality.gapTotalSeconds, 360);
      expect(model.quality.perHour, hasLength(24));
      expect(model.quality.perHour[9].coveragePercent, 5.0);

      expect(model.meta.parameters['gap_min_seconds'], 150);
      expect(model.meta.limitations, hasLength(3));
    });

    test('2. Baseline belum cukup (median, p25, p75 bernilai null)', () {
      final json = _normalFixture();
      json['baseline'] = {
        'sufficient': false,
        'sample_count': 12,
        'min_samples': 100,
        'median': null,
        'p25': null,
        'p75': null,
      };
      json['episodes'] = <Map<String, dynamic>>[];
      json['patterns'] = {
        'sufficient': false,
        'hourly': <Map<String, dynamic>>[],
        'by_note_type': <Map<String, dynamic>>[],
      };
      (json['current'] as Map<String, dynamic>)['status'] = 'belum_ada_baseline';

      final model = AnalysisModel.fromJson(json);

      expect(model.baseline.sufficient, isFalse);
      expect(model.baseline.sampleCount, 12);
      expect(model.baseline.minSamples, 100);
      expect(model.baseline.median, isNull);
      expect(model.baseline.p25, isNull);
      expect(model.baseline.p75, isNull);
      expect(model.episodes, isEmpty);
      expect(model.patterns.sufficient, isFalse);
      expect(model.patterns.hourly, isEmpty);
      expect(model.patterns.byNoteType, isEmpty);
      expect(model.current.status, 'belum_ada_baseline');
    });

    test('3. Current tanpa data (bpm, recorded_at, age_seconds bernilai null)', () {
      final json = _normalFixture();
      json['current'] = {
        'bpm': null,
        'recorded_at': null,
        'age_seconds': null,
        'status': 'tidak_ada_data',
        'measurement_state': 'tidak_ada_data',
        'expected_rest_seconds': 300,
      };

      final model = AnalysisModel.fromJson(json);

      expect(model.current.bpm, isNull);
      expect(model.current.recordedAt, isNull);
      expect(model.current.ageSeconds, isNull);
      expect(model.current.status, 'tidak_ada_data');
      expect(model.current.measurementState, 'tidak_ada_data');
      expect(model.current.expectedRestSeconds, 300);
    });

    test('4. Episode tanpa note (episodes[].note bernilai null)', () {
      final json = _normalFixture();
      json['episodes'] = [
        {
          'index': 1,
          'start': '2026-11-06T12:50:00+07:00',
          'end': '2026-11-06T12:59:00+07:00',
          'duration_seconds': 540,
          'peak_bpm': 121,
          'delta_from_median': 41.0,
          'has_sensor_gap': true,
          'note': null,
        },
      ];

      final model = AnalysisModel.fromJson(json);

      expect(model.episodes, hasLength(1));
      expect(model.episodes.first.note, isNull);
      expect(model.episodes.first.hasSensorGap, isTrue);
      expect(model.episodes.first.peakBpm, 121);
    });

    test('5. Array kosong ditangani dengan aman tanpa error', () {
      final json = _normalFixture();
      json['series'] = <dynamic>[];
      json['sensor_gaps'] = <dynamic>[];
      json['notes'] = <dynamic>[];
      json['episodes'] = <dynamic>[];
      json['patterns'] = {
        'sufficient': false,
        'hourly': <dynamic>[],
        'by_note_type': <dynamic>[],
      };
      json['quality'] = {
        'window_seconds': 0,
        'measured_seconds': 0,
        'coverage_percent': 0.0,
        'sample_count': 0,
        'gap_count': 0,
        'gap_total_seconds': 0,
        'per_hour': <dynamic>[],
      };
      json['meta'] = {
        'parameters': <String, dynamic>{},
        'limitations': <dynamic>[],
      };

      final model = AnalysisModel.fromJson(json);

      expect(model.series, isEmpty);
      expect(model.sensorGaps, isEmpty);
      expect(model.notes, isEmpty);
      expect(model.episodes, isEmpty);
      expect(model.patterns.hourly, isEmpty);
      expect(model.patterns.byNoteType, isEmpty);
      expect(model.quality.perHour, isEmpty);
      expect(model.meta.parameters, isEmpty);
      expect(model.meta.limitations, isEmpty);
    });

    test('6. avg_rise_bpm null pada patterns.by_note_type ditangani dengan benar', () {
      final model = AnalysisModel.fromJson(_normalFixture());

      final transisiPattern = model.patterns.byNoteType.firstWhere(
        (p) => p.type == 'transisi',
      );
      final suaraKerasPattern = model.patterns.byNoteType.firstWhere(
        (p) => p.type == 'suara_keras',
      );

      expect(transisiPattern.avgRiseBpm, isNull);
      expect(transisiPattern.notesUsed, 0);
      expect(transisiPattern.enough, isFalse);

      expect(suaraKerasPattern.avgRiseBpm, 45);
      expect(suaraKerasPattern.notesUsed, 5);
      expect(suaraKerasPattern.enough, isTrue);
    });
  });

  group('ApiService.getChildAnalysis tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        AuthService.tokenKey: 'test-sanctum-token',
        ConfigService.apiBaseUrlKey: 'http://127.0.0.1:8000/api',
      });
    });

    test('Mengirim header Bearer, Accept JSON, dan query parameter tz, from, to secara aman', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;

      final mockClient = MockClient((http.Request request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        return http.Response(jsonEncode(_normalFixture()), 200);
      });

      final apiService = ApiService(client: mockClient);
      final fromTime = DateTime(2026, 11, 6, 6, 0, 0);
      final toTime = DateTime(2026, 11, 6, 14, 0, 0);

      final result = await apiService.getChildAnalysis(
        1,
        from: fromTime,
        to: toTime,
        timezone: 'Asia/Jakarta',
      );

      expect(capturedUri, isNotNull);
      expect(capturedUri!.path, '/api/children/1/analysis');
      expect(capturedUri!.queryParameters['tz'], 'Asia/Jakarta');
      expect(capturedUri!.queryParameters['from'], fromTime.toIso8601String());
      expect(capturedUri!.queryParameters['to'], toTime.toIso8601String());

      expect(capturedHeaders!['Authorization'], 'Bearer test-sanctum-token');
      expect(capturedHeaders!['Accept'], 'application/json');
      expect(result.child.id, 1);
      expect(result.episodes, hasLength(1));
    });

    test('Hanya mengirim tz default ketika from dan to tidak diberikan', () async {
      Uri? capturedUri;

      final mockClient = MockClient((http.Request request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(_normalFixture()), 200);
      });

      final apiService = ApiService(client: mockClient);
      await apiService.getChildAnalysis(2);

      expect(capturedUri, isNotNull);
      expect(capturedUri!.path, '/api/children/2/analysis');
      expect(capturedUri!.queryParameters, {'tz': 'Asia/Jakarta'});
    });

    test('Melempar exception pada respons non-2xx (401 dan 422)', () async {
      final client401 = MockClient((_) async => http.Response('{"message":"Unauthenticated."}', 401));
      final service401 = ApiService(client: client401);
      await expectLater(
        service401.getChildAnalysis(1),
        throwsA(isA<Exception>()),
      );

      final client422 = MockClient((_) async => http.Response('{"message":"Parameter tz tidak valid."}', 422));
      final service422 = ApiService(client: client422);
      await expectLater(
        service422.getChildAnalysis(1, timezone: 'Invalid/TZ'),
        throwsA(
          predicate<Exception>((e) => e.toString().contains('Parameter tz tidak valid.')),
        ),
      );
    });
  });

  group('HomeScreen Analysis UI Integration tests', () {
    final mockChildren = [
      ChildModel(id: 1, userId: 1, nickname: 'Bima', birthYear: 2018),
      ChildModel(id: 2, userId: 1, nickname: 'Alya', birthYear: 2020),
    ];

    tearDown(() {
      HeartRateService.instance.switchMode(Mode.dummy);
      HeartRateService.instance.stop();
    });

    testWidgets(
      'Menampilkan BPM terkini, baseline p25-p75, grafik LineChart, pin catatan, dan ringkasan episode ringkas tanpa overflow di 360x640',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        SharedPreferences.setMockInitialValues({'active_child_id': 1});
        HeartRateService.instance.switchMode(Mode.dummy);

        final fixtureJson = _normalFixture();
        // Tambahkan catatan kedua yang berdekatan untuk menguji pin bertingkat (anti-bertumpuk)
        (fixtureJson['notes'] as List).add({
          'id': 11,
          'type': 'transisi',
          'at': '2026-11-06T09:00:45+07:00',
          'text_preview': 'Pergantian kegiatan belajar',
        });
        final analysisModel = AnalysisModel.fromJson(fixtureJson);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(360, 640)),
              child: Scaffold(
                body: HomeScreen(
                  initialChildren: mockChildren,
                  initialAnalysisData: analysisModel,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // 1. Kartu Detak Jantung Sekarang & Baseline Pribadi
        expect(find.text('84'), findsOneWidget);
        expect(find.text('BPM'), findsOneWidget);
        expect(find.text('Dalam rentang biasa'), findsOneWidget);
        expect(find.text('70–90 BPM'), findsOneWidget);
        expect(find.text('80 BPM'), findsOneWidget);
        expect(find.text('120 sampel'), findsOneWidget);
        expect(find.text('Sensor aktif mengukur'), findsOneWidget);

        // 2. Grafik Pemantauan Time-Series (fl_chart LineChart), Pin Catatan, & Footer Time-Series
        expect(find.byType(LineChart), findsOneWidget);
        expect(find.text('Pin catatan kejadian pada grafik'), findsOneWidget);
        expect(
          find.text('Pemantauan rentang waktu · bukan diagnosis'),
          findsOneWidget,
        );
        expect(
          find.text('Rata-rata per jam · bukan diagnosis'),
          findsNothing,
        );

        // 3. Ringkasan Episode Kenaikan Ringkas & Tombol Catatan Kejadian
        expect(find.text('Ringkasan episode kenaikan'), findsOneWidget);
        expect(find.text('1 episode'), findsOneWidget);
        expect(find.text('09:01–09:04 (3 menit)'), findsOneWidget);
        expect(find.text('Puncak 125 BPM (+45)'), findsOneWidget);
        expect(
          find.textContaining('Suara keras · Suara petir di dekat rumah'),
          findsOneWidget,
        );
        expect(find.text('Kualitas data & pola kejadian'), findsNothing);
        expect(find.text('+ Catatan kejadian'), findsOneWidget);
      },
    );

    testWidgets(
      'Menampilkan tiga status utama detak jantung dan menyinkronkan active_child_id dari SharedPreferences',
      (tester) async {
        SharedPreferences.setMockInitialValues({'active_child_id': 2});
        HeartRateService.instance.switchMode(Mode.dummy);

        final jsonSedikit = _normalFixture();
        (jsonSedikit['current'] as Map<String, dynamic>)['bpm'] = 96;
        (jsonSedikit['current'] as Map<String, dynamic>)['status'] =
            'sedikit_di_atas';
        final modelSedikit = AnalysisModel.fromJson(jsonSedikit);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                initialChildren: mockChildren,
                initialAnalysisData: modelSedikit,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Anak aktif harus Alya (id: 2 dari SharedPreferences), bukan otomatis _children.first (Bima)
        expect(find.text('Alya'), findsOneWidget);
        expect(find.text('Sedikit di atas baseline'), findsOneWidget);

        final jsonJauh = _normalFixture();
        (jsonJauh['current'] as Map<String, dynamic>)['bpm'] = 118;
        (jsonJauh['current'] as Map<String, dynamic>)['status'] =
            'jauh_di_atas';
        final modelJauh = AnalysisModel.fromJson(jsonJauh);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                initialChildren: mockChildren,
                initialAnalysisData: modelJauh,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Jauh di atas baseline'), findsOneWidget);
      },
    );

    testWidgets(
      'Prioritas BPM live BLE tidak terkunci oleh nilai backend 30 detik, serta menangani sensor terputus dan data stale',
      (tester) async {
        SharedPreferences.setMockInitialValues({'active_child_id': 1});

        // Backend mengembalikan BPM 84 ("dalam_rentang"), tetapi sensor BLE lokal aktif mengukur 116 BPM
        final analysisModel = AnalysisModel.fromJson(_normalFixture());

        HeartRateService.instance.setBleTestState(
          mode: Mode.ble,
          bleState: BluetoothConnectionState.connected,
          bpm: 116,
          lastBpmReceivedAt: DateTime.now(),
          secondsSinceLastBpm: 1,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                initialChildren: mockChildren,
                initialAnalysisData: analysisModel,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Harus menampilkan nilai live BLE (116) dan status dinamis "Jauh di atas baseline", bukan 84 dari backend
        expect(find.text('116'), findsOneWidget);
        expect(find.text('84'), findsNothing);
        expect(find.text('Jauh di atas baseline'), findsOneWidget);
        expect(find.text('Jam · mengukur'), findsOneWidget);
        expect(find.text('Pembacaan langsung BLE'), findsOneWidget);

        // Ketika BLE live turun ke 95 BPM, tampilan langsung ikut berubah menjadi 95 ("Sedikit di atas baseline")
        HeartRateService.instance.setBleTestState(
          mode: Mode.ble,
          bleState: BluetoothConnectionState.connected,
          bpm: 95,
          lastBpmReceivedAt: DateTime.now(),
          secondsSinceLastBpm: 0,
        );
        await tester.pump();

        expect(find.text('95'), findsOneWidget);
        expect(find.text('Sedikit di atas baseline'), findsOneWidget);

        // Ketika sensor BLE terputus dan data backend sudah stale (age_seconds > stale_after_seconds)
        final staleJson = _normalFixture();
        (staleJson['current'] as Map<String, dynamic>)['bpm'] = 88;
        (staleJson['current'] as Map<String, dynamic>)['age_seconds'] = 600;
        (staleJson['current'] as Map<String, dynamic>)['measurement_state'] =
            'tidak_ada_data';
        final staleModel = AnalysisModel.fromJson(staleJson);

        HeartRateService.instance.setBleTestState(
          mode: Mode.ble,
          bleState: BluetoothConnectionState.disconnected,
          bpm: 75,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                initialChildren: mockChildren,
                initialAnalysisData: staleModel,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('--'), findsOneWidget);
        expect(find.text('Jam · terputus'), findsOneWidget);
        expect(find.text('Data tidak terbaru'), findsOneWidget);
        expect(find.text('Sensor terputus · data kedaluwarsa'), findsOneWidget);
      },
    );

    testWidgets(
      'Footer grafik menyesuaikan sumber data: time-series vs fallback rata-rata per jam vs kosong',
      (tester) async {
        // 1. Grafik fallback rata-rata per jam (series kosong, hourlyAverages berisi data)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeMonitoringChartCard(
                analysisData: null,
                baselineData: const {'sufficient': true, 'p75': 90},
                hourlyAverages: [
                  {'label': '08:00', 'avg': 82.0},
                  {'label': '09:00', 'avg': 94.0},
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Rata-rata per jam · bukan diagnosis'),
          findsOneWidget,
        );
        expect(
          find.text('Ringkasan rata-rata per jam (24 jam terakhir)'),
          findsOneWidget,
        );

        // 2. Grafik kosong (series kosong & hourlyAverages kosong)
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HomeMonitoringChartCard(
                analysisData: null,
                baselineData: null,
                hourlyAverages: [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Pemantauan detak jantung · bukan diagnosis'),
          findsOneWidget,
        );
        expect(find.text('Belum ada data'), findsOneWidget);
      },
    );
  });
}

