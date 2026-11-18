import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/event_note_screen.dart';
import 'package:siband/screens/main_navigation_screen.dart';
import 'package:siband/services/heart_rate_service.dart';

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
}
