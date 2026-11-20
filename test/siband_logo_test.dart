import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/screens/login_screen.dart';
import 'package:siband/screens/register_screen.dart';
import 'package:siband/widgets/siband_logo.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'active_child_id': 1});
  });

  group('SibandLogo tests', () {
    for (final logoSize in const [24.0, 36.0, 64.0]) {
      testWidgets(
        'render pada ukuran ${logoSize.toInt()} tanpa overflow',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(child: SibandLogo(size: logoSize)),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(SibandLogo), findsOneWidget);
          final renderedSize = tester.getSize(find.byType(SibandLogo));
          expect(renderedSize.width, logoSize);
          expect(renderedSize.height, logoSize);
        },
      );
    }

    for (final screenSize in const [
      Size(360, 640),
      Size(412, 915),
      Size(1280, 720),
    ]) {
      testWidgets(
        'tampil di Login, Register, dan header Beranda tanpa overflow pada ${screenSize.width.toInt()}x${screenSize.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = screenSize;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          // LoginScreen
          await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(SibandLogo), findsOneWidget);

          // RegisterScreen
          await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(SibandLogo), findsOneWidget);

          // HomeScreen header
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HomeScreen(
                  initialChildren: [
                    ChildModel(
                      id: 1,
                      userId: 1,
                      nickname: 'Bima',
                      birthYear: 2018,
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(SibandLogo), findsOneWidget);
          final logoRect = tester.getRect(find.byType(SibandLogo));
          expect(logoRect.right, lessThanOrEqualTo(screenSize.width));
        },
      );
    }
  });
}
