import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siband/models/analysis_model.dart';
import 'package:siband/utils/event_type_helper.dart';
import 'package:siband/widgets/home_monitoring_chart_card.dart';

const double _cardWidth = 360;
// Lebar viewport area geser = lebar kartu - padding kartu (2 x 20) - kolom sumbu Y (34).
const double _viewport = _cardWidth - 40 - 34;
const double _plotPadX = 8;
const double _plotHeight = 180;

String _iso(int totalSeconds) {
  // Mulai 06:00:20 (+07:00); data sepanjang < 24 jam sehingga tanggal tetap.
  final s = 6 * 3600 + 20 + totalSeconds;
  final hh = (s ~/ 3600).toString().padLeft(2, '0');
  final mm = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
  final ss = (s % 60).toString().padLeft(2, '0');
  return '2026-11-15T$hh:$mm:$ss+07:00';
}

/// Data uji: [totalMinutes] menit, satu titik per [stepSeconds] detik.
/// Tiga titik terakhir membentuk episode (120, 125, 133 bpm).
Map<String, dynamic> _fixture({
  int totalMinutes = 300,
  int stepSeconds = 300,
  int resolution = 300,
  bool baselineSufficient = true,
  bool emptySeries = false,
  bool withNotes = false,
}) {
  final n = totalMinutes * 60 ~/ stepSeconds + 1;
  final series = <Map<String, dynamic>>[];
  for (int i = 0; i < n; i++) {
    int bpm = 70 + (i * 7) % 15; // 70..84
    if (i == n - 3) bpm = 120;
    if (i == n - 2) bpm = 125;
    if (i == n - 1) bpm = 133;
    series.add({'t': _iso(i * stepSeconds), 'bpm': bpm});
  }

  return {
    'child': {'id': 1, 'name': 'Bima', 'nickname': 'Bima'},
    'window': {
      'from': '2026-11-15T00:00:00+07:00',
      'to': '2026-11-15T12:00:00+07:00',
      'timezone': 'Asia/Jakarta',
    },
    'baseline': {
      'sufficient': baselineSufficient,
      'sample_count': 120,
      'min_samples': 100,
      'median': baselineSufficient ? 80 : null,
      'p25': baselineSufficient ? 70 : null,
      'p75': baselineSufficient ? 90 : null,
    },
    'current': {
      'bpm': 84,
      'recorded_at': _iso(totalMinutes * 60),
      'age_seconds': 60,
      'status': 'dalam_rentang',
      'measurement_state': 'mengukur',
      'expected_rest_seconds': 300,
    },
    'series': emptySeries ? <dynamic>[] : series,
    'resolution_seconds': resolution,
    'sensor_gaps': [
      {'from': _iso(60 * 60), 'to': _iso(70 * 60), 'duration_seconds': 600},
    ],
    'notes': withNotes
        ? [
            {
              'id': 10,
              'type': 'suara_keras',
              'at': _iso(30 * 60),
              'text_preview': 'Catatan uji',
            },
          ]
        : <dynamic>[],
    'episodes': emptySeries
        ? <dynamic>[]
        : [
            {
              'index': 1,
              'start': _iso((n - 3) * stepSeconds),
              'end': _iso((n - 1) * stepSeconds),
              'duration_seconds': 2 * stepSeconds,
              'peak_bpm': 133,
              'delta_from_median': 53,
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
      'measured_seconds': 0,
      'coverage_percent': 0.0,
      'sample_count': n,
      'gap_count': 1,
      'gap_total_seconds': 600,
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

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> json, {
  List<Map<String, dynamic>> hourly = const [],
}) async {
  tester.view.physicalSize = const Size(_cardWidth, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeMonitoringChartCard(
            analysisData: AnalysisModel.fromJson(json),
            baselineData: null,
            hourlyAverages: hourly,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

ScrollPosition _position(WidgetTester tester) {
  return tester
      .widget<SingleChildScrollView>(find.byKey(const Key('chart_scroll')))
      .controller!
      .position;
}

/// Posisi global titik terakhir (bpm 133). Rentang Y: minY 60, maxY 150
/// (p25 = 70, p75 = 90, bpm maks 133 -> floor((70-10)/10)*10 .. ceil((133+12)/10)*10).
Offset _lastPointGlobal(WidgetTester tester, {required double canvasW}) {
  final topLeft = tester.getTopLeft(find.byKey(const Key('chart_plot')));
  const minY = 60.0;
  const maxY = 150.0;
  final x = _plotPadX + 1.0 * (canvasW - 2 * _plotPadX);
  final y = _plotHeight * (maxY - 133) / (maxY - minY);
  return topLeft + Offset(x, y);
}

void main() {
  const double canvasW = 300 / visibleMinutes * _viewport;

  testWidgets(
    '(a) lebar kanvas > lebar viewport untuk data lebih panjang dari visibleMinutes',
    (tester) async {
      await _pump(tester, _fixture());

      final viewportW = tester
          .getSize(find.byKey(const Key('chart_scroll')))
          .width;
      final plotW = tester.getSize(find.byKey(const Key('chart_plot'))).width;

      expect(viewportW, closeTo(_viewport, 0.5));
      expect(plotW, greaterThan(viewportW));
      expect(plotW, closeTo(canvasW, 0.5));
      expect(find.byType(ScatterChart), findsOneWidget);
    },
  );

  testWidgets(
    '(b) posisi awal scroll berada di ujung kanan (maxScrollExtent)',
    (tester) async {
      await _pump(tester, _fixture());

      final pos = _position(tester);
      expect(pos.maxScrollExtent, greaterThan(0));
      expect(pos.pixels, pos.maxScrollExtent);
    },
  );

  testWidgets('(c) label sumbu Y tidak bergeser setelah area grafik digeser', (
    tester,
  ) async {
    await _pump(tester, _fixture());

    final yAxis = find.byKey(const Key('chart_y_axis'));
    final yLabel = find
        .descendant(of: yAxis, matching: find.byType(Text))
        .first;
    final axisBefore = tester.getTopLeft(yAxis);
    final labelBefore = tester.getTopLeft(yLabel);
    final plotBefore = tester.getTopLeft(find.byKey(const Key('chart_plot')));

    await tester.drag(
      find.byKey(const Key('chart_scroll')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();

    final plotAfter = tester.getTopLeft(find.byKey(const Key('chart_plot')));
    expect(plotAfter.dx, isNot(closeTo(plotBefore.dx, 1)));
    expect(tester.getTopLeft(yAxis), axisBefore);
    expect(tester.getTopLeft(yLabel), labelBefore);
  });

  testWidgets(
    '(d) ketukan pada titik menampilkan panel jam dan bpm (dengan detik)',
    (tester) async {
      await _pump(tester, _fixture(resolution: 10));

      expect(
        find.text('Tiap titik = nilai tengah per 10 detik'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chart_detail_panel')), findsNothing);

      await tester.tapAt(_lastPointGlobal(tester, canvasW: canvasW));
      await tester.pump();

      expect(find.byKey(const Key('chart_detail_panel')), findsOneWidget);
      expect(find.text('11.00.20 · 133 bpm'), findsOneWidget);
      expect(find.text('Jauh di atas baseline'), findsOneWidget);
      expect(
        find.text('Bagian dari episode 1 (+53 di atas median)'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chart_selection_ring')), findsOneWidget);
    },
  );

  testWidgets('(d2) tanpa detik jika resolution_seconds >= 60', (tester) async {
    await _pump(tester, _fixture(resolution: 300));

    expect(find.textContaining('Tiap titik = nilai tengah'), findsOneWidget);

    await tester.tapAt(_lastPointGlobal(tester, canvasW: canvasW));
    await tester.pump();

    expect(find.text('11.00 · 133 bpm'), findsOneWidget);
  });

  testWidgets(
    'catatan "Tiap titik" tidak tampil jika resolution_seconds <= 1',
    (tester) async {
      await _pump(tester, _fixture(resolution: 1));
      expect(find.textContaining('Tiap titik = nilai tengah'), findsNothing);
    },
  );

  testWidgets(
    '(e) ketukan di area kosong dan tombol Tutup membersihkan pilihan',
    (tester) async {
      await _pump(tester, _fixture());

      final point = _lastPointGlobal(tester, canvasW: canvasW);
      await tester.tapAt(point);
      await tester.pump();
      expect(find.byKey(const Key('chart_detail_panel')), findsOneWidget);

      // Area kosong: dekat sisi atas plot, jauh dari titik mana pun.
      final topLeft = tester.getTopLeft(find.byKey(const Key('chart_plot')));
      await tester.tapAt(Offset(point.dx - 200, topLeft.dy + 4));
      await tester.pump();
      expect(find.byKey(const Key('chart_detail_panel')), findsNothing);

      // Tombol Tutup.
      await tester.tapAt(point);
      await tester.pump();
      expect(find.byKey(const Key('chart_detail_panel')), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pump();
      expect(find.byKey(const Key('chart_detail_panel')), findsNothing);
    },
  );

  testWidgets(
    '(f) tombol "Ke sekarang" muncul setelah digeser ke kiri dan hilang setelah ditekan',
    (tester) async {
      await _pump(tester, _fixture());

      expect(find.text('Ke sekarang'), findsNothing);

      await tester.drag(
        find.byKey(const Key('chart_scroll')),
        const Offset(400, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ke sekarang'), findsOneWidget);

      await tester.tap(find.text('Ke sekarang'));
      await tester.pumpAndSettle();

      expect(find.text('Ke sekarang'), findsNothing);
      final pos = _position(tester);
      expect(pos.pixels, pos.maxScrollExtent);
    },
  );

  testWidgets(
    '(g) data tanpa series memakai fallback rata-rata per jam seperti sebelumnya',
    (tester) async {
      await _pump(
        tester,
        _fixture(emptySeries: true),
        hourly: [
          {'label': '08:00', 'avg': 82.0},
          {'label': '09:00', 'avg': 94.0},
        ],
      );

      expect(find.byType(ScatterChart), findsNothing);
      expect(find.byKey(const Key('chart_scroll')), findsNothing);
      expect(find.text('Rata-rata per jam · bukan diagnosis'), findsOneWidget);
      expect(
        find.text('Ringkasan rata-rata per jam (24 jam terakhir)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'warna dan ukuran titik mengikuti baseline; netral jika baseline belum cukup',
    (tester) async {
      await _pump(tester, _fixture());
      var spots = tester
          .widget<ScatterChart>(find.byType(ScatterChart))
          .data
          .scatterSpots;
      expect(spots.length, 61);

      // 133 > 90 + 10 -> oranye besar; 125 dan 120 juga di atas ambang.
      expect(spots.last.color, const Color(0xFFEA7A1E));
      expect(spots.last.radius, 6);
      // 70..84 dalam p25..p75 -> teal kecil.
      expect(spots.first.color, const Color(0xFF2F8F83));
      expect(spots.first.radius, 3);

      await _pump(tester, _fixture(baselineSufficient: false));
      await tester.pump();
      spots = tester
          .widget<ScatterChart>(find.byType(ScatterChart))
          .data
          .scatterSpots;
      expect(spots.map((s) => s.color).toSet(), {const Color(0xFF6F7B74)});
    },
  );

  testWidgets(
    'baris pin catatan ikut bergeser bersama grafik, judulnya tetap',
    (tester) async {
      await _pump(tester, _fixture(withNotes: true));

      final title = find.text('Pin catatan kejadian pada grafik');
      final chip = find.byIcon(getEventTypeIcon('suara_keras'));
      expect(title, findsOneWidget);
      expect(chip, findsOneWidget);

      final plotBefore = tester.getTopLeft(find.byKey(const Key('chart_plot')));
      final chipBefore = tester.getTopLeft(chip);
      final titleBefore = tester.getTopLeft(title);

      await tester.drag(
        find.byKey(const Key('chart_scroll')),
        const Offset(150, 0),
      );
      await tester.pumpAndSettle();

      final plotAfter = tester.getTopLeft(find.byKey(const Key('chart_plot')));
      final shift = plotAfter.dx - plotBefore.dx;
      expect(shift.abs(), greaterThan(50));
      expect(tester.getTopLeft(chip).dx - chipBefore.dx, closeTo(shift, 0.5));
      expect(tester.getTopLeft(title), titleBefore);
    },
  );
}
