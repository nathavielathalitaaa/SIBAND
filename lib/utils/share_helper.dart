import '../services/config_service.dart';

/// Ekstraksi origin dari baseUrl dengan menghapus akhiran '/api' dan trailing slash.
String extractOrigin(String baseUrl) {
  var trimmed = baseUrl.trim();
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  if (trimmed.endsWith('/api')) {
    trimmed = trimmed.substring(0, trimmed.length - 4);
  }
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

/// Membentuk tautan berbagi rekap terapis dari token: `<origin>/share.html#<token>`
/// dengan origin diambil dari baseUrl config_service tanpa akhiran "/api".
Future<String> shareUrl(String token, {ConfigService? configService}) async {
  final cs = configService ?? ConfigService();
  final baseUrl = await cs.getBaseUrl();
  final origin = extractOrigin(baseUrl);
  return '$origin/share.html#$token';
}
