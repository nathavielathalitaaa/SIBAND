import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const String tokenKey = 'access_token';

  /// Register user baru, simpan token jika berhasil.
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/register');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = data['access_token'] as String?;
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(tokenKey, token);
        }
        return {
          'success': true,
          'message': data['message'] ?? 'Registrasi berhasil',
          'token': token,
        };
      } else {
        final errorMessage = _parseErrorMessage(data);
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      debugPrint('[AuthService] Error saat register: $e');
      return {
        'success': false,
        'message': 'Gagal terhubung ke server: $e',
      };
    }
  }

  /// Login user, simpan token jika berhasil.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/login');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data['access_token'] as String?;
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(tokenKey, token);
        }
        return {
          'success': true,
          'message': data['message'] ?? 'Login berhasil',
          'token': token,
        };
      } else {
        final errorMessage = _parseErrorMessage(data);
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      debugPrint('[AuthService] Error saat login: $e');
      return {
        'success': false,
        'message': 'Gagal terhubung ke server: $e',
      };
    }
  }

  /// Logout user, revoke token di backend dan hapus dari SharedPreferences.
  Future<Map<String, dynamic>> logout() async {
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        final url = Uri.parse('$baseUrl/logout');
        await http.post(
          url,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      debugPrint('[AuthService] Error saat logout di server: $e');
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
    }

    return {
      'success': true,
      'message': 'Berhasil keluar',
    };
  }

  /// Ambil token yang tersimpan di local storage.
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  /// Cek apakah user sedang login (ada token tersimpan).
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Parse error response dari Laravel (termasuk 422 validation errors).
  String _parseErrorMessage(Map<String, dynamic> data) {
    if (data.containsKey('errors') && data['errors'] is Map) {
      final Map<String, dynamic> errors = data['errors'];
      final List<String> errorList = [];
      errors.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          errorList.add(value.first.toString());
        }
      });
      if (errorList.isNotEmpty) {
        return errorList.join('\n');
      }
    }
    return data['message']?.toString() ?? 'Terjadi kesalahan pada server';
  }
}
