import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:siband/models/child_model.dart';
import 'package:siband/screens/recap_screen.dart';
import 'package:siband/services/api_service.dart';
import 'package:siband/services/auth_service.dart';
import 'package:siband/services/config_service.dart';
import 'package:siband/utils/share_helper.dart';

Widget buildTestable(Widget child, {Size size = const Size(412, 915)}) {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shareUrl Unit Tests', () {
    test('extractOrigin handles standard baseUrl with /api', () {
      expect(extractOrigin('http://127.0.0.1:8000/api'), 'http://127.0.0.1:8000');
    });

    test('extractOrigin handles baseUrl with /api and trailing slash', () {
      expect(extractOrigin('http://127.0.0.1:8000/api/'), 'http://127.0.0.1:8000');
      expect(extractOrigin('http://127.0.0.1:8000/api///'), 'http://127.0.0.1:8000');
    });

    test('extractOrigin handles baseUrl without /api', () {
      expect(extractOrigin('https://siband.org'), 'https://siband.org');
      expect(extractOrigin('https://siband.org/'), 'https://siband.org');
    });

    test('extractOrigin handles custom subpath API_BASE_URL', () {
      expect(extractOrigin('https://example.com/v1/api'), 'https://example.com/v1');
      expect(extractOrigin('https://example.com/v1/api/'), 'https://example.com/v1');
    });

    test('shareUrl generates <origin>/share.html#<token> with default baseUrl', () async {
      SharedPreferences.setMockInitialValues({});
      final url = await shareUrl('tok12345');
      expect(url, 'http://127.0.0.1:8000/share.html#tok12345');
    });

    test('shareUrl generates correctly with custom baseUrl in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        ConfigService.apiBaseUrlKey: 'https://production-server.com/api',
      });
      final url = await shareUrl('secret-token-abc');
      expect(url, 'https://production-server.com/share.html#secret-token-abc');
    });

    test('shareUrl generates correctly with custom baseUrl ending with slash', () async {
      SharedPreferences.setMockInitialValues({
        ConfigService.apiBaseUrlKey: 'https://production-server.com/api/',
      });
      final url = await shareUrl('tok999');
      expect(url, 'https://production-server.com/share.html#tok999');
    });

    test('shareUrl generates correctly with baseUrl without /api suffix', () async {
      SharedPreferences.setMockInitialValues({
        ConfigService.apiBaseUrlKey: 'https://my-domain.org/',
      });
      final url = await shareUrl('xyz789');
      expect(url, 'https://my-domain.org/share.html#xyz789');
    });
  });

  group('RecapScreen Share BottomSheet Tests', () {
    final mockChildren = [
      ChildModel(id: 1, userId: 1, nickname: 'Bima', birthYear: 2018),
    ];

    testWidgets('Bottom sheet menampilkan teks peringatan lengkap dan format tautan baru', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        AuthService.tokenKey: 'valid_token',
        ConfigService.apiBaseUrlKey: 'http://127.0.0.1:8000/api',
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/share-links') && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 1,
              'token': 'mocked_share_token_abcdef',
              'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });

      final apiService = ApiService(client: mockClient);

      await tester.pumpWidget(buildTestable(
        RecapScreen(
          initialChildren: mockChildren,
          apiService: apiService,
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

      // Tap "Buat tautan aman"
      final buatBtn = find.text('Buat tautan aman');
      expect(buatBtn, findsOneWidget);
      await tester.ensureVisible(buatBtn);
      await tester.tap(buatBtn);
      await tester.pumpAndSettle();

      // Tap submit in modal bottom sheet
      final submitBtn = find.widgetWithText(ElevatedButton, 'Buat Tautan Aman');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify the updated warning text with added sentence
      expect(
        find.text(
          'Tautan ini hanya ditampilkan sekali. Simpan sekarang. Tautan hanya bisa dibuka bila server dapat dijangkau penerima.',
        ),
        findsOneWidget,
      );

      // Verify the generated URL format matches <origin>/share.html#<token>
      expect(
        find.text('http://127.0.0.1:8000/share.html#mocked_share_token_abcdef'),
        findsOneWidget,
      );

      // Verify copy button
      expect(find.widgetWithText(ElevatedButton, 'Salin Tautan'), findsOneWidget);
    });
  });
}
