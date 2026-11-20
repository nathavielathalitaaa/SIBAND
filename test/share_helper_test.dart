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

    test('shareUrl generates <origin>/share#<token> with default baseUrl', () async {
      SharedPreferences.setMockInitialValues({});
      final url = await shareUrl('tok12345');
      expect(url, 'http://127.0.0.1:8000/share#tok12345');
    });

    test('shareUrl generates correctly with custom baseUrl in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        ConfigService.apiBaseUrlKey: 'https://production-server.com/api',
      });
      final url = await shareUrl('secret-token-abc');
      expect(url, 'https://production-server.com/share#secret-token-abc');
    });

    test('shareUrl generates correctly with custom baseUrl ending with slash', () async {
      SharedPreferences.setMockInitialValues({
        ConfigService.apiBaseUrlKey: 'https://production-server.com/api/',
      });
      final url = await shareUrl('tok999');
      expect(url, 'https://production-server.com/share#tok999');
    });

    test('shareUrl generates correctly with baseUrl without /api suffix', () async {
      SharedPreferences.setMockInitialValues({
        ConfigService.apiBaseUrlKey: 'https://my-domain.org/',
      });
      final url = await shareUrl('xyz789');
      expect(url, 'https://my-domain.org/share#xyz789');
    });

    test('formatTherapistShareMessage formats friendly message with child name & short code, excluding PIN', () {
      final text = formatTherapistShareMessage(
        url: 'https://siband.id/share#abc',
        childName: 'Razzab',
        shortCode: 'SB7K4M',
        hasPin: true,
      );
      expect(text, contains('Berita informasi terakhir tentang Razzab!'));
      expect(text, contains('https://siband.id/share#abc'));
      expect(text, contains('Kode akses: SB7K4M'));
      expect(text, contains('PIN yang akan dikirim secara terpisah'));
      expect(text, isNot(contains('482910')));
    });

    test('formatTherapistPinMessage formats separate PIN message with child name', () {
      final pinText = formatTherapistPinMessage(
        pin: '482910',
        childName: 'Razzab',
      );
      expect(pinText, contains('Razzab'));
      expect(pinText, contains('482910'));
    });
  });

  group('RecapScreen Share BottomSheet Tests', () {
    final mockChildren = [
      ChildModel(id: 1, userId: 1, nickname: 'Razzab', birthYear: 2018),
    ];

    testWidgets('Bottom sheet membagikan tautan ramah + kode akses, dan PIN terpisah bila aktif', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        AuthService.tokenKey: 'valid_token',
        ConfigService.apiBaseUrlKey: 'http://127.0.0.1:8000/api',
      });

      final sharedPayloads = <String>[];
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/share-links') && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 1,
              'token': 'mocked_share_token_abcdef',
              'short_code': 'SB7K4M',
              'has_pin': true,
              'pin': '482910',
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
          onShareText: (text, {subject}) async {
            sharedPayloads.add(text);
            return true;
          },
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

      // Verify generated URL, short code, and separate PIN section
      expect(
        find.text('http://127.0.0.1:8000/share#mocked_share_token_abcdef'),
        findsOneWidget,
      );
      expect(find.text('Kode akses: SB7K4M'), findsOneWidget);
      expect(find.text('PIN: 482910'), findsOneWidget);

      // Tap Bagikan Tautan -> sends friendly message + URL + short code, WITHOUT PIN
      final shareLinkBtn = find.widgetWithText(ElevatedButton, 'Bagikan Tautan');
      expect(shareLinkBtn, findsOneWidget);
      await tester.ensureVisible(shareLinkBtn);
      await tester.tap(shareLinkBtn);
      await tester.pumpAndSettle();

      expect(sharedPayloads.length, 1);
      expect(sharedPayloads.first, contains('Berita informasi terakhir tentang Razzab!'));
      expect(sharedPayloads.first, contains('http://127.0.0.1:8000/share#mocked_share_token_abcdef'));
      expect(sharedPayloads.first, contains('Kode akses: SB7K4M'));
      expect(sharedPayloads.first, isNot(contains('482910')));

      // Tap Bagikan PIN Terpisah -> sends only the separate PIN message
      final sharePinBtn = find.text('Bagikan PIN Terpisah');
      expect(sharePinBtn, findsOneWidget);
      await tester.ensureVisible(sharePinBtn);
      await tester.tap(sharePinBtn);
      await tester.pumpAndSettle();

      expect(sharedPayloads.length, 2);
      expect(sharedPayloads.last, contains('482910'));
      expect(sharedPayloads.last, contains('Razzab'));
      expect(sharedPayloads.last, isNot(contains('mocked_share_token_abcdef')));
    });

    testWidgets('Bottom sheet tidak menampilkan bagian PIN terpisah bila PIN dimatikan', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        AuthService.tokenKey: 'valid_token',
        ConfigService.apiBaseUrlKey: 'http://127.0.0.1:8000/api',
      });

      final sharedPayloads = <String>[];
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/share-links') && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 2,
              'token': 'token_no_pin_123',
              'short_code': 'NP9X2K',
              'has_pin': false,
              'pin': null,
              'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });

      await tester.pumpWidget(buildTestable(
        RecapScreen(
          initialChildren: mockChildren,
          apiService: ApiService(client: mockClient),
          onShareText: (text, {subject}) async {
            sharedPayloads.add(text);
            return true;
          },
          initialRecapData: {
            'periode': '7_hari',
            'jumlah_sampel': 10,
            'jumlah_hari': 1,
            'ringkasan_per_hari': [],
            'catatan_kejadian': {'daftar': []},
          },
        ),
        size: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Buat tautan aman'));
      await tester.tap(find.text('Buat tautan aman'));
      await tester.pumpAndSettle();

      // Matikan switch PIN
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Buat Tautan Aman'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Kode akses: NP9X2K'), findsOneWidget);
      expect(find.text('Bagikan PIN Terpisah'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Bagikan Tautan'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Bagikan Tautan'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Bagikan Tautan'));
      await tester.pumpAndSettle();

      expect(sharedPayloads.length, 1);
      expect(sharedPayloads.first, contains('Berita informasi terakhir tentang Razzab!'));
      expect(sharedPayloads.first, contains('Kode akses: NP9X2K'));
      expect(sharedPayloads.first, isNot(contains('PIN')));
    });

    testWidgets('Kartu Tautan Berbagi Aktif tidak overflow di layar 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestable(
        RecapScreen(
          initialChildren: mockChildren,
          initialRecapData: {
            'periode': '2026-11',
            'jumlah_sampel': 10,
            'jumlah_hari': 1,
            'ringkasan_per_hari': [],
            'catatan_kejadian': {'daftar': []},
          },
          initialShareLinks: const [
            {
              'id': 1,
              'status': 'active',
              'expires_at': '2026-11-27T10:44:00Z',
              'last_accessed_at': null,
              'revoked_at': null,
            },
          ],
        ),
        size: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Tautan Berbagi Aktif'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tautan Berbagi Aktif'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Cabut'), findsOneWidget);
    });
  });
}
