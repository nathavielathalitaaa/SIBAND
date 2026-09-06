import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL dengan ADB reverse port forwarding (adb reverse tcp:8000 tcp:8000)
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  Future<bool> postHeartRate({
    required int bpm,
    String? deviceName,
    String? deviceMac,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/heart-rate');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
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

  Future<List<Map<String, dynamic>>> getHeartRateHistory() async {
    try {
      final url = Uri.parse('$baseUrl/heart-rate');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
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
