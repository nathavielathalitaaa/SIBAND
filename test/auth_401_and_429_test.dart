import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/models/child_model.dart';
import 'package:siband/screens/home_screen.dart';
import 'package:siband/screens/login_screen.dart';
import 'package:siband/services/api_service.dart';
import 'package:siband/services/auth_service.dart';
import 'package:siband/services/heart_rate_service.dart';
import 'package:siband/services/session_guard.dart';

class _TrackingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  setUp(() {
    SessionGuard.resetForTest();
    SharedPreferences.setMockInitialValues({'access_token': 'stale-token'});
  });

  tearDown(() {
    SessionGuard.resetForTest();
    HeartRateService.instance.switchMode(Mode.dummy);
    HeartRateService.instance.stop();
  });

  testWidgets('Penanganan 401 idempotent (panggilan beruntun hanya navigasi sekali)', (tester) async {
    final observer = _TrackingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: SessionGuard.navigatorKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('Beranda')),
      ),
    );

    // Reset count after initial route push.
    observer.pushCount = 0;

    await Future.wait([
      SessionGuard.handleUnauthorized(),
      SessionGuard.handleUnauthorized(),
      SessionGuard.handleUnauthorized(),
    ]);
    await tester.pumpAndSettle();

    expect(observer.pushCount, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sesi berakhir, silakan masuk lagi.'), findsOneWidget);
  });

  test('Penghapusan token setelah menerima 401 dari ApiService', () async {
    final authService = AuthService();
    expect(await authService.getToken(), 'stale-token');

    final client = MockClient((_) async {
      return http.Response(jsonEncode({'message': 'Unauthenticated.'}), 401);
    });
    final apiService = ApiService(authService: authService, client: client);

    await expectLater(
      apiService.getChildAnalysis(1),
      throwsA(isA<Exception>()),
    );

    expect(await authService.getToken(), isNull);
  });

  testWidgets('429 pada login menampilkan pesan bahasa Indonesia tanpa teks mentah server', (tester) async {
    final client = MockClient((_) async {
      return http.Response(
        jsonEncode({'message': 'Too Many Attempts. Retry after 60s.'}),
        429,
      );
    });
    final authService = AuthService(client: client);

    final result = await authService.login(
      email: 'ortu@example.com',
      password: 'password123',
    );
    expect(result['success'], isFalse);
    expect(result['message'], 'Terlalu banyak percobaan. Coba lagi sebentar.');

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: authService),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'ortu@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    final loginBtn = find.byType(ElevatedButton).first;
    await tester.ensureVisible(loginBtn);
    await tester.tap(loginBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Terlalu banyak percobaan. Coba lagi sebentar.'), findsOneWidget);
    expect(find.textContaining('Too Many Attempts'), findsNothing);
  });

  testWidgets('HomeScreen yang menerima 401 dari analisis kembali ke LoginScreen', (tester) async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'expired-token',
      'active_child_id': 1,
    });

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/analysis')) {
        return http.Response(jsonEncode({'message': 'Unauthenticated.'}), 401);
      }
      if (request.url.path.endsWith('/heart-rate')) {
        return http.Response(jsonEncode([]), 200);
      }
      return http.Response(jsonEncode({}), 200);
    });

    final apiService = ApiService(client: client);
    final mockChildren = [
      ChildModel(id: 1, userId: 1, nickname: 'Bima', birthYear: 2018),
    ];

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: SessionGuard.navigatorKey,
        home: Scaffold(
          body: HomeScreen(
            apiService: apiService,
            initialChildren: mockChildren,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sesi berakhir, silakan masuk lagi.'), findsOneWidget);
    expect(await AuthService().getToken(), isNull);
  });
}
