import 'dart:convert';
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
import 'package:siband/services/heart_rate_service.dart';
import 'package:siband/widgets/heartbeat_pulse.dart';

Map<String, dynamic> _buildAnalysisJson({
  int? currentBpm = 84,
  int? ageSeconds = 30,
  String currentStatus = 'dalam_rentang',
  String measurementState = 'mengukur',
  List<Map<String, dynamic>>? episodes,
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
      'bpm': currentBpm,
      'recorded_at':
          currentBpm != null ? '2026-11-18T11:59:30+07:00' : null,
      'age_seconds': ageSeconds,
      'status': currentStatus,
      'measurement_state': measurementState,
      'expected_rest_seconds': 300,
    },
    'series': [
      {'t': '2026-11-18T09:00:00+07:00', 'bpm': 82},
      {'t': '2026-11-18T09:05:00+07:00', 'bpm': 86},
    ],
    'resolution_seconds': 60,
    'sensor_gaps': <dynamic>[],
    'notes': <dynamic>[],
    'episodes': episodes ??
        [
          {
            'index': 1,
            'start': '2026-11-18T09:01:00+07:00',
            'end': '2026-11-18T09:04:00+07:00',
            'duration_seconds': 180,
            'peak_bpm': 118,
            'delta_from_median': 38,
            'has_sensor_gap': false,
            'note': null,
          },
          {
            'index': 2,
            'start': '2026-11-18T10:15:00+07:00',
            'end': '2026-11-18T10:18:00+07:00',
            'duration_seconds': 180,
            'peak_bpm': 122,
            'delta_from_median': 42,
            'has_sensor_gap': false,
            'note': null,
          },
        ],
    'patterns': {
      'sufficient': false,
      'hourly': <dynamic>[],
      'by_note_type': <dynamic>[],
    },
    'quality': {
      'window_seconds': 43200,
      'measured_seconds': 300,
      'coverage_percent': 10.0,
      'sample_count': 2,
      'gap_count': 0,
      'gap_total_seconds': 0,
      'per_hour': <dynamic>[],
    },
    'meta': {
      'parameters': {
        'default_timezone': 'Asia/Jakarta',
        'episode_margin_bpm': 10,
        'stale_after_seconds': 420,
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
    EpisodeEntryFadeIn.animationTriggerCount = 0;
    SharedPreferences.setMockInitialValues({
      'access_token': 'test-token',
      'active_child_id': 1,
    });
  });

  tearDown(() {
    HeartRateService.instance.switchMode(Mode.dummy);
    HeartRateService.instance.stop();
  });

  testWidgets(
    '(a) HeartbeatPulse measuring dengan bpm 60 dan 120 menghasilkan durasi controller berbeda',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartbeatPulse(
              bpm: 60,
              state: HeartbeatState.measuring,
            ),
          ),
        ),
      );

      final state60 = tester.state<HeartbeatPulseState>(
        find.byType(HeartbeatPulse),
      );
      final dur60 = state60.controllerDuration;
      expect(dur60, const Duration(milliseconds: 1000));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartbeatPulse(
              bpm: 120,
              state: HeartbeatState.measuring,
            ),
          ),
        ),
      );

      final state120 = tester.state<HeartbeatPulseState>(
        find.byType(HeartbeatPulse),
      );
      final dur120 = state120.controllerDuration;
      expect(dur120, const Duration(milliseconds: 500));
      expect(dur60, isNot(equals(dur120)));
    },
  );

  testWidgets(
    '(b) disableAnimations true menghasilkan tidak ada animasi berjalan',
    (tester) async {
      for (final s in HeartbeatState.values) {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: HeartbeatPulse(
                  bpm: 90,
                  state: s,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse);
      }
    },
  );

  testWidgets(
    '(c) resting dan stale tidak memakai warna merah',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartbeatPulse(
              bpm: 80,
              state: HeartbeatState.resting,
            ),
          ),
        ),
      );
      final restingIcon = tester.widget<Icon>(find.byType(Icon));
      expect(restingIcon.color, HeartbeatPulseState.amberColor);
      expect(restingIcon.color, isNot(Colors.red));
      expect(restingIcon.color, isNot(Colors.redAccent));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartbeatPulse(
              bpm: null,
              state: HeartbeatState.stale,
            ),
          ),
        ),
      );
      final staleIcon = tester.widget<Icon>(find.byType(Icon));
      expect(staleIcon.color, HeartbeatPulseState.staleColor);
      expect(staleIcon.color, isNot(Colors.red));
      expect(staleIcon.color, isNot(Colors.redAccent));
    },
  );

  testWidgets(
    '(d) simulated menampilkan hati garis tepi tanpa denyut dan label Simulasi',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartbeatPulse(
              bpm: 75,
              state: HeartbeatState.simulated,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Simulasi'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets(
    '(e) string status baru tampil untuk tiap keadaan di HomeScreen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Backend mengukur -> 'Jam sedang mengukur'
      HeartRateService.instance.switchMode(Mode.dummy);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              initialChildren: mockChildren,
              initialAnalysisData: AnalysisModel.fromJson(
                _buildAnalysisJson(measurementState: 'mengukur'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Jam sedang mengukur'), findsOneWidget);

      // 2. BLE resting dengan bacaan lokal segar -> 'Jam sedang beristirahat sebentar'
      HeartRateService.instance.setBleTestState(
        mode: Mode.ble,
        bleState: BluetoothConnectionState.connected,
        bpm: 82,
        lastBpmReceivedAt: DateTime.now().subtract(const Duration(seconds: 20)),
        secondsSinceLastBpm: 20,
      );
      await tester.pump();
      expect(find.text('Jam sedang beristirahat sebentar'), findsOneWidget);

      // 3. BLE resting tanpa bacaan segar & backend kedaluwarsa -> 'Belum ada data baru'
      HeartRateService.instance.setBleTestState(
        mode: Mode.ble,
        bleState: BluetoothConnectionState.connected,
        bpm: 0,
        lastBpmReceivedAt: null,
        secondsSinceLastBpm: 500,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              initialChildren: mockChildren,
              initialAnalysisData: AnalysisModel.fromJson(
                _buildAnalysisJson(
                  currentBpm: 80,
                  ageSeconds: 600,
                  measurementState: 'tidak_ada_data',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Belum ada data baru'), findsOneWidget);

      // 4. BLE terputus tapi ada bacaan backend segar -> 'Jam tidak terhubung · bacaan terakhir'
      HeartRateService.instance.setBleTestState(
        mode: Mode.ble,
        bleState: BluetoothConnectionState.disconnected,
        bpm: 0,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              initialChildren: mockChildren,
              initialAnalysisData: AnalysisModel.fromJson(
                _buildAnalysisJson(
                  currentBpm: 84,
                  ageSeconds: 30,
                  measurementState: 'mengukur',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Jam tidak terhubung · bacaan terakhir'), findsOneWidget);

      // 5. BLE terputus & data backend kedaluwarsa -> 'Jam tidak terhubung'
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              initialChildren: mockChildren,
              initialAnalysisData: AnalysisModel.fromJson(
                _buildAnalysisJson(
                  currentBpm: 84,
                  ageSeconds: 600,
                  measurementState: 'tidak_ada_data',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Jam tidak terhubung'), findsOneWidget);

      // 6. BLE terputus & belum pernah ada bacaan -> 'Menunggu bacaan pertama dari jam'
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              initialChildren: mockChildren,
              initialAnalysisData: AnalysisModel.fromJson(
                _buildAnalysisJson(
                  currentBpm: null,
                  ageSeconds: null,
                  measurementState: 'tidak_ada_data',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Menunggu bacaan pertama dari jam'), findsOneWidget);
    },
  );

  testWidgets(
    '(f) refresh 30 detik tidak memutar ulang animasi kartu episode yang sudah tampil',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      int analysisCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/analysis')) {
          analysisCalls++;
          return http.Response(jsonEncode(_buildAnalysisJson()), 200);
        }
        if (request.url.path.endsWith('/heart-rate')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      final apiService = ApiService(client: client);
      EpisodeEntryFadeIn.animationTriggerCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              apiService: apiService,
              initialChildren: mockChildren,
              initialAnalysisData: AnalysisModel.fromJson(_buildAnalysisJson()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dua kartu episode tampil pertama kali -> 2 animasi dijalankan.
      expect(EpisodeEntryFadeIn.animationTriggerCount, 2);
      final initialCalls = analysisCalls;

      // Majukan waktu 30 detik untuk memicu timer refresh berkala.
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(milliseconds: 100));

      expect(analysisCalls, greaterThan(initialCalls));
      // Tidak ada animasi kartu episode yang diulang pada episode yang sama.
      expect(EpisodeEntryFadeIn.animationTriggerCount, 2);
    },
  );
}
