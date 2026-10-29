import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String defaultBaseUrl = 'http://10.0.2.2:8000/api';
  static const String apiBaseUrlKey = 'api_base_url';

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
    final trimmedUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString(apiBaseUrlKey, trimmedUrl);
  }
}
