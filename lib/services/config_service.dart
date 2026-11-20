import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );
  static const String defaultShareBaseUrl = String.fromEnvironment(
    'SHARE_BASE_URL',
    defaultValue: '',
  );
  static const String apiBaseUrlKey = 'api_base_url';
  static const String shareBaseUrlKey = 'share_base_url';

  /// Menormalkan input alamat server dari pengguna agar selalu memiliki skema
  /// (`http://` atau `https://`) dan akhiran `/api` tanpa trailing slash.
  static String normalizeApiBaseUrl(String raw) {
    var trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return '';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    if (!trimmed.endsWith('/api')) {
      trimmed = '$trimmed/api';
    }
    return trimmed;
  }

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(apiBaseUrlKey);
    if (url == null || url.trim().isEmpty) {
      return defaultBaseUrl;
    }
    return url.trim();
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = normalizeApiBaseUrl(url);
    if (normalized.isEmpty) {
      await prefs.remove(apiBaseUrlKey);
    } else {
      await prefs.setString(apiBaseUrlKey, normalized);
    }
  }

  /// Alamat origin khusus untuk tautan berbagi lintas perangkat (misal IP LAN server).
  /// Mengembalikan null bila belum diatur sehingga pemanggil memakai origin dari `getBaseUrl()`.
  Future<String?> getShareBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(shareBaseUrlKey)?.trim();
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    final envDefault = defaultShareBaseUrl.trim();
    if (envDefault.isNotEmpty) {
      return envDefault;
    }
    return null;
  }

  Future<void> setShareBaseUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url?.trim().replaceAll(RegExp(r'/+$'), '') ?? '';
    if (trimmed.isEmpty) {
      await prefs.remove(shareBaseUrlKey);
    } else {
      await prefs.setString(shareBaseUrlKey, trimmed);
    }
  }
}
