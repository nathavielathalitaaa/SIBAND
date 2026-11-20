import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/screens/login_screen.dart';
import 'package:siband/screens/register_screen.dart';
import 'package:siband/services/config_service.dart';

void main() {
  Widget buildTestable(Widget child, {Size size = const Size(412, 915)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  group('LoginScreen tests', () {
    testWidgets('Renders LoginScreen and does not overflow on 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(const LoginScreen(), size: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Login to your account'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Kata sandi'), findsOneWidget);
      expect(find.text('nama@email.com'), findsOneWidget);
      expect(find.text('Masukkan kata sandi'), findsOneWidget);
      expect(find.text('Lupa kata sandi?'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'LOGIN'), findsOneWidget);
      expect(find.text('Masuk dengan Google'), findsNothing);
      expect(find.textContaining('Signup', findRichText: true), findsOneWidget);

      // Verify semantics labels on fields and buttons
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Email'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Kata sandi'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'LOGIN'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Masuk dengan Google'), findsNothing);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Lupa kata sandi?'), findsNothing);
    });

    testWidgets('Renders LoginScreen and does not overflow on 412x915', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(const LoginScreen(), size: const Size(412, 915)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'LOGIN'), findsOneWidget);
    });

    testWidgets('LoginScreen tidak memuat Google maupun Lupa kata sandi', (tester) async {
      await tester.pumpWidget(buildTestable(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Google'), findsNothing);
      expect(find.textContaining('Lupa kata sandi'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Tapping Signup navigates to RegisterScreen', (tester) async {
      await tester.pumpWidget(buildTestable(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Signup', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('Form validation displays errors on empty login', (tester) async {
      await tester.pumpWidget(buildTestable(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
      await tester.pumpAndSettle();

      expect(find.text('Email tidak boleh kosong'), findsOneWidget);
      expect(find.text('Kata sandi tidak boleh kosong'), findsOneWidget);
    });

    test('ConfigService.normalizeApiBaseUrl normalizes scheme and /api suffix', () {
      expect(ConfigService.normalizeApiBaseUrl('192.168.1.10:8000'), 'http://192.168.1.10:8000/api');
      expect(ConfigService.normalizeApiBaseUrl('http://192.168.1.10:8000/'), 'http://192.168.1.10:8000/api');
      expect(ConfigService.normalizeApiBaseUrl('https://siband.id/api/'), 'https://siband.id/api');
    });

    testWidgets('Tombol Atur server di LoginScreen menyimpan alamat server yang dinormalkan', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildTestable(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Atur server'));
      await tester.pumpAndSettle();

      expect(find.text('Atur alamat server'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '192.168.1.10:8000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(await ConfigService().getBaseUrl(), 'http://192.168.1.10:8000/api');
    });
  });

  group('RegisterScreen tests', () {
    testWidgets('Renders RegisterScreen and does not overflow on 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(const RegisterScreen(), size: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Create new account'), findsOneWidget);
      expect(find.text('Nama lengkap'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Kata sandi'), findsOneWidget);
      expect(find.text('Konfirmasi kata sandi'), findsOneWidget);
      expect(find.text('Nama orang tua / wali'), findsOneWidget);
      expect(find.text('nama@email.com'), findsOneWidget);
      expect(find.text('Minimal 8 karakter'), findsOneWidget);
      expect(find.text('Ulangi kata sandi'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'SIGN UP'), findsOneWidget);
      expect(find.text('Masuk dengan Google'), findsNothing);
      expect(find.textContaining('Login', findRichText: true), findsOneWidget);

      // Verify semantics labels on fields and buttons
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Nama lengkap'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Email'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Kata sandi'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Konfirmasi kata sandi'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'SIGN UP'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Masuk dengan Google'), findsNothing);
    });

    testWidgets('Renders RegisterScreen and does not overflow on 412x915', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(const RegisterScreen(), size: const Size(412, 915)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Register'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'SIGN UP'), findsOneWidget);
    });

    testWidgets('RegisterScreen tidak memuat Google maupun Lupa kata sandi', (tester) async {
      await tester.pumpWidget(buildTestable(const RegisterScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Google'), findsNothing);
      expect(find.textContaining('Lupa kata sandi'), findsNothing);
    });

    testWidgets('Register validation displays required errors', (tester) async {
      await tester.pumpWidget(buildTestable(const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'SIGN UP'));
      await tester.pumpAndSettle();

      expect(find.text('Nama tidak boleh kosong'), findsOneWidget);
      expect(find.text('Email tidak boleh kosong'), findsOneWidget);
      expect(find.text('Kata sandi tidak boleh kosong'), findsOneWidget);
      expect(find.text('Konfirmasi kata sandi tidak boleh kosong'), findsOneWidget);
    });

    testWidgets('Register password mismatch validation', (tester) async {
      await tester.pumpWidget(buildTestable(const RegisterScreen()));
      await tester.pumpAndSettle();

      // Enter name, email, password, and mismatched confirm password
      await tester.enterText(find.byType(TextFormField).at(0), 'Budi');
      await tester.enterText(find.byType(TextFormField).at(1), 'budi@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'different123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'SIGN UP'));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi kata sandi tidak cocok'), findsOneWidget);
    });

    testWidgets('Register password minimum length validation', (tester) async {
      await tester.pumpWidget(buildTestable(const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Budi');
      await tester.enterText(find.byType(TextFormField).at(1), 'budi@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'short');
      await tester.enterText(find.byType(TextFormField).at(3), 'short');

      await tester.tap(find.widgetWithText(ElevatedButton, 'SIGN UP'));
      await tester.pumpAndSettle();

      expect(find.text('Kata sandi minimal 8 karakter'), findsOneWidget);
    });
  });
}
