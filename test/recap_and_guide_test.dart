import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/event_note_success_screen.dart';
import 'package:siband/screens/recap_screen.dart';

Widget buildTestable(Widget child, {Size size = const Size(360, 640)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F4EF),
        body: child,
      ),
    ),
  );
}

void main() {
  group('EventNoteSuccessScreen Tests', () {
    testWidgets('Layar berhasil menampilkan ringkasan tipe dan catatan pada 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testDate = DateTime.now();

      await tester.pumpWidget(buildTestable(
        EventNoteSuccessScreen(
          type: 'suara_keras',
          note: 'Anak kaget mendengar suara guntur',
          occurredAt: testDate,
        ),
        size: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Catatan kejadian'), findsOneWidget);
      expect(find.text('Catatan berhasil dibuat'), findsOneWidget);
      expect(find.text('Ringkasan catatan'), findsOneWidget);
      expect(find.text('Suara keras'), findsOneWidget);
      expect(find.textContaining('Hari ini,'), findsOneWidget);
      expect(find.text('Anak kaget mendengar suara guntur'), findsOneWidget);
      expect(find.text('Kembali ke Beranda'), findsOneWidget);
    });

    testWidgets('Layar berhasil menampilkan ringkasan tipe dan tanpa catatan tambahan pada 412x915', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final pastDate = DateTime(2026, 10, 25, 14, 30);

      await tester.pumpWidget(buildTestable(
        EventNoteSuccessScreen(
          type: 'perubahan_aktivitas',
          note: null,
          occurredAt: pastDate,
        ),
        size: const Size(412, 915),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Catatan berhasil dibuat'), findsOneWidget);
      expect(find.text('Perubahan aktivitas'), findsOneWidget);
      expect(find.text('25/10/2026, 14:30'), findsOneWidget);
      expect(find.text('Tanpa catatan tambahan'), findsOneWidget);
      expect(find.text('Kembali ke Beranda'), findsOneWidget);
    });
  });

  group('RecapScreen Tests', () {
    final mockChildren = [
      ChildModel(id: 1, userId: 1, nickname: 'Anak Demo', birthYear: 2018),
    ];

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    testWidgets('Rekap menghitung gabungan 7 hari dari data tiruan pada 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockRecapData = {
        'periode': '7_hari',
        'jumlah_sampel': 70,
        'jumlah_hari': 5,
        'ringkasan_per_hari': [
          {
            'tanggal': yesterdayStr,
            'rata_rata': 82.0,
            'maksimum': 110,
            'jumlah_sampel': 35,
            'bacaan_di_atas_p75': 0,
          },
          {
            'tanggal': todayStr,
            'rata_rata': 96.0,
            'maksimum': 125,
            'jumlah_sampel': 35,
            'bacaan_di_atas_p75': 3,
          },
        ],
        'baseline': {
          'sufficient': true,
          'p75': 90.0,
        },
        'bacaan_di_atas_p75': 3,
        'catatan_kejadian': {
          'daftar': [
            {
              'tipe': 'suara_keras',
              'waktu': '${todayStr}T10:15:00',
              'catatan': 'Mendengar bunyi sirene',
            },
            {
              'tipe': 'transisi',
              'waktu': '${yesterdayStr}T14:30:00',
              'catatan': '',
            },
          ],
        },
      };

      await tester.pumpWidget(buildTestable(
        RecapScreen(
          initialChildren: mockChildren,
          initialRecapData: mockRecapData,
        ),
        size: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Riwayat & Rekap'), findsOneWidget);
      expect(find.text('Pahami pola dari waktu ke waktu'), findsOneWidget);
      expect(find.text('Data tercatat'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
      expect(find.text('bacaan'), findsOneWidget);
      expect(find.text('Hari tersinkron'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('hari'), findsOneWidget);
      expect(find.text('Detak jantung (BPM)'), findsOneWidget);
      expect(find.text('Catatan kejadian terbaru'), findsOneWidget);
      expect(find.textContaining('Suara keras'), findsOneWidget);
      expect(find.text('Mendengar bunyi sirene'), findsOneWidget);
      expect(find.text('Tanpa catatan tambahan'), findsOneWidget);
      expect(find.text('Bagikan rekap ke terapis'), findsOneWidget);
    });

    testWidgets('Bar oranye hanya bila baseline cukup dan bacaan_di_atas_p75 > 0', (tester) async {
      // 1. Baseline sufficient = true -> terdapat bar oranye
      final sufficientData = {
        'periode': '7_hari',
        'jumlah_sampel': 30,
        'jumlah_hari': 1,
        'ringkasan_per_hari': [
          {
            'tanggal': todayStr,
            'rata_rata': 95.0,
            'maksimum': 120,
            'jumlah_sampel': 30,
            'bacaan_di_atas_p75': 4,
          },
        ],
        'baseline': {
          'sufficient': true,
          'p75': 88.0,
        },
      };

      await tester.pumpWidget(buildTestable(
        RecapScreen(
          initialChildren: mockChildren,
          initialRecapData: sufficientData,
        ),
      ));
      await tester.pumpAndSettle();

      // Cari bar berlatar Color(0xFFE8A24F)
      final orangeContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration) {
          return dec.color == const Color(0xFFE8A24F);
        }
        return false;
      });
      expect(orangeContainers.isNotEmpty, isTrue);

      // 2. Baseline sufficient = false -> bar TIDAK boleh oranye
      final insufficientData = {
        'periode': '7_hari',
        'jumlah_sampel': 30,
        'jumlah_hari': 1,
        'ringkasan_per_hari': [
          {
            'tanggal': todayStr,
            'rata_rata': 95.0,
            'maksimum': 120,
            'jumlah_sampel': 30,
            'bacaan_di_atas_p75': 4,
          },
        ],
        'baseline': {
          'sufficient': false,
          'p75': null,
        },
      };

      await tester.pumpWidget(buildTestable(
        RecapScreen(
          initialChildren: mockChildren,
          initialRecapData: insufficientData,
        ),
      ));
      await tester.pumpAndSettle();

      final orangeContainers2 = tester.widgetList<Container>(find.byType(Container)).where((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration) {
          return dec.color == const Color(0xFFE8A24F);
        }
        return false;
      });
      expect(orangeContainers2.isEmpty, isTrue);
    });

    testWidgets('RecapScreen renders properly on 412x915', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(
        RecapScreen(
          initialChildren: mockChildren,
          initialRecapData: {
            'periode': '7_hari',
            'jumlah_sampel': 0,
            'jumlah_hari': 0,
            'ringkasan_per_hari': [],
            'catatan_kejadian': {'daftar': []},
          },
        ),
        size: const Size(412, 915),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Riwayat & Rekap'), findsOneWidget);
      expect(find.text('Belum ada catatan kejadian'), findsOneWidget);
    });

    testWidgets('Tombol Buat tautan aman membuka modal sheet dengan opsi masa berlaku', (tester) async {
      await tester.pumpWidget(buildTestable(
        RecapScreen(
          initialChildren: mockChildren,
          initialRecapData: {
            'periode': '7_hari',
            'jumlah_sampel': 10,
            'jumlah_hari': 1,
            'ringkasan_per_hari': [],
            'catatan_kejadian': {'daftar': []},
          },
        ),
      ));
      await tester.pumpAndSettle();

      final buatBtn = find.text('Buat tautan aman');
      expect(buatBtn, findsOneWidget);
      await tester.tap(buatBtn);
      await tester.pumpAndSettle();

      expect(find.text('Buat Tautan Berbagi'), findsOneWidget);
      expect(find.text('Masa berlaku:'), findsOneWidget);
      expect(find.text('7 Hari'), findsOneWidget);
    });
  });
}


