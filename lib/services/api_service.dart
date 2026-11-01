import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/child_model.dart';
import 'auth_service.dart';
import 'config_service.dart';

class ApiService {
  final AuthService _authService = AuthService();
  final ConfigService _configService = ConfigService();

  Future<bool> postHeartRate({
    required int bpm,
    String? deviceName,
    String? deviceMac,
    int? childId,
    int? deviceId,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[ApiService] Token null/kosong, postHeartRate dibatalkan.');
        return false;
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/heart-rate');
      final payload = <String, dynamic>{
        'bpm': bpm,
        'device_name': deviceName,
        'device_mac': deviceMac,
        'recorded_at': DateTime.now().toIso8601String(),
      };
      if (childId != null) {
        payload['child_id'] = childId;
      }
      if (deviceId != null) {
        payload['device_id'] = deviceId;
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
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

  /// Ambil profil pengguna (GET /api/user).
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return null;

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/user');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] Error fetching user profile: $e');
      return null;
    }
  }

  /// Ambil daftar anak milik user (GET /api/children).
  Future<List<ChildModel>> getChildren() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[ApiService] Token null/kosong, getChildren dibatalkan.');
        throw Exception('Token tidak ditemukan atau sesi telah berakhir');
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/children');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ChildModel.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Server mengembalikan status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] Error fetching children: $e');
      rethrow;
    }
  }

  /// Buat data anak baru (POST /api/children).
  Future<ChildModel?> createChild({
    required String nickname,
    required int birthYear,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return null;

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/children');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nickname': nickname,
          'birth_year': birthYear,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ChildModel.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] Error creating child: $e');
      return null;
    }
  }

  /// Perbarui data anak (PUT /api/children/{id}).
  Future<ChildModel?> updateChild({
    required int id,
    required String nickname,
    required int birthYear,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return null;

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/children/$id');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nickname': nickname,
          'birth_year': birthYear,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ChildModel.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] Error updating child: $e');
      return null;
    }
  }

  /// Hapus data anak (DELETE /api/children/{id}).
  Future<bool> deleteChild(int id) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return false;

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/children/$id');
      final response = await http.delete(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] Error deleting child: $e');
      return false;
    }
  }

  /// Ambil statistik baseline anak (GET /api/children/{child}/baseline).
  Future<Map<String, dynamic>?> getBaseline(int childId, {int days = 7}) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return null;

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/children/$childId/baseline?days=$days');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] Error fetching baseline: $e');
      return null;
    }
  }

  /// Simpan catatan kejadian (POST /api/children/{child}/event-notes).
  Future<Map<String, dynamic>> createEventNote(
    int childId, {
    required String type,
    String? note,
    DateTime? occurredAt,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Sesi telah berakhir, silakan login kembali.'};
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/children/$childId/event-notes');

      final time = occurredAt ?? DateTime.now();
      final formattedTime =
          '${time.year.toString().padLeft(4, '0')}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'type': type,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          'occurred_at': formattedTime,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Catatan tersimpan'};
      } else {
        String msg = 'Gagal menyimpan catatan';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {}
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      debugPrint('[ApiService] Error creating event note: $e');
      return {'success': false, 'message': 'Gagal terhubung ke server: $e'};
    }
  }

  /// Ambil rekap bulanan anak (GET /api/children/{child}/recap).
  Future<Map<String, dynamic>?> getRecap(int childId, {String? month}) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return null;
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/children/$childId/recap').replace(
        queryParameters: month != null ? {'month': month} : null,
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated');
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] Error fetching recap: $e');
      rethrow;
    }
  }

  /// Ambil daftar tautan berbagi rekap (GET /api/children/{child}/share-links).
  Future<List<Map<String, dynamic>>> getShareLinks(int childId) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return [];
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/children/$childId/share-links');

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
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated');
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] Error fetching share links: $e');
      rethrow;
    }
  }

  /// Buat tautan berbagi baru (POST /api/children/{child}/share-links).
  Future<Map<String, dynamic>?> createShareLink(int childId, {int days = 7}) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return null;
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/children/$childId/share-links');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'days': days}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated');
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] Error creating share link: $e');
      rethrow;
    }
  }

  /// Cabut tautan berbagi (DELETE /api/share-links/{id}).
  Future<bool> deleteShareLink(int shareLinkId) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return false;
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/share-links/$shareLinkId');

      final response = await http.delete(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated');
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] Error deleting share link: $e');
      rethrow;
    }
  }
}

