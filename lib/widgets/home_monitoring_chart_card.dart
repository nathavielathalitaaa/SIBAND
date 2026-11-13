import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/analysis_model.dart';
import '../utils/event_type_helper.dart';

class HomeMonitoringChartCard extends StatelessWidget {
  final AnalysisModel? analysisData;
  final Map<String, dynamic>? baselineData;
  final List<Map<String, dynamic>> hourlyAverages;
  final bool isLoadingAnalysis;

  const HomeMonitoringChartCard({
    super.key,
    required this.analysisData,
    required this.baselineData,
    required this.hourlyAverages,
    this.isLoadingAnalysis = false,
  });

  /// Format HH:mm dari ISO 8601 string (mempertahankan jam lokal pada offset string seperti +07:00).
  static String formatTimeWib(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    final match = RegExp(r'T(\d{2}):(\d{2})').firstMatch(iso);
    if (match != null) {
      return '${match.group(1)}:${match.group(2)}';
    }
    final dt = DateTime.tryParse(iso);
    if (dt != null) {
      final wib = dt.toUtc().add(const Duration(hours: 7));
      return '${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')}';
    }
    return iso;
  }

  @override
  Widget build(BuildContext context) {
    final analysis = analysisData;
    final series = analysis?.series ?? const <AnalysisSeriesPoint>[];
    final bool hasTimeSeries = series.isNotEmpty;
    final bool hasHourlyFallback = !hasTimeSeries && hourlyAverages.isNotEmpty;

    final String subtitleText;
    final String footerText;
    if (hasTimeSeries) {
      subtitleText =
          'Grafik pemantauan hari ini (${analysis?.window.timezone ?? 'Asia/Jakarta'})';
      footerText = 'Pemantauan rentang waktu · bukan diagnosis';
    } else if (hasHourlyFallback) {
      subtitleText = 'Ringkasan rata-rata per jam (24 jam terakhir)';
      footerText = 'Rata-rata per jam · bukan diagnosis';
    } else {
      subtitleText = 'Menunggu bacaan sensor detak jantung';
      footerText = 'Pemantauan detak jantung · bukan diagnosis';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tren detak jantung',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E2A24),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6F7B74),
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoadingAnalysis)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1F5C4A),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (hasTimeSeries) ...[
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildLegendItem(
                  color: const Color(0xFF1F5C4A),
                  label: 'BPM aktual',
                  isLine: true,
                ),
                _buildLegendItem(
                  color: const Color(0xFFE3EEDF),
                  label: 'Rentang p25–p75',
                  isBox: true,
                ),
                _buildLegendItem(
                  color: const Color(0xFFE8A24F),
                  label: 'Episode kenaikan & puncak',
                  isBox: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimeSeriesLineChart(analysis!),
          ] else if (hasHourlyFallback) ...[
            const SizedBox(height: 4),
            _buildHourlyFallbackBars(),
          ] else ...[
            const SizedBox(height: 4),
            _buildEmptyChartState(),
          ],

          const SizedBox(height: 14),
          Center(
            child: Text(
              footerText,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6F7B74),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool isLine = false,
    bool isBox = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isLine ? 14 : 10,
          height: isLine ? 3 : 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isLine ? 2 : 3),
            border: isBox && color == const Color(0xFFE3EEDF)
                ? Border.all(
                    color: const Color(0xFF1F5C4A).withValues(alpha: 0.4),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF6F7B74),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSeriesLineChart(AnalysisModel analysis) {
    final series = analysis.series;
    final parsedPoints = <({DateTime time, int ms, double bpm, String rawT})>[];

    for (final pt in series) {
      final dt = DateTime.tryParse(pt.t);
      if (dt != null) {
        parsedPoints.add((
          time: dt,
          ms: dt.millisecondsSinceEpoch,
          bpm: pt.bpm.toDouble(),
          rawT: pt.t,
        ));
      }
    }

    if (parsedPoints.isEmpty) {
      return _buildEmptyChartState();
    }

    final firstMs = parsedPoints.first.ms;
    final lastMs = parsedPoints.last.ms;
    const minX = 0.0;
    final maxX = math.max(1.0, (lastMs - firstMs) / 60000.0);

    final int gapMinSeconds =
        (analysis.meta.parameters['gap_min_seconds'] as num?)?.toInt() ?? 150;

    final gapRangesMs = <({int fromMs, int toMs})>[];
    for (final g in analysis.sensorGaps) {
      final f = DateTime.tryParse(g.from)?.millisecondsSinceEpoch;
      final t = DateTime.tryParse(g.to)?.millisecondsSinceEpoch;
      if (f != null && t != null) {
        gapRangesMs.add((fromMs: f, toMs: t));
      }
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < parsedPoints.length; i++) {
      final curr = parsedPoints[i];
      if (i > 0) {
        final prev = parsedPoints[i - 1];
        final diffSec = (curr.ms - prev.ms) / 1000.0;
        final isExplicitGap = gapRangesMs.any(
          (g) =>
              prev.ms >= g.fromMs - 1000 &&
              curr.ms <= g.toMs + 1000 &&
              diffSec > gapMinSeconds,
        );
        if (diffSec > gapMinSeconds || isExplicitGap) {
          spots.add(FlSpot.nullSpot);
        }
      }
      final xMin = (curr.ms - firstMs) / 60000.0;
      spots.add(FlSpot(xMin, curr.bpm));
    }

    final verticalRanges = <VerticalRangeAnnotation>[];
    final peakVerticalLines = <VerticalLine>[];
    final peakSpotKeys = <String>{};

    for (final ep in analysis.episodes) {
      final epStartMs = DateTime.tryParse(ep.start)?.millisecondsSinceEpoch;
      final epEndMs = DateTime.tryParse(ep.end)?.millisecondsSinceEpoch;
      if (epStartMs == null || epEndMs == null) continue;

      final double rawX1 = ((epStartMs - firstMs) / 60000.0).clamp(minX, maxX);
      final double rawX2 = ((epEndMs - firstMs) / 60000.0).clamp(minX, maxX);
      final double minVisualWidth = math.max(0.4, (maxX - minX) * 0.02);
      final double x1 = rawX1;
      final double x2 = math.max(rawX1 + minVisualWidth, rawX2);

      verticalRanges.add(
        VerticalRangeAnnotation(
          x1: x1,
          x2: math.min(maxX, x2),
          color: const Color(0xFFE8A24F).withValues(alpha: 0.24),
        ),
      );

      ({DateTime time, int ms, double bpm, String rawT})? peakPt;
      for (final pt in parsedPoints) {
        if (pt.ms >= epStartMs && pt.ms <= epEndMs) {
          if (peakPt == null || pt.bpm > peakPt.bpm) {
            peakPt = pt;
          }
        }
      }

      if (peakPt != null) {
        final peakX = (peakPt.ms - firstMs) / 60000.0;
        peakSpotKeys.add('${peakX.toStringAsFixed(3)}_${peakPt.bpm.round()}');
        peakVerticalLines.add(
          VerticalLine(
            x: peakX,
            color: const Color(0xFFD97706),
            strokeWidth: 1.2,
            dashArray: [4, 4],
            label: VerticalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB45309),
              ),
              labelResolver: (_) =>
                  '${ep.peakBpm} BPM (${formatTimeWib(ep.start)})',
            ),
          ),
        );
      }
    }

    final horizontalRanges = <HorizontalRangeAnnotation>[];
    final horizontalLines = <HorizontalLine>[];
    final baseline = analysis.baseline;

    if (baseline.sufficient && baseline.p25 != null && baseline.p75 != null) {
      horizontalRanges.add(
        HorizontalRangeAnnotation(
          y1: baseline.p25!,
          y2: baseline.p75!,
          color: const Color(0xFFE3EEDF).withValues(alpha: 0.8),
        ),
      );
      if (baseline.median != null) {
        horizontalLines.add(
          HorizontalLine(
            y: baseline.median!,
            color: const Color(0xFF1F5C4A).withValues(alpha: 0.35),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        );
      }
    }

    double minBpm = parsedPoints.map((e) => e.bpm).reduce(math.min);
    double maxBpm = parsedPoints.map((e) => e.bpm).reduce(math.max);
    if (baseline.p25 != null) minBpm = math.min(minBpm, baseline.p25!);
    if (baseline.p75 != null) maxBpm = math.max(maxBpm, baseline.p75!);

    final double minY = ((minBpm - 10) / 10).floorToDouble() * 10;
    final double maxY = ((maxBpm + 12) / 10).ceilToDouble() * 10;
    final double yInterval =
        math.max(10.0, ((maxY - minY) / 4).roundToDouble());
    final double xInterval = math.max(1.0, (maxX - minX) / 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 210,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (value) => const FlLine(
                  color: Color(0xFFF1F5F9),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                  left: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: horizontalRanges,
                verticalRangeAnnotations: verticalRanges,
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: horizontalLines,
                verticalLines: peakVerticalLines,
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: yInterval,
                    getTitlesWidget: (val, meta) {
                      if (val == minY || val == maxY) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        val.round().toString(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF6F7B74),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: xInterval,
                    getTitlesWidget: (val, meta) {
                      final ms = firstMs + (val * 60000).round();
                      final wib = DateTime.fromMillisecondsSinceEpoch(
                        ms,
                        isUtc: true,
                      ).add(const Duration(hours: 7));
                      final label =
                          '${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')}';
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF6F7B74),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: const Color(0xFF1E2A24),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final ms = firstMs + (spot.x * 60000).round();
                      final wib = DateTime.fromMillisecondsSinceEpoch(
                        ms,
                        isUtc: true,
                      ).add(const Duration(hours: 7));
                      final timeStr =
                          '${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')}';
                      final key =
                          '${spot.x.toStringAsFixed(3)}_${spot.y.round()}';
                      final isPeak = peakSpotKeys.contains(key);
                      final prefix = isPeak ? 'Puncak Episode · ' : '';
                      return LineTooltipItem(
                        '$prefix$timeStr\n${spot.y.round()} BPM',
                        GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: const Color(0xFF1F5C4A),
                  barWidth: 2.2,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final key =
                          '${spot.x.toStringAsFixed(3)}_${spot.y.round()}';
                      if (peakSpotKeys.contains(key)) {
                        return FlDotCirclePainter(
                          radius: 5.0,
                          color: const Color(0xFFE8A24F),
                          strokeWidth: 2.0,
                          strokeColor: Colors.white,
                        );
                      }
                      final showRegularDot = parsedPoints.length <= 80;
                      return FlDotCirclePainter(
                        radius: showRegularDot ? 2.5 : 0.0,
                        color: const Color(0xFF1F5C4A),
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (analysis.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildActivityPinsTimeline(
            notes: analysis.notes,
            firstMs: firstMs,
            lastMs: lastMs,
          ),
        ],
      ],
    );
  }

  Widget _buildActivityPinsTimeline({
    required List<AnalysisNote> notes,
    required int firstMs,
    required int lastMs,
  }) {
    final totalSpanMs = math.max(1, lastMs - firstMs);
    final positionedNotes = <({AnalysisNote note, double ratio, int row})>[];
    final lastRatioPerRow = <int, double>{};

    for (final note in notes) {
      final ms = DateTime.tryParse(note.at)?.millisecondsSinceEpoch;
      final ratio = ms != null
          ? ((ms - firstMs) / totalSpanMs).clamp(0.0, 1.0)
          : 0.5;

      int assignedRow = 0;
      if (lastRatioPerRow.containsKey(0) &&
          (ratio - lastRatioPerRow[0]!).abs() < 0.18) {
        assignedRow = 1;
      }
      lastRatioPerRow[assignedRow] = ratio;
      positionedNotes.add((note: note, ratio: ratio, row: assignedRow));
    }

    final hasSecondRow = positionedNotes.any((p) => p.row == 1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pin catatan kejadian pada grafik',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E2A24),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SizedBox(
                height: hasSecondRow ? 54 : 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: positionedNotes.map((item) {
                    final label =
                        '${formatTimeWib(item.note.at)} · ${getEventTypeName(item.note.type)}';
                    final double left = (item.ratio * (width - 110))
                        .clamp(0.0, math.max(0.0, width - 110))
                        .toDouble();
                    return Positioned(
                      left: left,
                      top: item.row * 26.0,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: math.min(150.0, width),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD9DED6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              getEventTypeIcon(item.note.type),
                              size: 12,
                              color: const Color(0xFF1F5C4A),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E2A24),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyFallbackBars() {
    final p75 = (baselineData != null && baselineData!['sufficient'] == true)
        ? (baselineData!['p75'] as num?)?.toDouble()
        : null;

    return SizedBox(
      height: 130,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: hourlyAverages.map((item) {
          final avg = (item['avg'] as num).toDouble();
          final label = item['label'].toString();

          final isAboveP75 = p75 != null && avg > p75;
          final barColor = isAboveP75
              ? const Color(0xFFE8A24F)
              : const Color(0xFFE3EEDF);

          final heightRatio = ((avg - 40) / 100).clamp(0.15, 1.0);
          final barHeight = heightRatio * 90;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                avg.round().toString(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6F7B74),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: barHeight,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6F7B74),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyChartState() {
    return SizedBox(
      height: 130,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                return Container(
                  width: 24,
                  height: 40 + (index % 3) * 15.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F4EF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFD9DED6)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            Text(
              'Belum ada data',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6F7B74),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

