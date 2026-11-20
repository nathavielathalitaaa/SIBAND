import 'package:flutter_test/flutter_test.dart';
import 'package:siband/screens/journal_privacy_screen.dart';

void main() {
  String formatExpectedLocal(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year, $hour:$minute';
  }

  group('formatServerNoteTime', () {
    test('format UTC SQL, ISO Z, dan ISO offset menghasilkan waktu lokal yang sama', () {
      final expected = formatExpectedLocal(DateTime.utc(2026, 11, 20, 0, 40));

      expect(formatServerNoteTime('2026-11-20 00:40:00'), expected);
      expect(formatServerNoteTime('2026-11-20T00:40:00.000Z'), expected);
      expect(formatServerNoteTime('2026-11-20T07:40:00+07:00'), expected);
    });

    test('null atau kosong mengembalikan strip', () {
      expect(formatServerNoteTime(null), '-');
      expect(formatServerNoteTime(''), '-');
      expect(formatServerNoteTime('   '), '-');
    });

    test('teks sampah dikembalikan apa adanya', () {
      expect(formatServerNoteTime('bukan-tanggal'), 'bukan-tanggal');
      expect(formatServerNoteTime('invalid time value'), 'invalid time value');
    });
  });
}
