import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siband/screens/event_note_success_screen.dart';

Widget buildTestable(Widget child, {Size size = const Size(360, 640)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: child,
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
}
