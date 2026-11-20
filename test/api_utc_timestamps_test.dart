import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/services/api_service.dart';
import 'package:siband/services/auth_service.dart';
import 'package:siband/services/config_service.dart';

void main() {
  group('ApiService UTC timestamps', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        AuthService.tokenKey: 'test-sanctum-token',
        ConfigService.apiBaseUrlKey: 'http://127.0.0.1:8000/api',
      });
    });

    test('postHeartRate mengirim recorded_at dalam UTC berakhiran Z sesuai DateTime yang diberikan', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((http.Request request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"id": 1}', 201);
      });

      final apiService = ApiService(client: mockClient);
      final localTime = DateTime(2026, 11, 20, 7, 40, 15);

      final ok = await apiService.postHeartRate(
        bpm: 82,
        deviceName: 'XWatch H4',
        deviceMac: 'A3:23:78:8B:2F:A5',
        childId: 2,
        deviceId: 2,
        recordedAt: localTime,
      );

      expect(ok, isTrue);
      expect(capturedBody, isNotNull);
      final recordedAt = capturedBody!['recorded_at'] as String;
      expect(recordedAt.endsWith('Z'), isTrue);
      expect(recordedAt, localTime.toUtc().toIso8601String());
    });

    test('postHeartRate tanpa recordedAt memakai waktu sekarang dalam UTC berakhiran Z', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((http.Request request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"id": 1}', 201);
      });

      final apiService = ApiService(client: mockClient);
      final before = DateTime.now().toUtc().subtract(const Duration(seconds: 2));
      final ok = await apiService.postHeartRate(bpm: 76, childId: 2, deviceId: 2);
      final after = DateTime.now().toUtc().add(const Duration(seconds: 2));

      expect(ok, isTrue);
      final recordedAt = capturedBody!['recorded_at'] as String;
      expect(recordedAt.endsWith('Z'), isTrue);
      final parsed = DateTime.parse(recordedAt);
      expect(parsed.isUtc, isTrue);
      expect(parsed.isAfter(before), isTrue);
      expect(parsed.isBefore(after), isTrue);
    });

    String formatUtcSql(DateTime utc) {
      final t = utc.toUtc();
      return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    }

    test('createEventNote mengirim occurred_at lokal dalam UTC format YYYY-MM-DD HH:mm:ss', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((http.Request request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"id": 10}', 201);
      });

      final apiService = ApiService(client: mockClient);
      final localTime = DateTime(2026, 11, 20, 7, 40);

      final result = await apiService.createEventNote(
        2,
        type: 'gelisah',
        note: 'Suara keras di luar',
        occurredAt: localTime,
      );

      expect(result['success'], isTrue);
      expect(capturedBody, isNotNull);
      final occurredAt = capturedBody!['occurred_at'] as String;
      expect(occurredAt.contains('Z'), isFalse);
      expect(occurredAt.contains(' '), isTrue);
      expect(occurredAt, formatUtcSql(localTime.toUtc()));
    });

    test('createEventNote dengan occurredAt null memakai waktu sekarang dalam UTC format YYYY-MM-DD HH:mm:ss', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((http.Request request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"id": 11}', 201);
      });

      final apiService = ApiService(client: mockClient);
      final before = DateTime.now().toUtc().subtract(const Duration(seconds: 2));
      final result = await apiService.createEventNote(
        2,
        type: 'istirahat',
      );
      final after = DateTime.now().toUtc().add(const Duration(seconds: 2));

      expect(result['success'], isTrue);
      expect(capturedBody, isNotNull);
      final occurredAt = capturedBody!['occurred_at'] as String;
      expect(occurredAt.contains('Z'), isFalse);
      expect(occurredAt.contains(' '), isTrue);
      expect(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(occurredAt), isTrue);
      final parsed = DateTime.parse('${occurredAt.replaceFirst(' ', 'T')}Z');
      expect(parsed.isUtc, isTrue);
      expect(parsed.isAfter(before), isTrue);
      expect(parsed.isBefore(after), isTrue);
    });
  });
}
