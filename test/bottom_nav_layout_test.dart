import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/main_navigation_screen.dart';
import 'package:siband/services/heart_rate_service.dart';

void main() {
  final mockChildren = [
    ChildModel(id: 1, userId: 1, nickname: 'Bima', birthYear: 2018),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    HeartRateService.instance.stop();
  });

  Widget buildTestable(Widget child, Size size) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  group('MainNavigationScreen Bottom Navigation Layout Tests', () {
    const testSizes = [
      Size(360, 640),
      Size(412, 915),
      Size(1280, 720),
    ];

    for (final size in testSizes) {
      testWidgets('Layout test on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestable(
            MainNavigationScreen(
              initialChildren: mockChildren,
              onFetchChildren: () async => mockChildren,
            ),
            size,
          ),
        );
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.bottomNavigationBar, isNotNull);

        final bottomNavFinder = find.byWidget(scaffold.bottomNavigationBar!);
        expect(bottomNavFinder, findsOneWidget);

        final bottomNavRect = tester.getRect(bottomNavFinder);

        // 1. tinggi bar bawah <= 96
        expect(
          bottomNavRect.height,
          lessThanOrEqualTo(96.0),
          reason: 'Tinggi bar bawah harus <= 96 pada ukuran ${size.width.toInt()}x${size.height.toInt()}',
        );

        // 2. bar menempel di dasar layar (tester.getRect(...).bottom sama dengan tinggi layar)
        expect(
          bottomNavRect.bottom,
          equals(size.height),
          reason: 'Bar bawah harus menempel di dasar layar pada ukuran ${size.width.toInt()}x${size.height.toInt()}',
        );

        // 3. area isi di atas bar bertinggi > 0
        final bodyFinder = find.byType(IndexedStack);
        expect(bodyFinder, findsOneWidget);

        final bodyRect = tester.getRect(bodyFinder);
        expect(
          bodyRect.height,
          greaterThan(0),
          reason: 'Area isi di atas bar harus bertinggi > 0 pada ukuran ${size.width.toInt()}x${size.height.toInt()}',
        );

        expect(
          bodyRect.bottom,
          lessThanOrEqualTo(bottomNavRect.top),
          reason: 'Area isi harus berada di atas bar bawah',
        );
      });
    }
  });
}
