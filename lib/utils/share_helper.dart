import 'package:flutter/services.dart';
import '../services/config_service.dart';

const MethodChannel _shareChannel = MethodChannel('id.siband.app/share');

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

/// Membentuk tautan berbagi rekap terapis dari token: `<origin>/share#<token>`.
/// Memprioritaskan `SHARE_BASE_URL` / alamat LAN berbagi bila diatur agar
/// perangkat lain di router lokal (laptop terapis & ponsel juri) dapat membukanya
/// meski HP terhubung ke server melalui USB (`127.0.0.1`).
Future<String> shareUrl(String token, {ConfigService? configService}) async {
  final cs = configService ?? ConfigService();
  final shareBase = await cs.getShareBaseUrl();
  final rawBase = (shareBase != null && shareBase.isNotEmpty)
      ? shareBase
      : await cs.getBaseUrl();
  final origin = extractOrigin(rawBase);
  return '$origin/share#$token';
}

/// Format pesan ramah untuk membagikan tautan & kode akses (tanpa PIN) ke terapis.
String formatTherapistShareMessage({
  required String url,
  String? childName,
  String? shortCode,
  bool hasPin = false,
}) {
  final trimmedName = childName?.trim() ?? '';
  final headline = trimmedName.isNotEmpty
      ? 'Berita informasi terakhir tentang $trimmedName!'
      : 'Berita informasi terakhir dari Siband!';
  final intro = trimmedName.isNotEmpty
      ? 'Berikut tautan rekap pemantauan terbaru $trimmedName dari Siband:'
      : 'Berikut tautan rekap pemantauan terbaru dari Siband:';

  final lines = <String>[
    headline,
    '',
    intro,
    url,
  ];
  if (shortCode != null && shortCode.trim().isNotEmpty) {
    lines.add('');
    lines.add('Kode akses: ${shortCode.trim()}');
  }
  if (hasPin) {
    lines.add('Tautan ini dilindungi PIN yang akan dikirim secara terpisah.');
  }
  return lines.join('\n');
}

/// Format pesan PIN terpisah agar keamanan akses rekap tetap terjaga.
String formatTherapistPinMessage({
  required String pin,
  String? childName,
}) {
  final trimmedName = childName?.trim() ?? '';
  final trimmedPin = pin.trim();
  if (trimmedName.isNotEmpty) {
    return 'PIN akses rekap $trimmedName di Siband: $trimmedPin';
  }
  return 'PIN akses rekap Siband: $trimmedPin';
}

/// Membuka lembar berbagi bawaan sistem (Android Share Sheet).
/// Mengembalikan `true` jika lembar berbagi sistem terbuka, atau `false` jika fallback ke clipboard.
Future<bool> shareTextNative(String text, {String? subject}) async {
  try {
    final result = await _shareChannel.invokeMethod<bool>('shareText', {
      'text': text,
      'subject': subject,
    });
    if (result == true) return true;
  } on MissingPluginException {
    // Fallback ke clipboard pada desktop/test yang tidak memiliki channel Android.
  } on PlatformException {
    // Fallback ke clipboard jika share sheet gagal dibuka.
  }
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}
