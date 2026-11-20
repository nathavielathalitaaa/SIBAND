import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/analysis_model.dart';
import '../utils/event_type_helper.dart';
import 'event_note_screen.dart';

// Palet proyek (tanpa warna baru).
const Color _kGreen = Color(0xFF1F5C4A);
const Color _kGreenSoft = Color(0xFFE3EEDF);
const Color _kSand = Color(0xFFF6F4EF);
const Color _kAmber = Color(0xFFE8A24F);
const Color _kGrey = Color(0xFFD9DED6);
const Color _kText = Color(0xFF1E2A24);
const Color _kTextMuted = Color(0xFF6F7B74);

/// Jumlah catatan minimum per jenis agar pola jenis dianggap cukup.
/// Nilai ini sama dengan `min_notes_per_type` di konfigurasi analisis server
/// (siband-backend/config/analysis.php); dipakai bila meta tidak menyediakannya.
const int _minNotesPerType = 5;

String _two(int v) => v.toString().padLeft(2, '0');

String _hourLabel(int hour) => '${_two(hour)}.00';

/// Jam dengan episode terbanyak; seri dimenangkan oleh jam paling awal.
/// Mengembalikan null bila tidak ada episode.
int? patternPeakHour(AnalysisModel analysis) {
  int? bestHour;
  var bestCount = 0;
  final sorted = [...analysis.patterns.hourly]
    ..sort((a, b) => a.hour.compareTo(b.hour));
  for (final h in sorted) {
    if (h.episodeCount > bestCount) {
      bestCount = h.episodeCount;
      bestHour = h.hour;
    }
  }
  if (bestHour != null) return bestHour;

  // Cadangan: hitung dari jam mulai episode (jam dinding zona server).
  if (analysis.episodes.isEmpty) return null;
  final counts = <int, int>{};
  for (final ep in analysis.episodes) {
    final s = ep.start;
    if (s.length < 13) continue;
    final hour = int.tryParse(s.substring(11, 13));
    if (hour == null || hour < 0 || hour > 23) continue;
    counts[hour] = (counts[hour] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final hours = counts.keys.toList()..sort();
  for (final hour in hours) {
    if (counts[hour]! > bestCount) {
      bestCount = counts[hour]!;
      bestHour = hour;
    }
  }
  return bestHour;
}

/// Kalimat ringkasan pola tanpa penyebab atau diagnosis.
String patternSummaryText(AnalysisModel analysis) {
  if (!analysis.baseline.sufficient) return 'Baseline belum cukup';
  final peak = patternPeakHour(analysis);
  if (peak != null) return 'Paling sering naik sekitar ${_hourLabel(peak)}';
  return 'Tidak ada kenaikan tercatat';
}

class PatternScreen extends StatefulWidget {
  final AnalysisModel analysis;
  final int childId;

  const PatternScreen({
    super.key,
    required this.analysis,
    required this.childId,
  });

  @override
  State<PatternScreen> createState() => _PatternScreenState();
}

class _PatternScreenState extends State<PatternScreen> {
  static const double _barAreaHeight = 80;
  static const double _chartHeight = 100;

  int? _selectedHour;

  AnalysisModel get _a => widget.analysis;

  BoxDecoration _cardDecoration(Color color) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _cardTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- Ringkasan
  Widget _buildSummaryCard() {
    final baseline = _a.baseline;
    final children = <Widget>[
      _cardTitle('Ringkasan'),
      const SizedBox(height: 10),
      Text(
        patternSummaryText(_a),
        key: const Key('pattern_summary_text'),
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _kText,
        ),
      ),
    ];
    if (!baseline.sufficient) {
      final minSamples = baseline.minSamples <= 0 ? 1 : baseline.minSamples;
      final progress = (baseline.sampleCount / minSamples).clamp(0.0, 1.0);
      children.addAll([
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            key: const Key('pattern_baseline_progress'),
            value: progress.toDouble(),
            minHeight: 8,
            color: _kGreen,
            backgroundColor: _kGrey,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${baseline.sampleCount}/${baseline.minSamples} sampel',
          style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
        ),
      ]);
    }
    return Container(
      key: const Key('pattern_summary_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(_kGreenSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // --------------------------------------------------------------------- Jam
  void _selectHourFromDx(double dx, double width) {
    if (width <= 0) return;
    final index = (dx / (width / 24)).floor().clamp(0, 23);
    if (_selectedHour != index) setState(() => _selectedHour = index);
  }

  Widget _buildHourCard() {
    final counts = List<int>.filled(24, 0);
    for (final h in _a.patterns.hourly) {
      if (h.hour >= 0 && h.hour < 24) counts[h.hour] = h.episodeCount;
    }
    final maxCount = counts.fold<int>(0, (m, c) => c > m ? c : m);
    int? peakHour;
    if (maxCount > 0) peakHour = counts.indexOf(maxCount);

    final selected = _selectedHour;
    final detail = selected == null
        ? 'Ketuk batang untuk detail'
        : '${_hourLabel(selected)} · ${counts[selected]} kenaikan';

    return Container(
      key: const Key('pattern_hour_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(_kAmber.withValues(alpha: 0.12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Jam', subtitle: 'Kenaikan per jam'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _selectHourFromDx(d.localPosition.dx, width),
                onHorizontalDragUpdate: (d) =>
                    _selectHourFromDx(d.localPosition.dx, width),
                child: Column(
                  children: [
                    SizedBox(
                      height: _chartHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(24, (hour) {
                          final count = counts[hour];
                          final isPeak = hour == peakHour;
                          final barHeight = count == 0 || maxCount == 0
                              ? 2.0
                              : _barAreaHeight * count / maxCount;
                          return Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isPeak)
                                    Text(
                                      '$count',
                                      key: const Key('pattern_hour_peak_label'),
                                      maxLines: 1,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _kText,
                                      ),
                                    ),
                                  Container(
                                    key: Key('hour_bar_$hour'),
                                    width: (width / 24 - 3).clamp(2.0, 14.0),
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: count > 0
                                          ? _kAmber
                                          : _kGrey,
                                      borderRadius: BorderRadius.circular(3),
                                      border: selected == hour
                                          ? Border.all(color: _kText, width: 1)
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final label in const ['00', '06', '12', '18'])
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: _kTextMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            key: const Key('pattern_hour_detail'),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- Jenis
  int get _minNotes {
    final raw = _a.meta.parameters['min_notes_per_type'];
    if (raw is num && raw > 0) return raw.toInt();
    return _minNotesPerType;
  }

  List<AnalysisNoteTypePattern> get _typeRows {
    final rows = _a.patterns.byNoteType
        .where((t) => t.notesTotal > 0 && t.type != 'aktivitas_fisik')
        .toList();
    // Urut avgRiseBpm menurun; null di akhir (sort stabil dijaga lewat indeks).
    final indexed = rows.asMap().entries.toList();
    indexed.sort((x, y) {
      final a = x.value.avgRiseBpm;
      final b = y.value.avgRiseBpm;
      if (a == null && b == null) return x.key.compareTo(y.key);
      if (a == null) return 1;
      if (b == null) return -1;
      final c = b.compareTo(a);
      return c != 0 ? c : x.key.compareTo(y.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  Widget _buildTypeCard() {
    final rows = _typeRows;
    final Widget body;
    if (rows.isEmpty) {
      body = Column(
        key: const Key('pattern_type_empty'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Belum ada catatan',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventNoteScreen(childId: widget.childId),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: _kGreen,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(
                'Tambah catatan',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      final maxRise = rows.fold<int>(
        0,
        (m, r) => (r.avgRiseBpm ?? 0) > m ? (r.avgRiseBpm ?? 0) : m,
      );
      body = Column(
        children: [
          for (final r in rows) ...[
            _buildTypeRow(r, maxRise),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pola terbuka setelah cukup catatan per jenis.',
              style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
            ),
          ),
        ],
      );
    }

    return Container(
      key: const Key('pattern_type_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(
        Color.alphaBlend(_kGrey.withValues(alpha: 0.35), _kSand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Jenis', subtitle: 'Rata-rata kenaikan'),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  Widget _buildTypeRow(AnalysisNoteTypePattern r, int maxRise) {
    final rise = r.avgRiseBpm;
    final fraction = (rise == null || maxRise <= 0) ? 0.0 : rise / maxRise;
    final barColor = r.enough ? _kGreen : _kGreen.withValues(alpha: 0.3);
    return Column(
      key: Key('type_row_${r.type}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                getEventTypeName(r.type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
            ),
            if (!r.enough)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Belum cukup (${r.notesUsed}/$_minNotes)',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 10,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: _kGrey.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Container(
                  key: Key('type_bar_${r.type}'),
                  height: 10,
                  width: constraints.maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          '${rise == null ? '-' : '+$rise bpm'} · ${r.notesTotal} catatan',
          style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- Kualitas
  Widget _buildQualityCard() {
    final q = _a.quality;
    final percent = q.coveragePercent;
    final percentText = percent == percent.roundToDouble()
        ? '${percent.round()}%'
        : '${percent.toStringAsFixed(1)}%';
    return Container(
      key: const Key('pattern_quality_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(_kGreenSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Kualitas', subtitle: 'Cakupan pengukuran'),
          const SizedBox(height: 8),
          Text(
            percentText,
            key: const Key('pattern_quality_percent'),
            style: GoogleFonts.inter(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: _kGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${q.gapCount} jeda · ${q.sampleCount} sampel',
            style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
          ),
          if (q.perHour.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildQualityPerHour(q),
          ],
          const SizedBox(height: 12),
          Text(
            'Jam beristirahat sebentar di antara pengukuran, jadi kejadian singkat bisa terlewat.',
            key: const Key('pattern_quality_note'),
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: _kText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityPerHour(AnalysisQuality q) {
    final byHour = <int, double>{
      for (final h in q.perHour) h.hour: h.coveragePercent,
    };
    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (hour) {
          final v = (byHour[hour] ?? 0).clamp(0, 100).toDouble();
          return Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                key: Key('quality_bar_$hour'),
                width: 6,
                height: v <= 0 ? 2 : 2 + 26 * v / 100,
                decoration: BoxDecoration(
                  color: v <= 0 ? _kGrey : _kGreen.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // -------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSand,
      appBar: AppBar(
        backgroundColor: _kSand,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _kText),
        title: Text(
          'Pola',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _kText,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 14),
              _buildHourCard(),
              const SizedBox(height: 14),
              _buildTypeCard(),
              const SizedBox(height: 14),
              _buildQualityCard(),
              const SizedBox(height: 20),
              Text(
                'Siband bukan alat diagnosis.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
