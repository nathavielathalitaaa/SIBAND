import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siband/screens/login_screen.dart';
import 'package:siband/screens/register_screen.dart';

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
      expect(find.text('Lupa kata sandi?'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'LOGIN'), findsOneWidget);
      expect(find.text('Masuk dengan Google'), findsOneWidget);
      expect(find.textContaining('Signup', findRichText: true), findsOneWidget);

      // Verify semantics labels on fields and buttons
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Email'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Kata sandi'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'LOGIN'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Masuk dengan Google'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Lupa kata sandi?'), findsOneWidget);
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

    testWidgets('Lupa kata sandi displays SnackBar', (tester) async {
      await tester.pumpWidget(buildTestable(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lupa kata sandi?'));
      await tester.pump();

      expect(find.text('Fitur ini belum tersedia'), findsOneWidget);
    });

    testWidgets('Google sign in displays SnackBar', (tester) async {
      await tester.pumpWidget(buildTestable(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Masuk dengan Google'));
      await tester.pump();

      expect(find.text('Masuk dengan Google belum tersedia'), findsOneWidget);
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
      expect(find.text('Masuk dengan Google'), findsOneWidget);
      expect(find.textContaining('Login', findRichText: true), findsOneWidget);

      // Verify semantics labels on fields and buttons
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Nama lengkap'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Email'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Kata sandi'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Konfirmasi kata sandi'), findsAtLeastNWidgets(1));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'SIGN UP'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Masuk dengan Google'), findsOneWidget);
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

    testWidgets('Google sign in displays SnackBar on RegisterScreen', (tester) async {
      await tester.pumpWidget(buildTestable(const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Masuk dengan Google'));
      await tester.pump();

      expect(find.text('Masuk dengan Google belum tersedia'), findsOneWidget);
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
