import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/analysis_model.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/services/api_service.dart';
import 'package:siband/services/heart_rate_service.dart';

Map<String, dynamic> _analysisSuccessFixture() {
  return {
    'child': {'id': 1, 'name': 'Bima', 'nickname': 'Bima'},
    'window': {
      'from': '2026-11-15T00:00:00+07:00',
      'to': '2026-11-15T12:00:00+07:00',
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
      'recorded_at': '2026-11-15T11:59:00+07:00',
      'age_seconds': 60,
      'status': 'dalam_rentang',
      'measurement_state': 'mengukur',
      'expected_rest_seconds': 300,
    },
    'series': [
      {'t': '2026-11-15T09:00:00+07:00', 'bpm': 82},
      {'t': '2026-11-15T09:01:00+07:00', 'bpm': 86},
    ],
    'resolution_seconds': 0,
    'sensor_gaps': <dynamic>[],
    'notes': <dynamic>[],
    'episodes': <dynamic>[],
    'patterns': {
      'total_episodes': 0,
      'episodes_with_note': 0,
      'by_note_type': <dynamic>[],
    },
  };
}

void main() {
  final mockChildren = [
    ChildModel(id: 1, userId: 1, nickname: 'Bima', birthYear: 2018),
  ];

  setUp(() {
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
    'Kegagalan analisis menampilkan teks error ringan, mempertahankan kartu BPM & tombol catatan, dan Coba lagi memuat ulang hingga berhasil',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      int analysisAttempts = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/analysis')) {
          analysisAttempts++;
          if (analysisAttempts == 1) {
            return http.Response(
              jsonEncode({'message': 'Internal Server Error'}),
              500,
            );
          }
          return http.Response(jsonEncode(_analysisSuccessFixture()), 200);
        }
        if (request.url.path.endsWith('/heart-rate')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      final apiService = ApiService(client: client);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              apiService: apiService,
              initialChildren: mockChildren,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Beranda tetap menampilkan kartu BPM dan tombol catatan saat analisis gagal.
      expect(find.text('PEMANTAUAN DETAK JANTUNG'), findsOneWidget);
      expect(find.text('Catatan kejadian'), findsOneWidget);

      // Teks kecil abu dan tombol Coba lagi tampil.
      expect(find.text('Data analisis belum bisa dimuat'), findsOneWidget);
      final retryButton = find.widgetWithText(TextButton, 'Coba lagi');
      expect(retryButton, findsOneWidget);

      // Ketuk Coba lagi -> panggilan kedua berhasil dan error hilang.
      await tester.ensureVisible(retryButton);
      await tester.tap(retryButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(analysisAttempts, 2);
      expect(find.text('Data analisis belum bisa dimuat'), findsNothing);
      expect(find.text('Grafik pemantauan hari ini (Asia/Jakarta)'), findsOneWidget);
    },
  );

  testWidgets(
    'Kegagalan analisis saat refresh tidak menghapus data analisis yang sudah tampil',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/analysis')) {
          return http.Response(
            jsonEncode({'message': 'Service Unavailable'}),
            503,
          );
        }
        if (request.url.path.endsWith('/heart-rate')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      final apiService = ApiService(client: client);
      final initialAnalysis = AnalysisModel.fromJson(_analysisSuccessFixture());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              apiService: apiService,
              initialChildren: mockChildren,
              initialAnalysisData: initialAnalysis,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Data yang sudah tampil tetap dipertahankan, kartu BPM & tombol catatan ada.
      expect(find.text('Grafik pemantauan hari ini (Asia/Jakarta)'), findsOneWidget);
      expect(find.text('PEMANTAUAN DETAK JANTUNG'), findsOneWidget);
      expect(find.text('Catatan kejadian'), findsOneWidget);
      expect(find.text('Data analisis belum bisa dimuat'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Coba lagi'), findsOneWidget);
    },
  );
}
