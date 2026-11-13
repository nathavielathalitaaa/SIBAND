import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/analysis_model.dart';
import '../models/child_model.dart';
import 'auth_service.dart';
import 'config_service.dart';

class ApiService {
  final AuthService _authService;
  final ConfigService _configService;
  final http.Client _client;

  ApiService({
    AuthService? authService,
    ConfigService? configService,
    http.Client? client,
  })  : _authService = authService ?? AuthService(),
        _configService = configService ?? ConfigService(),
        _client = client ?? http.Client();

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

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

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
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
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
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

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
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ChildModel.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Server mengembalikan status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } catch (e) {
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
      }
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
      final response = await _client.post(
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
      ).timeout(const Duration(seconds: 15));

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
      final response = await _client.put(
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
      ).timeout(const Duration(seconds: 15));

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
      final response = await _client.delete(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

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
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] Error fetching baseline: $e');
      return null;
    }
  }

  /// Ambil data analisis detak jantung dan catatan kejadian anak (GET /api/children/{child}/analysis).
  Future<AnalysisModel> getChildAnalysis(
    int childId, {
    DateTime? from,
    DateTime? to,
    String? timezone = 'Asia/Jakarta',
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Unauthenticated');
      }

      final baseUrl = await _configService.getBaseUrl();
      final queryParams = <String, String>{};
      if (from != null) {
        queryParams['from'] = from.toIso8601String();
      }
      if (to != null) {
        queryParams['to'] = to.toIso8601String();
      }
      if (timezone != null && timezone.trim().isNotEmpty) {
        queryParams['tz'] = timezone.trim();
      }

      final url = Uri.parse('$baseUrl/children/$childId/analysis').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AnalysisModel.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated');
      } else {
        String? serverMessage;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            serverMessage = decoded['message'].toString();
          }
        } catch (_) {}
        throw Exception(
          serverMessage ?? 'Server mengembalikan status ${response.statusCode}',
        );
      }
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } catch (e) {
      if (e is http.ClientException ||
          e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
      }
      debugPrint('[ApiService] Error fetching child analysis: $e');
      rethrow;
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

      final response = await _client.post(
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
      ).timeout(const Duration(seconds: 15));

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
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
      };
    } on SocketException {
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
      };
    } catch (e) {
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        return {
          'success': false,
          'message': 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
        };
      }
      debugPrint('[ApiService] Error creating event note: $e');
      return {'success': false, 'message': 'Gagal terhubung ke server: $e'};
    }
  }

  /// Ambil daftar catatan kejadian anak (GET /api/children/{child}/event-notes).
  Future<List<Map<String, dynamic>>> getEventNotes(int childId) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Unauthenticated');
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/children/$childId/event-notes');

      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated');
      } else {
        throw Exception('Server mengembalikan status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } catch (e) {
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
      }
      debugPrint('[ApiService] Error fetching event notes: $e');
      rethrow;
    }
  }

  /// Hapus catatan kejadian (DELETE /api/event-notes/{id}).
  Future<bool> deleteEventNote(int noteId) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Unauthenticated');
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/event-notes/$noteId');

      final response = await _client.delete(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated');
      }
      return false;
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } catch (e) {
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
      }
      debugPrint('[ApiService] Error deleting event note: $e');
      rethrow;
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

      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated');
      }
      return null;
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } catch (e) {
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
      }
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

      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated');
      }
      return [];
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } catch (e) {
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
      }
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

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'days': days}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated');
      }
      return null;
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } catch (e) {
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
      }
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

      final response = await _client.delete(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated');
      }
      return false;
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
    } catch (e) {
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw Exception('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.');
      }
      debugPrint('[ApiService] Error deleting share link: $e');
      rethrow;
    }
  }

  /// Pasangkan device ke anak (POST /api/devices/pair).
  Future<Map<String, dynamic>> pairDevice({
    required String mac,
    required String name,
    required int childId,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Sesi telah berakhir, silakan login kembali.', 'statusCode': 401};
      }

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/devices/pair');
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'mac': mac,
          'name': name,
          'child_id': childId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data, 'device': data, 'statusCode': response.statusCode};
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Unauthenticated', 'statusCode': 401};
      } else {
        String msg = 'Gagal memasangkan jam';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {}
        return {'success': false, 'message': msg, 'statusCode': response.statusCode};
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
      };
    } on SocketException {
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
      };
    } catch (e) {
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        return {
          'success': false,
          'message': 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
        };
      }
      debugPrint('[ApiService] Error pairing device: $e');
      return {
        'success': false,
        'message': 'Gagal terhubung ke server: $e',
      };
    }
  }

  /// Ambil daftar jam yang terpasang (GET /api/devices).
  Future<List<Map<String, dynamic>>> getDevices() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return [];

      final baseUrl = await _configService.getBaseUrl();
      final url = Uri.parse('$baseUrl/devices');
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] Error fetching devices: $e');
      return [];
    }
  }
}
