import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/services/api_service.dart';
import 'package:siband/services/auth_service.dart';
import 'package:siband/services/config_service.dart';
import 'package:siband/services/heart_rate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AuthService.tokenKey: 'test-token',
      ConfigService.apiBaseUrlKey: 'http://127.0.0.1:8000/api',
    });
  });

  group('HeartRateService Mode Dummy backend posting', () {
    testWidgets(
      'Mode Dummy dengan sendDummyToBackend=false tidak mengirim postHeartRate ke backend',
      (tester) async {
        int postCount = 0;
        final mockClient = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/heart-rate')) {
            postCount++;
          }
          return http.Response('{"message":"ok"}', 201);
        });

        final service = HeartRateService.forTesting(
          apiService: ApiService(client: mockClient),
        );
        expect(service.sendDummyToBackend, isFalse);

        service.start();
        await tester.pump(const Duration(seconds: 3));

        expect(service.currentMode, Mode.dummy);
        expect(service.lastBpmReceivedAt, isNotNull);
        expect(service.currentBpm, inInclusiveRange(60, 120));
        expect(postCount, 0);

        service.stop();
      },
    );

    testWidgets(
      'Mode Dummy dengan sendDummyToBackend=true mengirim postHeartRate ke backend',
      (tester) async {
        final postedPayloads = <Map<String, dynamic>>[];
        final mockClient = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/heart-rate')) {
            postedPayloads.add(
              jsonDecode(request.body) as Map<String, dynamic>,
            );
          }
          return http.Response('{"message":"ok"}', 201);
        });

        final service = HeartRateService.forTesting(
          apiService: ApiService(client: mockClient),
        );
        service.sendDummyToBackend = true;

        service.start();
        await tester.pump(const Duration(seconds: 3));

        expect(postedPayloads, isNotEmpty);
        expect(postedPayloads.first['device_name'], 'XWATCH_DUMMY');
        expect(postedPayloads.first['bpm'], inInclusiveRange(60, 120));

        service.stop();
      },
    );
  });
}
