import '../services/config_service.dart';

/// Membentuk tautan berbagi rekap terapis dari token.
/// // TODO: ganti ke halaman web terapis nanti; baseUrl dari config_service
Future<String> shareUrl(String token) async {
  final baseUrl = await ConfigService().getBaseUrl();
  return '$baseUrl/api/share/$token';
}
