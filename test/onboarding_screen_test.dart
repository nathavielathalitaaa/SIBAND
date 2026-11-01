import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/screens/login_screen.dart';
import 'package:siband/screens/onboarding_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget({Size size = const Size(412, 915)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const OnboardingScreen(),
      ),
    );
  }

  testWidgets('Renders slide 1 and does not overflow on 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget(size: const Size(360, 640)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SELAMAT DATANG DI SIBAND'), findsOneWidget);
    expect(find.text('Temani tumbuhnya,\ndengan lebih tenang.'), findsOneWidget);
    expect(
      find.text(
        'Ruang pendamping bagi orang tua untuk memahami kebutuhan, emosi, dan keseharian anak.',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Lanjut'), findsOneWidget);
  });

  testWidgets('Renders slide 1 and does not overflow on 412x915', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget(size: const Size(412, 915)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SELAMAT DATANG DI SIBAND'), findsOneWidget);
    expect(find.text('Temani tumbuhnya,\ndengan lebih tenang.'), findsOneWidget);
  });

  testWidgets('Navigates through slides with button and finishes onboarding', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Slide 1
    expect(find.text('SELAMAT DATANG DI SIBAND'), findsOneWidget);
    expect(find.text('Temani tumbuhnya,\ndengan lebih tenang.'), findsOneWidget);

    // Tap next to Slide 2
    await tester.tap(find.bySemanticsLabel('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('PAHAMI POLANYA'), findsOneWidget);
    expect(find.text('Setiap anak punya\ncaranya sendiri.'), findsOneWidget);
    expect(
      find.text(
        'Kenali pemicu sensorik, suasana hati, dan hal-hal yang membantu anak merasa aman.',
      ),
      findsOneWidget,
    );

    // Tap next to Slide 3
    await tester.tap(find.bySemanticsLabel('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('LANGKAH KECIL BERARTI'), findsOneWidget);
    expect(find.text('Catat hari ini,\nlihat perkembangannya.'), findsOneWidget);
    expect(
      find.text(
        'Simpan jurnal dan catatan kejadian agar orang tua dan pendamping bisa melihat pola dari waktu ke waktu.',
      ),
      findsOneWidget,
    );

    // Tap next on Slide 3 -> sets onboarding_done & opens LoginScreen
    await tester.tap(find.bySemanticsLabel('Lanjut'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_done'), isTrue);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Swiping between slides updates active slide', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(find.text('SELAMAT DATANG DI SIBAND'), findsOneWidget);

    // Fling left to advance to Slide 2
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('PAHAMI POLANYA'), findsOneWidget);

    // Fling left to advance to Slide 3
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('LANGKAH KECIL BERARTI'), findsOneWidget);
  });
}
