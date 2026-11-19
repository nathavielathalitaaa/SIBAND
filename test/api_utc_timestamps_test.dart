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

    test('createEventNote mengirim occurred_at lokal dalam UTC berakhiran Z', () async {
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
      expect(occurredAt.endsWith('Z'), isTrue);
      expect(occurredAt, localTime.toUtc().toIso8601String());
    });

    test('createEventNote dengan occurredAt null memakai waktu sekarang dalam UTC berakhiran Z', () async {
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
      expect(occurredAt.endsWith('Z'), isTrue);
      final parsed = DateTime.parse(occurredAt);
      expect(parsed.isUtc, isTrue);
      expect(parsed.isAfter(before), isTrue);
      expect(parsed.isBefore(after), isTrue);
    });
  });
}
