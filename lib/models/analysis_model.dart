int _parseInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value != null) return int.tryParse(value.toString()) ?? fallback;
  return fallback;
}

int? _parseNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _parseDouble(dynamic value, [double fallback = 0.0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value != null) return double.tryParse(value.toString()) ?? fallback;
  return fallback;
}

double? _parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

num _parseNum(dynamic value, [num fallback = 0]) {
  if (value is num) return value;
  if (value != null) return num.tryParse(value.toString()) ?? fallback;
  return fallback;
}

bool _parseBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return fallback;
}

class AnalysisModel {
  final AnalysisChild child;
  final AnalysisWindow window;
  final AnalysisBaseline baseline;
  final AnalysisCurrent current;
  final List<AnalysisSeriesPoint> series;
  final int resolutionSeconds;
  final List<AnalysisSensorGap> sensorGaps;
  final List<AnalysisNote> notes;
  final List<AnalysisEpisode> episodes;
  final AnalysisPatterns patterns;
  final AnalysisQuality quality;
  final AnalysisMeta meta;

  const AnalysisModel({
    required this.child,
    required this.window,
    required this.baseline,
    required this.current,
    required this.series,
    required this.resolutionSeconds,
    required this.sensorGaps,
    required this.notes,
    required this.episodes,
    required this.patterns,
    required this.quality,
    required this.meta,
  });

  factory AnalysisModel.fromJson(Map<String, dynamic> json) {
    final rawSeries = json['series'];
    final rawGaps = json['sensor_gaps'];
    final rawNotes = json['notes'];
    final rawEpisodes = json['episodes'];

    return AnalysisModel(
      child: AnalysisChild.fromJson(
        json['child'] is Map<String, dynamic>
            ? json['child'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      window: AnalysisWindow.fromJson(
        json['window'] is Map<String, dynamic>
            ? json['window'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      baseline: AnalysisBaseline.fromJson(
        json['baseline'] is Map<String, dynamic>
            ? json['baseline'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      current: AnalysisCurrent.fromJson(
        json['current'] is Map<String, dynamic>
            ? json['current'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      series: rawSeries is List
          ? rawSeries
              .whereType<Map<String, dynamic>>()
              .map(AnalysisSeriesPoint.fromJson)
              .toList()
          : const <AnalysisSeriesPoint>[],
      resolutionSeconds: _parseInt(json['resolution_seconds']),
      sensorGaps: rawGaps is List
          ? rawGaps
              .whereType<Map<String, dynamic>>()
              .map(AnalysisSensorGap.fromJson)
              .toList()
          : const <AnalysisSensorGap>[],
      notes: rawNotes is List
          ? rawNotes
              .whereType<Map<String, dynamic>>()
              .map(AnalysisNote.fromJson)
              .toList()
          : const <AnalysisNote>[],
      episodes: rawEpisodes is List
          ? rawEpisodes
              .whereType<Map<String, dynamic>>()
              .map(AnalysisEpisode.fromJson)
              .toList()
          : const <AnalysisEpisode>[],
      patterns: AnalysisPatterns.fromJson(
        json['patterns'] is Map<String, dynamic>
            ? json['patterns'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      quality: AnalysisQuality.fromJson(
        json['quality'] is Map<String, dynamic>
            ? json['quality'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      meta: AnalysisMeta.fromJson(
        json['meta'] is Map<String, dynamic>
            ? json['meta'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'child': child.toJson(),
      'window': window.toJson(),
      'baseline': baseline.toJson(),
      'current': current.toJson(),
      'series': series.map((e) => e.toJson()).toList(),
      'resolution_seconds': resolutionSeconds,
      'sensor_gaps': sensorGaps.map((e) => e.toJson()).toList(),
      'notes': notes.map((e) => e.toJson()).toList(),
      'episodes': episodes.map((e) => e.toJson()).toList(),
      'patterns': patterns.toJson(),
      'quality': quality.toJson(),
      'meta': meta.toJson(),
    };
  }
}

class AnalysisChild {
  final int id;
  final String name;
  final String nickname;

  const AnalysisChild({
    required this.id,
    required this.name,
    required this.nickname,
  });

  factory AnalysisChild.fromJson(Map<String, dynamic> json) {
    final nameVal = json['name']?.toString();
    final nicknameVal = json['nickname']?.toString();
    return AnalysisChild(
      id: _parseInt(json['id']),
      name: nameVal ?? nicknameVal ?? '',
      nickname: nicknameVal ?? nameVal ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nickname': nickname,
    };
  }
}

class AnalysisWindow {
  final String from;
  final String to;
  final String timezone;

  const AnalysisWindow({
    required this.from,
    required this.to,
    required this.timezone,
  });

  factory AnalysisWindow.fromJson(Map<String, dynamic> json) {
    return AnalysisWindow(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      timezone: json['timezone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'timezone': timezone,
    };
  }
}

class AnalysisBaseline {
  final bool sufficient;
  final int sampleCount;
  final int minSamples;
  final double? median;
  final double? p25;
  final double? p75;

  const AnalysisBaseline({
    required this.sufficient,
    required this.sampleCount,
    required this.minSamples,
    required this.median,
    required this.p25,
    required this.p75,
  });

  factory AnalysisBaseline.fromJson(Map<String, dynamic> json) {
    return AnalysisBaseline(
      sufficient: _parseBool(json['sufficient']),
      sampleCount: _parseInt(json['sample_count']),
      minSamples: _parseInt(json['min_samples']),
      median: _parseNullableDouble(json['median']),
      p25: _parseNullableDouble(json['p25']),
      p75: _parseNullableDouble(json['p75']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sufficient': sufficient,
      'sample_count': sampleCount,
      'min_samples': minSamples,
      'median': median,
      'p25': p25,
      'p75': p75,
    };
  }
}

class AnalysisCurrent {
  final int? bpm;
  final String? recordedAt;
  final int? ageSeconds;
  final String status;
  final String measurementState;
  final int expectedRestSeconds;

  const AnalysisCurrent({
    required this.bpm,
    required this.recordedAt,
    required this.ageSeconds,
    required this.status,
    required this.measurementState,
    required this.expectedRestSeconds,
  });

  factory AnalysisCurrent.fromJson(Map<String, dynamic> json) {
    return AnalysisCurrent(
      bpm: _parseNullableInt(json['bpm']),
      recordedAt: json['recorded_at']?.toString(),
      ageSeconds: _parseNullableInt(json['age_seconds']),
      status: json['status']?.toString() ?? '',
      measurementState: json['measurement_state']?.toString() ?? '',
      expectedRestSeconds: _parseInt(json['expected_rest_seconds']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bpm': bpm,
      'recorded_at': recordedAt,
      'age_seconds': ageSeconds,
      'status': status,
      'measurement_state': measurementState,
      'expected_rest_seconds': expectedRestSeconds,
    };
  }
}

class AnalysisSeriesPoint {
  final String t;
  final num bpm;

  const AnalysisSeriesPoint({
    required this.t,
    required this.bpm,
  });

  factory AnalysisSeriesPoint.fromJson(Map<String, dynamic> json) {
    return AnalysisSeriesPoint(
      t: json['t']?.toString() ?? '',
      bpm: _parseNum(json['bpm']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      't': t,
      'bpm': bpm,
    };
  }
}

class AnalysisSensorGap {
  final String from;
  final String to;
  final int durationSeconds;

  const AnalysisSensorGap({
    required this.from,
    required this.to,
    required this.durationSeconds,
  });

  factory AnalysisSensorGap.fromJson(Map<String, dynamic> json) {
    return AnalysisSensorGap(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      durationSeconds: _parseInt(json['duration_seconds']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'duration_seconds': durationSeconds,
    };
  }
}

class AnalysisNote {
  final int id;
  final String type;
  final String at;
  final String textPreview;

  const AnalysisNote({
    required this.id,
    required this.type,
    required this.at,
    required this.textPreview,
  });

  factory AnalysisNote.fromJson(Map<String, dynamic> json) {
    return AnalysisNote(
      id: _parseInt(json['id']),
      type: json['type']?.toString() ?? '',
      at: json['at']?.toString() ?? '',
      textPreview: json['text_preview']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'at': at,
      'text_preview': textPreview,
    };
  }
}

class AnalysisEpisode {
  final int index;
  final String start;
  final String end;
  final int durationSeconds;
  final int peakBpm;
  final double deltaFromMedian;
  final bool hasSensorGap;
  final AnalysisNote? note;

  const AnalysisEpisode({
    required this.index,
    required this.start,
    required this.end,
    required this.durationSeconds,
    required this.peakBpm,
    required this.deltaFromMedian,
    required this.hasSensorGap,
    required this.note,
  });

  factory AnalysisEpisode.fromJson(Map<String, dynamic> json) {
    final rawNote = json['note'];
    return AnalysisEpisode(
      index: _parseInt(json['index']),
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
      durationSeconds: _parseInt(json['duration_seconds']),
      peakBpm: _parseInt(json['peak_bpm']),
      deltaFromMedian: _parseDouble(json['delta_from_median']),
      hasSensorGap: _parseBool(json['has_sensor_gap']),
      note: rawNote is Map<String, dynamic>
          ? AnalysisNote.fromJson(rawNote)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'start': start,
      'end': end,
      'duration_seconds': durationSeconds,
      'peak_bpm': peakBpm,
      'delta_from_median': deltaFromMedian,
      'has_sensor_gap': hasSensorGap,
      'note': note?.toJson(),
    };
  }
}

class AnalysisPatterns {
  final bool sufficient;
  final List<AnalysisHourlyPattern> hourly;
  final List<AnalysisNoteTypePattern> byNoteType;

  const AnalysisPatterns({
    required this.sufficient,
    required this.hourly,
    required this.byNoteType,
  });

  factory AnalysisPatterns.fromJson(Map<String, dynamic> json) {
    final rawHourly = json['hourly'];
    final rawByNoteType = json['by_note_type'];

    return AnalysisPatterns(
      sufficient: _parseBool(json['sufficient']),
      hourly: rawHourly is List
          ? rawHourly
              .whereType<Map<String, dynamic>>()
              .map(AnalysisHourlyPattern.fromJson)
              .toList()
          : const <AnalysisHourlyPattern>[],
      byNoteType: rawByNoteType is List
          ? rawByNoteType
              .whereType<Map<String, dynamic>>()
              .map(AnalysisNoteTypePattern.fromJson)
              .toList()
          : const <AnalysisNoteTypePattern>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sufficient': sufficient,
      'hourly': hourly.map((e) => e.toJson()).toList(),
      'by_note_type': byNoteType.map((e) => e.toJson()).toList(),
    };
  }
}

class AnalysisHourlyPattern {
  final int hour;
  final int episodeCount;

  const AnalysisHourlyPattern({
    required this.hour,
    required this.episodeCount,
  });

  factory AnalysisHourlyPattern.fromJson(Map<String, dynamic> json) {
    return AnalysisHourlyPattern(
      hour: _parseInt(json['hour']),
      episodeCount: _parseInt(json['episode_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'episode_count': episodeCount,
    };
  }
}

class AnalysisNoteTypePattern {
  final String type;
  final int? avgRiseBpm;
  final int notesUsed;
  final int notesTotal;
  final bool enough;

  const AnalysisNoteTypePattern({
    required this.type,
    required this.avgRiseBpm,
    required this.notesUsed,
    required this.notesTotal,
    required this.enough,
  });

  factory AnalysisNoteTypePattern.fromJson(Map<String, dynamic> json) {
    return AnalysisNoteTypePattern(
      type: json['type']?.toString() ?? '',
      avgRiseBpm: _parseNullableInt(json['avg_rise_bpm']),
      notesUsed: _parseInt(json['notes_used']),
      notesTotal: _parseInt(json['notes_total']),
      enough: _parseBool(json['enough']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'avg_rise_bpm': avgRiseBpm,
      'notes_used': notesUsed,
      'notes_total': notesTotal,
      'enough': enough,
    };
  }
}

class AnalysisQuality {
  final int windowSeconds;
  final int measuredSeconds;
  final double coveragePercent;
  final int sampleCount;
  final int gapCount;
  final int gapTotalSeconds;
  final List<AnalysisHourlyQuality> perHour;

  const AnalysisQuality({
    required this.windowSeconds,
    required this.measuredSeconds,
    required this.coveragePercent,
    required this.sampleCount,
    required this.gapCount,
    required this.gapTotalSeconds,
    required this.perHour,
  });

  factory AnalysisQuality.fromJson(Map<String, dynamic> json) {
    final rawPerHour = json['per_hour'];

    return AnalysisQuality(
      windowSeconds: _parseInt(json['window_seconds']),
      measuredSeconds: _parseInt(json['measured_seconds']),
      coveragePercent: _parseDouble(json['coverage_percent']),
      sampleCount: _parseInt(json['sample_count']),
      gapCount: _parseInt(json['gap_count']),
      gapTotalSeconds: _parseInt(json['gap_total_seconds']),
      perHour: rawPerHour is List
          ? rawPerHour
              .whereType<Map<String, dynamic>>()
              .map(AnalysisHourlyQuality.fromJson)
              .toList()
          : const <AnalysisHourlyQuality>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'window_seconds': windowSeconds,
      'measured_seconds': measuredSeconds,
      'coverage_percent': coveragePercent,
      'sample_count': sampleCount,
      'gap_count': gapCount,
      'gap_total_seconds': gapTotalSeconds,
      'per_hour': perHour.map((e) => e.toJson()).toList(),
    };
  }
}

class AnalysisHourlyQuality {
  final int hour;
  final double coveragePercent;

  const AnalysisHourlyQuality({
    required this.hour,
    required this.coveragePercent,
  });

  factory AnalysisHourlyQuality.fromJson(Map<String, dynamic> json) {
    return AnalysisHourlyQuality(
      hour: _parseInt(json['hour']),
      coveragePercent: _parseDouble(json['coverage_percent']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'coverage_percent': coveragePercent,
    };
  }
}

class AnalysisMeta {
  final Map<String, dynamic> parameters;
  final List<String> limitations;

  const AnalysisMeta({
    required this.parameters,
    required this.limitations,
  });

  factory AnalysisMeta.fromJson(Map<String, dynamic> json) {
    final rawParams = json['parameters'];
    final rawLimitations = json['limitations'];

    return AnalysisMeta(
      parameters: rawParams is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawParams)
          : const <String, dynamic>{},
      limitations: rawLimitations is List
          ? rawLimitations.map((e) => e.toString()).toList()
          : const <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parameters': parameters,
      'limitations': limitations,
    };
  }
}

