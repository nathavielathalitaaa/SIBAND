import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/analysis_model.dart';
import '../utils/event_type_helper.dart';

/// Jumlah menit data yang terlihat dalam satu layar (viewport) grafik.
const double visibleMinutes = 60;

const double _yAxisWidth = 34;
const double _plotHeight = 180;
const double _xLabelHeight = 22;
const double _plotPadX = 8;
const double _tapRadius = 16;
const double _pinHeaderHeight = 18;

const Color _colorBelow = Color(0xFF8FA3B5);
const Color _colorNormal = Color(0xFF2F8F83);
const Color _colorAbove = Color(0xFFE8A24F);
const Color _colorEpisode = Color(0xFFEA7A1E);
const Color _colorNeutral = Color(0xFF6F7B74);

typedef _Pt = ({int ms, double x, double bpm, String rawT});

class _ChartGeometry {
  final List<_Pt> points;
  final int firstMs;
  final int lastMs;
  final double maxX;
  final double minY;
  final double maxY;
  final double yInterval;
  final double canvasW;

  const _ChartGeometry({
    required this.points,
    required this.firstMs,
    required this.lastMs,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.yInterval,
    required this.canvasW,
  });

  double get plotW => canvasW - 2 * _plotPadX;

  double xPx(double minutes) =>
      _plotPadX + (minutes / maxX).clamp(0.0, 1.0) * plotW;

  double yPx(double bpm) => _plotHeight * (maxY - bpm) / (maxY - minY);

  Offset offsetOf(_Pt p) => Offset(xPx(p.x), yPx(p.bpm));
}

class HomeMonitoringChartCard extends StatefulWidget {
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
  State<HomeMonitoringChartCard> createState() =>
      _HomeMonitoringChartCardState();
}

class _HomeMonitoringChartCardState extends State<HomeMonitoringChartCard> {
  final ScrollController _scrollController = ScrollController();
  int? _selectedMs;
  bool _showJumpToNow = false;

  AnalysisModel? get _analysis => widget.analysisData;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _jumpToEndAfterFrame();
  }

  @override
  void didUpdateWidget(covariant HomeMonitoringChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analysisData != widget.analysisData) {
      final wasAtEnd =
          !_scrollController.hasClients ||
          (_scrollController.position.maxScrollExtent -
                  _scrollController.position.pixels) <=
              2;
      if (wasAtEnd) _jumpToEndAfterFrame();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToEndAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      _onScroll();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final far = (pos.maxScrollExtent - pos.pixels) > pos.viewportDimension;
    if (far != _showJumpToNow && mounted) {
      setState(() => _showJumpToNow = far);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysisData;
    final series = analysis?.series ?? const <AnalysisSeriesPoint>[];
    final bool hasTimeSeries = series.isNotEmpty;
    final bool hasHourlyFallback =
        !hasTimeSeries && widget.hourlyAverages.isNotEmpty;

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

    final bool showResolutionNote =
        hasTimeSeries && (analysis?.resolutionSeconds ?? 0) > 1;

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
                    if (showResolutionNote) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Tiap titik = nilai tengah per ${analysis!.resolutionSeconds} detik',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF6F7B74),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.isLoadingAnalysis)
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
                  color: _colorNormal,
                  label: 'BPM aktual',
                  isDot: true,
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
            _buildTimeSeriesScatterChart(analysis!),
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
    bool isDot = false,
    bool isBox = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isDot ? 8 : 10,
          height: isDot ? 8 : 10,
          decoration: BoxDecoration(
            color: color,
            shape: isDot ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isDot ? null : BorderRadius.circular(3),
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

  /// Status terhadap baseline (aturan sama dengan kartu BPM di Beranda).
  static String _statusLabel({
    required int bpm,
    required bool sufficient,
    required double? p25,
    required double? p75,
    required int margin,
  }) {
    if (sufficient && p25 != null && p75 != null) {
      final threshold = p75 + margin;
      if (bpm <= p75) return 'Dalam rentang biasa';
      if (bpm <= threshold) return 'Sedikit di atas baseline';
      return 'Jauh di atas baseline';
    }
    if (!sufficient) return 'Baseline belum cukup data';
    return 'Belum ada pembacaan';
  }

  static String _clockFromRaw(String raw, {required bool withSeconds}) {
    final m = RegExp(r'T(\d{2}):(\d{2}):(\d{2})').firstMatch(raw);
    if (m != null) {
      return withSeconds
          ? '${m.group(1)}.${m.group(2)}.${m.group(3)}'
          : '${m.group(1)}.${m.group(2)}';
    }
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final wib = dt.toUtc().add(const Duration(hours: 7));
    final hh = wib.hour.toString().padLeft(2, '0');
    final mm = wib.minute.toString().padLeft(2, '0');
    final ss = wib.second.toString().padLeft(2, '0');
    return withSeconds ? '$hh.$mm.$ss' : '$hh.$mm';
  }

  void _handleTap(Offset local, _ChartGeometry g) {
    _Pt? best;
    double bestDistance = _tapRadius;
    for (final p in g.points) {
      final d = (g.offsetOf(p) - local).distance;
      if (d <= bestDistance) {
        best = p;
        bestDistance = d;
      }
    }
    setState(() => _selectedMs = best?.ms);
  }

  Widget _buildTimeSeriesScatterChart(AnalysisModel analysis) {
    final parsed = <_Pt>[];
    for (final pt in analysis.series) {
      final dt = DateTime.tryParse(pt.t);
      if (dt != null) {
        parsed.add((
          ms: dt.millisecondsSinceEpoch,
          x: 0.0,
          bpm: pt.bpm.toDouble(),
          rawT: pt.t,
        ));
      }
    }
    if (parsed.isEmpty) return _buildEmptyChartState();
    parsed.sort((a, b) => a.ms.compareTo(b.ms));

    final firstMs = parsed.first.ms;
    final lastMs = parsed.last.ms;
    final double maxX = math.max(1.0, (lastMs - firstMs) / 60000.0);
    final points = parsed
        .map(
          (p) => (
            ms: p.ms,
            x: (p.ms - firstMs) / 60000.0,
            bpm: p.bpm,
            rawT: p.rawT,
          ),
        )
        .toList();

    final baseline = analysis.baseline;
    final bool sufficient =
        baseline.sufficient && baseline.p25 != null && baseline.p75 != null;
    final int episodeMargin =
        (analysis.meta.parameters['episode_margin_bpm'] as num?)?.toInt() ?? 10;

    double minBpm = points.map((e) => e.bpm).reduce(math.min);
    double maxBpm = points.map((e) => e.bpm).reduce(math.max);
    if (baseline.p25 != null) minBpm = math.min(minBpm, baseline.p25!);
    if (baseline.p75 != null) maxBpm = math.max(maxBpm, baseline.p75!);
    final double minY = ((minBpm - 10) / 10).floorToDouble() * 10;
    final double maxY = ((maxBpm + 12) / 10).ceilToDouble() * 10;
    final double yInterval = math.max(
      10.0,
      ((maxY - minY) / 4).roundToDouble(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double viewport = constraints.maxWidth - _yAxisWidth;
        final double canvasW = math.max(
          viewport,
          maxX / visibleMinutes * viewport,
        );
        final g = _ChartGeometry(
          points: points,
          firstMs: firstMs,
          lastMs: lastMs,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          yInterval: yInterval,
          canvasW: canvasW,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildChartArea(analysis, g, viewport, sufficient, episodeMargin),
            _buildSelectedPanel(analysis, g, sufficient, episodeMargin),
          ],
        );
      },
    );
  }

  Widget _buildChartArea(
    AnalysisModel analysis,
    _ChartGeometry g,
    double viewport,
    bool sufficient,
    int episodeMargin,
  ) {
    final baseline = analysis.baseline;
    final p25 = baseline.p25;
    final p75 = baseline.p75;

    // Titik (scatter)
    final spots = g.points.map((p) {
      final style = _dotStyle(p.bpm, sufficient, p75, episodeMargin);
      return ScatterSpot(p.x, p.bpm, radius: style.radius, color: style.color);
    }).toList();

    // Blok episode
    final episodeBlocks = <Widget>[];
    for (final ep in analysis.episodes) {
      final s = DateTime.tryParse(ep.start)?.millisecondsSinceEpoch;
      final e = DateTime.tryParse(ep.end)?.millisecondsSinceEpoch;
      if (s == null || e == null) continue;
      final left = g.xPx((s - g.firstMs) / 60000.0);
      final right = g.xPx((e - g.firstMs) / 60000.0);
      final width = math.max(8.0, right - left);
      episodeBlocks.add(
        Positioned(
          left: left,
          top: 0,
          width: width,
          height: _plotHeight,
          child: Container(
            color: _colorAbove.withValues(alpha: 0.24),
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFB45309),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+${ep.deltaFromMedian.round()}',
                maxLines: 1,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Area jeda sensor
    final gapRects = <(double, double)>[];
    for (final gap in analysis.sensorGaps) {
      final f = DateTime.tryParse(gap.from)?.millisecondsSinceEpoch;
      final t = DateTime.tryParse(gap.to)?.millisecondsSinceEpoch;
      if (f == null || t == null) continue;
      gapRects.add((
        g.xPx((f - g.firstMs) / 60000.0),
        g.xPx((t - g.firstMs) / 60000.0),
      ));
    }

    final yTicks = <double>[];
    for (double v = g.minY; v <= g.maxY + 0.001; v += g.yInterval) {
      yTicks.add(v);
    }

    // Label sumbu X
    final double pxPerMin = g.plotW / g.maxX;
    const steps = [1, 2, 5, 10, 15, 30, 60, 120, 240];
    final int stepMin = steps.firstWhere(
      (s) => s * pxPerMin >= 56,
      orElse: () => steps.last,
    );
    final xLabels = <Widget>[];
    for (int m = 0; m <= g.maxX.floor(); m += stepMin) {
      final ms = g.firstMs + m * 60000;
      final wib = DateTime.fromMillisecondsSinceEpoch(
        ms,
        isUtc: true,
      ).add(const Duration(hours: 7));
      final label =
          '${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')}';
      xLabels.add(
        Positioned(
          left: g.xPx(m.toDouble()) - 24,
          top: 6,
          width: 48,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF6F7B74),
            ),
          ),
        ),
      );
    }

    // Pin catatan
    final hasNotes = analysis.notes.isNotEmpty;
    final pins = <Widget>[];
    bool hasSecondRow = false;
    if (hasNotes) {
      final totalSpanMs = math.max(1, g.lastMs - g.firstMs);
      double? lastRow0Px;
      for (final note in analysis.notes) {
        final ms = DateTime.tryParse(note.at)?.millisecondsSinceEpoch;
        final ratio = ms != null
            ? ((ms - g.firstMs) / totalSpanMs).clamp(0.0, 1.0)
            : 0.5;
        final px = _plotPadX + ratio * g.plotW;
        int row = 0;
        if (lastRow0Px != null && (px - lastRow0Px).abs() < 120) {
          row = 1;
          hasSecondRow = true;
        } else {
          lastRow0Px = px;
        }
        final double left = (px - 8)
            .clamp(0.0, math.max(0.0, g.canvasW - 150))
            .toDouble();
        final label =
            '${HomeMonitoringChartCard.formatTimeWib(note.at)} · ${getEventTypeName(note.type)}';
        pins.add(
          Positioned(
            left: left,
            top: _pinHeaderHeight + row * 26.0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 150),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD9DED6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    getEventTypeIcon(note.type),
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
          ),
        );
      }
    }
    final double laneHeight = hasSecondRow ? 54 : 28;
    final double pinsSectionHeight = _pinHeaderHeight + laneHeight + 6;

    _Pt? selected;
    for (final p in g.points) {
      if (p.ms == _selectedMs) selected = p;
    }

    final canvas = SizedBox(
      width: g.canvasW,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _handleTap(d.localPosition, g),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              key: const Key('chart_plot'),
              width: g.canvasW,
              height: _plotHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PlotBackgroundPainter(
                        g: g,
                        yTicks: yTicks,
                        bandP25: sufficient ? p25 : null,
                        bandP75: sufficient ? p75 : null,
                        median: sufficient ? baseline.median : null,
                        gapRects: gapRects,
                      ),
                    ),
                  ),
                  ...episodeBlocks,
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _plotPadX,
                      ),
                      child: ScatterChart(
                        ScatterChartData(
                          minX: 0,
                          maxX: g.maxX,
                          minY: g.minY,
                          maxY: g.maxY,
                          scatterSpots: spots,
                          backgroundColor: Colors.transparent,
                          clipData: const FlClipData.none(),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          scatterTouchData: ScatterTouchData(enabled: false),
                        ),
                        swapAnimationDuration: Duration.zero,
                      ),
                    ),
                  ),
                  if (selected != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          key: const Key('chart_selection_ring'),
                          painter: _RingPainter(g.offsetOf(selected)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: _xLabelHeight,
              width: g.canvasW,
              child: Stack(children: xLabels),
            ),
            if (hasNotes)
              Container(
                width: g.canvasW,
                height: pinsSectionHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F4EF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(children: pins),
              ),
          ],
        ),
      ),
    );

    final double scrollHeight =
        _plotHeight + _xLabelHeight + (hasNotes ? pinsSectionHeight : 0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          key: const Key('chart_y_axis'),
          width: _yAxisWidth,
          height: _plotHeight + _xLabelHeight,
          child: Stack(
            children: [
              for (final v in yTicks)
                if (v != g.minY && v != g.maxY)
                  Positioned(
                    top: g.yPx(v) - 7,
                    left: 0,
                    right: 6,
                    child: Text(
                      v.round().toString(),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF6F7B74),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        Expanded(
          child: SizedBox(
            height: scrollHeight,
            child: Stack(
              children: [
                SingleChildScrollView(
                  key: const Key('chart_scroll'),
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: canvas,
                ),
                if (hasNotes)
                  Positioned(
                    left: 8,
                    bottom: laneHeight + 8,
                    child: IgnorePointer(
                      child: Text(
                        'Pin catatan kejadian pada grafik',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E2A24),
                        ),
                      ),
                    ),
                  ),
                if (_showJumpToNow)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: TextButton(
                      key: const Key('chart_jump_to_now'),
                      onPressed: () {
                        if (!_scrollController.hasClients) return;
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.92),
                        foregroundColor: const Color(0xFF1F5C4A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: Color(0xFFD9DED6)),
                      ),
                      child: Text(
                        'Ke sekarang',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  ({Color color, double radius}) _dotStyle(
    double bpm,
    bool sufficient,
    double? p75,
    int margin,
  ) {
    if (!sufficient || p75 == null) {
      return (color: _colorNeutral, radius: 3.5);
    }
    final p25 = _analysis?.baseline.p25;
    if (p25 != null && bpm < p25) return (color: _colorBelow, radius: 3);
    if (bpm <= p75) return (color: _colorNormal, radius: 3);
    if (bpm <= p75 + margin) return (color: _colorAbove, radius: 4.5);
    return (color: _colorEpisode, radius: 6);
  }

  Widget _buildSelectedPanel(
    AnalysisModel analysis,
    _ChartGeometry g,
    bool sufficient,
    int episodeMargin,
  ) {
    _Pt? pt;
    for (final p in g.points) {
      if (p.ms == _selectedMs) pt = p;
    }
    if (pt == null) return const SizedBox.shrink();

    final baseline = analysis.baseline;
    final bpm = pt.bpm.round();
    final bool minuteOnly = analysis.resolutionSeconds >= 60;
    final clock = _clockFromRaw(pt.rawT, withSeconds: !minuteOnly);
    final status = _statusLabel(
      bpm: bpm,
      sufficient: sufficient,
      p25: baseline.p25,
      p75: baseline.p75,
      margin: episodeMargin,
    );

    String? episodeText;
    for (final ep in analysis.episodes) {
      final s = DateTime.tryParse(ep.start)?.millisecondsSinceEpoch;
      final e = DateTime.tryParse(ep.end)?.millisecondsSinceEpoch;
      if (s == null || e == null) continue;
      if (pt.ms >= s && pt.ms <= e) {
        final median = baseline.median;
        final diff = median != null ? (pt.bpm - median).round() : null;
        episodeText = (diff != null && diff > 0)
            ? 'Bagian dari episode ${ep.index} (+$diff di atas median)'
            : 'Bagian dari episode ${ep.index}';
        break;
      }
    }

    return Container(
      key: const Key('chart_detail_panel'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$clock · $bpm bpm',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E2A24),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6F7B74),
                  ),
                ),
                if (episodeText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    episodeText,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedMs = null),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1F5C4A),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Tutup',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyFallbackBars() {
    final p75 =
        (widget.baselineData != null &&
            widget.baselineData!['sufficient'] == true)
        ? (widget.baselineData!['p75'] as num?)?.toDouble()
        : null;

    return SizedBox(
      height: 130,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: widget.hourlyAverages.map((item) {
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

class _PlotBackgroundPainter extends CustomPainter {
  final _ChartGeometry g;
  final List<double> yTicks;
  final double? bandP25;
  final double? bandP75;
  final double? median;
  final List<(double, double)> gapRects;

  _PlotBackgroundPainter({
    required this.g,
    required this.yTicks,
    required this.bandP25,
    required this.bandP75,
    required this.median,
    required this.gapRects,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bandP25 != null && bandP75 != null) {
      final top = g.yPx(bandP75!);
      final bottom = g.yPx(bandP25!);
      canvas.drawRect(
        Rect.fromLTRB(0, top, size.width, bottom),
        Paint()..color = const Color(0xFFE3EEDF).withValues(alpha: 0.8),
      );
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;
    for (final v in yTicks) {
      final y = g.yPx(v);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final r in gapRects) {
      final left = math.min(r.$1, r.$2);
      final right = math.max(math.max(r.$1, r.$2), left + 6);
      final rect = Rect.fromLTRB(left, 0, right, size.height);
      canvas.save();
      canvas.clipRect(rect);
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF94A3B8).withValues(alpha: 0.10),
      );
      final hatch = Paint()
        ..color = const Color(0xFF94A3B8).withValues(alpha: 0.55)
        ..strokeWidth = 1;
      for (double x = left - size.height; x < right; x += 7) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          hatch,
        );
      }
      canvas.restore();
    }

    if (median != null) {
      final y = g.yPx(median!);
      final paint = Paint()
        ..color = const Color(0xFF1F5C4A).withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width), y),
          paint,
        );
      }
    }

    final axisPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint);
  }

  @override
  bool shouldRepaint(covariant _PlotBackgroundPainter old) => true;
}

class _RingPainter extends CustomPainter {
  final Offset center;
  _RingPainter(this.center);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..color = const Color(0xFF1E2A24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.center != center;
}
