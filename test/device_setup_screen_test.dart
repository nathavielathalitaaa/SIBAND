import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/device_setup_screen.dart';
import 'package:siband/screens/pair_device_screen.dart';

void main() {
  group('DeviceSetupScreen tests', () {
    for (final size in const [
      Size(360, 640),
      Size(412, 915),
      Size(1280, 720),
    ]) {
      testWidgets(
        'menampilkan tutorial smartwatch 5 langkah dan aksi utama tanpa overflow pada ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            MaterialApp(
              home: DeviceSetupScreen(
                activeChild: ChildModel(
                  id: 1,
                  userId: 1,
                  nickname: 'Bima',
                  birthYear: 2018,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Perangkat & sumber data'), findsOneWidget);
          expect(find.text('Tutorial hubungkan smartwatch'), findsOneWidget);
          expect(find.text('Nyalakan Bluetooth dan Lokasi'), findsOneWidget);
          expect(find.text('Putuskan dari aplikasi bawaan'), findsOneWidget);
          expect(find.text('Pasang jam cukup pas di tangan'), findsOneWidget);
          expect(
            find.text('Ketuk Pasang jam lalu pilih perangkat'),
            findsOneWidget,
          );
          expect(find.text('Tunggu bacaan pertama dari jam'), findsOneWidget);
          expect(find.text('Pasang jam'), findsOneWidget);
          expect(find.text('Sumber data'), findsOneWidget);
          expect(find.text('Layar teknis (lama)'), findsOneWidget);
        },
      );
    }

    testWidgets('mengetuk Pasang jam membuka PairDeviceScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceSetupScreen(
            activeChild: ChildModel(
              id: 1,
              userId: 1,
              nickname: 'Bima',
              birthYear: 2018,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('device_setup_pair_button')));
      await tester.pumpAndSettle();

      expect(find.byType(PairDeviceScreen), findsOneWidget);
    });
  });
}
