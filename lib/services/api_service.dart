import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'config_service.dart';

class ApiService {
  final AuthService _authService = AuthService();
  final ConfigService _configService = ConfigService();

  Future<bool> postHeartRate({
    required int bpm,
    String? deviceName,
    String? deviceMac,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[ApiService] Token null/kosong, postHeartRate dibatalkan.');
        return false;
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/heart-rate');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'bpm': bpm,
          'device_name': deviceName,
          'device_mac': deviceMac,
          'recorded_at': DateTime.now().toIso8601String(),
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      debugPrint('[ApiService] Error posting heart rate: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getHeartRateHistory({int? hours}) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[ApiService] Token null/kosong, getHeartRateHistory dibatalkan.');
        return [];
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/heart-rate').replace(
        queryParameters: hours != null ? {'hours': '$hours'} : null,
      );
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] Error fetching heart rate history: $e');
      return [];
    }
  }
}
