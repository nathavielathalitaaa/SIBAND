<?php

namespace App\Services;

use App\Models\Child;
use App\Models\EventNote;
use App\Models\HeartRateLog;
use Carbon\Carbon;
use Illuminate\Support\Str;

class AnalysisService
{
    public const MIN_BASELINE_SAMPLES = 100;
    public const MIN_VALID_BPM = 40;
    public const MAX_VALID_BPM = 200;

    protected BaselineService $baselineService;

    public function __construct(BaselineService $baselineService)
    {
        $this->baselineService = $baselineService;
    }

    /**
     * Compute comprehensive heart-rate and event-note analysis for a child within [from, to].
     */
    public function analyze(Child $child, Carbon $from, Carbon $to, ?string $tz = null): array
    {
        $tz = $tz ?? (string) config('analysis.default_timezone', 'Asia/Jakarta');
        $appTz = (string) config('app.timezone', 'UTC');
        $now = Carbon::now($tz);

        $fromLocal = $from->copy()->setTimezone($tz);
        $toLocal = $to->copy()->setTimezone($tz);
        $fromDb = $fromLocal->copy()->setTimezone($appTz);
        $toDb = $toLocal->copy()->setTimezone($appTz);

        $gapMinSeconds = (int) config('analysis.gap_min_seconds', 150);
        $staleAfterSeconds = (int) config('analysis.stale_after_seconds', 420);
        $expectedRestSeconds = (int) config('analysis.expected_rest_seconds', 300);
        $episodeMarginBpm = (int) config('analysis.episode_margin_bpm', 10);
        $episodeMinDurationSeconds = (int) config('analysis.episode_min_duration_seconds', 120);
        $noteMatchSeconds = (int) config('analysis.note_match_seconds', 300);
        $patternWindowSeconds = (int) config('analysis.pattern_window_seconds', 600);
        $minNotesPerType = (int) config('analysis.min_notes_per_type', 5);
        $maxSpanDays = (int) config('analysis.max_span_days', 7);
        $chartMaxPoints = (int) config('analysis.chart_max_points', 1500);

        // 1. Valid samples within window (BPM 40-200), ordered by recorded_at
        $samples = HeartRateLog::where('child_id', $child->id)
            ->whereBetween('bpm', [self::MIN_VALID_BPM, self::MAX_VALID_BPM])
            ->whereBetween('recorded_at', [$fromDb, $toDb])
            ->orderBy('recorded_at')
            ->orderBy('id')
            ->get();

        // 2. Baseline from existing BaselineService
        $rawBaseline = $this->baselineService->computeBaseline($child, $maxSpanDays);
        $baselineSufficient = (bool) ($rawBaseline['sufficient'] ?? false);
        $baselineSampleCount = (int) ($rawBaseline['sample_count'] ?? 0);

        $median = $baselineSufficient ? $rawBaseline['median'] : null;
        $p25 = $baselineSufficient ? $rawBaseline['p25'] : null;
        $p75 = $baselineSufficient ? $rawBaseline['p75'] : null;

        $baselinePayload = [
            'sufficient' => $baselineSufficient,
            'sample_count' => $baselineSampleCount,
            'min_samples' => self::MIN_BASELINE_SAMPLES,
            'median' => $median,
            'p25' => $p25,
            'p75' => $p75,
        ];

        // 3. Sensor gaps (consecutive valid samples with diff > gap_min_seconds)
        $sensorGaps = [];
        $sampleCount = $samples->count();
        for ($i = 1; $i < $sampleCount; $i++) {
            $prevTime = Carbon::parse($samples[$i - 1]->recorded_at)->setTimezone($tz);
            $currTime = Carbon::parse($samples[$i]->recorded_at)->setTimezone($tz);
            $diffSec = (int) round($prevTime->diffInSeconds($currTime, false));
            if ($diffSec > $gapMinSeconds) {
                $sensorGaps[] = [
                    'from' => $prevTime->toIso8601String(),
                    'to' => $currTime->toIso8601String(),
                    'duration_seconds' => $diffSec,
                ];
            }
        }

        // 4. Series (no interpolation inside gaps; downsample by median per bucket if > chart_max_points)
        $windowSeconds = max(0, (int) round($fromLocal->diffInSeconds($toLocal, false)));
        $resolutionSeconds = 0;
        $series = [];

        if ($sampleCount > $chartMaxPoints) {
            $resolutionSeconds = $windowSeconds <= 86400 ? 60 : 300;
            $fromTs = $fromLocal->getTimestamp();
            $buckets = [];
            foreach ($samples as $sample) {
                $sampleTime = Carbon::parse($sample->recorded_at)->setTimezone($tz);
                $bucketIndex = intdiv(max(0, $sampleTime->getTimestamp() - $fromTs), $resolutionSeconds);
                $buckets[$bucketIndex][] = (int) $sample->bpm;
            }
            ksort($buckets);
            foreach ($buckets as $bucketIndex => $bpmList) {
                sort($bpmList);
                $bucketMedian = $this->baselineService->percentile(collect($bpmList), 50);
                $bucketTime = $fromLocal->copy()->addSeconds($bucketIndex * $resolutionSeconds);
                $series[] = [
                    't' => $bucketTime->toIso8601String(),
                    'bpm' => is_float($bucketMedian) ? round($bucketMedian, 1) : (int) $bucketMedian,
                ];
            }
        } else {
            foreach ($samples as $sample) {
                $sampleTime = Carbon::parse($sample->recorded_at)->setTimezone($tz);
                $series[] = [
                    't' => $sampleTime->toIso8601String(),
                    'bpm' => (int) $sample->bpm,
                ];
            }
        }

        // Fetch notes in window (and slightly before window for aktivitas_fisik / episode matching)
        $lookbackStartDb = $fromDb->copy()->subSeconds(max($noteMatchSeconds, 600));
        $lookaheadEndDb = $toDb->copy()->addSeconds($noteMatchSeconds);
        $extendedNotes = EventNote::where('child_id', $child->id)
            ->whereBetween('occurred_at', [$lookbackStartDb, $lookaheadEndDb])
            ->orderBy('occurred_at')
            ->orderBy('id')
            ->get();

        $windowNotes = $extendedNotes->filter(function ($note) use ($fromLocal, $toLocal, $tz) {
            $t = Carbon::parse($note->occurred_at)->setTimezone($tz);
            return $t->greaterThanOrEqualTo($fromLocal) && $t->lessThanOrEqualTo($toLocal);
        })->values();

        // 8. notes (for chart pins)
        $notesPayload = $windowNotes->map(function ($note) use ($tz) {
            return $this->formatNoteItem($note, $tz);
        })->values()->all();

        // 5, 6, 7. Episodes & 9, 10. Patterns
        $episodes = [];
        $hourly = [];
        for ($h = 0; $h < 24; $h++) {
            $hourly[$h] = [
                'hour' => $h,
                'episode_count' => 0,
            ];
        }
        $byNoteType = [];

        if ($baselineSufficient && $p75 !== null && $median !== null) {
            $threshold = (float) $p75 + $episodeMarginBpm;
            $physicalActivityNotes = $extendedNotes->where('type', EventNote::TYPE_AKTIVITAS_FISIK)->values();
            $matchableNotes = $extendedNotes->where('type', '!=', EventNote::TYPE_AKTIVITAS_FISIK)->values();

            $rawRuns = [];
            $currentRun = [];

            foreach ($samples as $sample) {
                $sampleTime = Carbon::parse($sample->recorded_at)->setTimezone($tz);
                $isPhysicalActivity = $this->baselineService->isWithinNoteExclusionWindow($sampleTime, $physicalActivityNotes);

                if (!$isPhysicalActivity && (float) $sample->bpm > $threshold) {
                    $currentRun[] = $sample;
                } else {
                    if (!empty($currentRun)) {
                        $rawRuns[] = $currentRun;
                        $currentRun = [];
                    }
                }
            }
            if (!empty($currentRun)) {
                $rawRuns[] = $currentRun;
            }

            $episodeIndex = 1;
            foreach ($rawRuns as $run) {
                $firstTime = Carbon::parse($run[0]->recorded_at)->setTimezone($tz);
                $lastTime = Carbon::parse($run[count($run) - 1]->recorded_at)->setTimezone($tz);
                $durationSec = (int) round($firstTime->diffInSeconds($lastTime, false));

                if ($durationSec < $episodeMinDurationSeconds) {
                    continue;
                }

                $peakBpm = 0;
                $hasSensorGap = false;
                $runCount = count($run);
                for ($i = 0; $i < $runCount; $i++) {
                    $bpmVal = (int) $run[$i]->bpm;
                    if ($bpmVal > $peakBpm) {
                        $peakBpm = $bpmVal;
                    }
                    if ($i > 0) {
                        $tPrev = Carbon::parse($run[$i - 1]->recorded_at)->setTimezone($tz);
                        $tCurr = Carbon::parse($run[$i]->recorded_at)->setTimezone($tz);
                        if ((int) round($tPrev->diffInSeconds($tCurr, false)) > $gapMinSeconds) {
                            $hasSensorGap = true;
                        }
                    }
                }

                $matchedNote = $this->findClosestNote($firstTime, $matchableNotes, $noteMatchSeconds, $tz);

                $episodes[] = [
                    'index' => $episodeIndex++,
                    'start' => $firstTime->toIso8601String(),
                    'end' => $lastTime->toIso8601String(),
                    'duration_seconds' => $durationSec,
                    'peak_bpm' => $peakBpm,
                    'delta_from_median' => round($peakBpm - (float) $median, 1),
                    'has_sensor_gap' => $hasSensorGap,
                    'note' => $matchedNote,
                ];

                $startHour = (int) $firstTime->hour;
                $hourly[$startHour]['episode_count']++;
            }

            // 10. patterns.by_note_type (for each type except aktivitas_fisik)
            // Fetch valid samples up to toLocal + patternWindowSeconds for notes near the end of window
            $samplesForPatterns = HeartRateLog::where('child_id', $child->id)
                ->whereBetween('bpm', [self::MIN_VALID_BPM, self::MAX_VALID_BPM])
                ->whereBetween('recorded_at', [$fromDb, $toDb->copy()->addSeconds($patternWindowSeconds)])
                ->orderBy('recorded_at')
                ->get();

            foreach (EventNote::TYPES as $type) {
                if ($type === EventNote::TYPE_AKTIVITAS_FISIK) {
                    continue;
                }

                $notesOfType = $windowNotes->where('type', $type)->values();
                $notesTotal = $notesOfType->count();
                $rises = [];

                foreach ($notesOfType as $note) {
                    $noteTime = Carbon::parse($note->occurred_at)->setTimezone($tz);
                    $winEnd = $noteTime->copy()->addSeconds($patternWindowSeconds);

                    $inWindow = $samplesForPatterns->filter(function ($s) use ($noteTime, $winEnd, $tz) {
                        $st = Carbon::parse($s->recorded_at)->setTimezone($tz);
                        return $st->greaterThanOrEqualTo($noteTime) && $st->lessThanOrEqualTo($winEnd);
                    });

                    if ($inWindow->isNotEmpty()) {
                        $maxBpm = (float) $inWindow->max('bpm');
                        $rises[] = $maxBpm - (float) $median;
                    }
                }

                $notesUsed = count($rises);
                $avgRise = $notesUsed > 0 ? (int) round(array_sum($rises) / $notesUsed) : null;

                $byNoteType[] = [
                    'type' => $type,
                    'avg_rise_bpm' => $avgRise,
                    'notes_used' => $notesUsed,
                    'notes_total' => $notesTotal,
                    'enough' => $notesUsed >= $minNotesPerType,
                ];
            }
        }

        $patternsPayload = [
            'sufficient' => $baselineSufficient,
            'hourly' => $baselineSufficient ? array_values($hourly) : [],
            'by_note_type' => $baselineSufficient ? $byNoteType : [],
        ];

        // 11. quality
        $qualityPayload = $this->computeQuality(
            $samples,
            $fromLocal,
            $toLocal,
            $gapMinSeconds,
            $tz
        );

        // 12. current
        $currentPayload = $this->computeCurrent(
            $samples->last(),
            $now,
            $baselineSufficient,
            $p25 !== null ? (float) $p25 : null,
            $p75 !== null ? (float) $p75 : null,
            $episodeMarginBpm,
            $gapMinSeconds,
            $staleAfterSeconds,
            $expectedRestSeconds,
            $tz
        );

        // 13. meta
        $metaPayload = [
            'parameters' => [
                'default_timezone' => (string) config('analysis.default_timezone', 'Asia/Jakarta'),
                'gap_min_seconds' => $gapMinSeconds,
                'stale_after_seconds' => $staleAfterSeconds,
                'expected_rest_seconds' => $expectedRestSeconds,
                'episode_margin_bpm' => $episodeMarginBpm,
                'episode_min_duration_seconds' => $episodeMinDurationSeconds,
                'note_match_seconds' => $noteMatchSeconds,
                'pattern_window_seconds' => $patternWindowSeconds,
                'min_notes_per_type' => $minNotesPerType,
                'max_span_days' => $maxSpanDays,
                'chart_max_points' => $chartMaxPoints,
            ],
            'limitations' => [
                'Jam beristirahat di antara rangkaian pengukuran sehingga kejadian singkat bisa terlewat.',
                'Detak jantung saja tidak menunjukkan penyebab; konteks dari catatan kejadian.',
                'Bukan alat diagnosis.',
            ],
        ];

        return [
            'child' => [
                'id' => $child->id,
                'name' => $child->nickname,
                'nickname' => $child->nickname,
            ],
            'window' => [
                'from' => $fromLocal->toIso8601String(),
                'to' => $toLocal->toIso8601String(),
                'timezone' => $tz,
            ],
            'baseline' => $baselinePayload,
            'current' => $currentPayload,
            'series' => $series,
            'resolution_seconds' => $resolutionSeconds,
            'sensor_gaps' => $sensorGaps,
            'notes' => $notesPayload,
            'episodes' => $episodes,
            'patterns' => $patternsPayload,
            'quality' => $qualityPayload,
            'meta' => $metaPayload,
        ];
    }

    private function formatNoteItem(EventNote $note, string $tz): array
    {
        $rawText = (string) ($note->note ?? '');
        $preview = Str::limit($rawText, 60, '');

        return [
            'id' => $note->id,
            'type' => $note->type,
            'at' => Carbon::parse($note->occurred_at)->setTimezone($tz)->toIso8601String(),
            'text_preview' => $preview,
        ];
    }

    private function findClosestNote(Carbon $episodeStart, iterable $notes, int $noteMatchSeconds, string $tz): ?array
    {
        $bestNote = null;
        $bestDiff = null;
        $bestNoteTime = null;

        foreach ($notes as $note) {
            $noteTime = Carbon::parse($note->occurred_at)->setTimezone($tz);
            $diff = abs((int) round($episodeStart->diffInSeconds($noteTime, false)));
            if ($diff <= $noteMatchSeconds) {
                if (
                    $bestNote === null ||
                    $diff < $bestDiff ||
                    ($diff === $bestDiff && $noteTime->lessThan($bestNoteTime))
                ) {
                    $bestNote = $note;
                    $bestDiff = $diff;
                    $bestNoteTime = $noteTime;
                }
            }
        }

        return $bestNote !== null ? $this->formatNoteItem($bestNote, $tz) : null;
    }

    private function computeQuality($samples, Carbon $fromLocal, Carbon $toLocal, int $gapMinSeconds, string $tz): array
    {
        $windowSeconds = max(0, (int) round($fromLocal->diffInSeconds($toLocal, false)));
        $sampleCount = $samples->count();
        $measuredSeconds = 0;
        $gapCount = 0;
        $gapTotalSeconds = 0;

        $hourlyMeasured = array_fill(0, 24, 0.0);
        $hourlyWindow = array_fill(0, 24, 0.0);

        // Compute total window overlap per hour of day
        $this->accumulateHourlyOverlap($fromLocal, $toLocal, $hourlyWindow);

        for ($i = 1; $i < $sampleCount; $i++) {
            $prevTime = Carbon::parse($samples[$i - 1]->recorded_at)->setTimezone($tz);
            $currTime = Carbon::parse($samples[$i]->recorded_at)->setTimezone($tz);
            $diff = max(0, (int) round($prevTime->diffInSeconds($currTime, false)));

            if ($diff <= $gapMinSeconds) {
                $measuredSeconds += $diff;
                $this->accumulateHourlyOverlap($prevTime, $currTime, $hourlyMeasured);
            } else {
                $gapCount++;
                $gapTotalSeconds += $diff;
            }
        }

        $coveragePercent = $windowSeconds > 0
            ? round(($measuredSeconds / $windowSeconds) * 100, 1)
            : 0.0;

        $perHour = [];
        for ($h = 0; $h < 24; $h++) {
            $wSec = $hourlyWindow[$h];
            $mSec = $hourlyMeasured[$h];
            $hourCov = $wSec > 0 ? round(min(100.0, ($mSec / $wSec) * 100), 1) : 0.0;
            $perHour[] = [
                'hour' => $h,
                'coverage_percent' => $hourCov,
            ];
        }

        return [
            'window_seconds' => $windowSeconds,
            'measured_seconds' => $measuredSeconds,
            'coverage_percent' => $coveragePercent,
            'sample_count' => $sampleCount,
            'gap_count' => $gapCount,
            'gap_total_seconds' => $gapTotalSeconds,
            'per_hour' => $perHour,
        ];
    }

    private function accumulateHourlyOverlap(Carbon $start, Carbon $end, array &$buckets): void
    {
        $cursor = $start->copy();
        while ($cursor->lessThan($end)) {
            $nextHour = $cursor->copy()->startOfHour()->addHour();
            $segmentEnd = $nextHour->lessThan($end) ? $nextHour : $end;
            $sec = max(0, $cursor->diffInSeconds($segmentEnd, false));
            $hour = (int) $cursor->hour;
            $buckets[$hour] += $sec;
            $cursor = $segmentEnd;
        }
    }

    private function computeCurrent(
        ?HeartRateLog $lastSample,
        Carbon $now,
        bool $baselineSufficient,
        ?float $p25,
        ?float $p75,
        int $episodeMarginBpm,
        int $gapMinSeconds,
        int $staleAfterSeconds,
        int $expectedRestSeconds,
        string $tz
    ): array {
        if ($lastSample === null) {
            return [
                'bpm' => null,
                'recorded_at' => null,
                'age_seconds' => null,
                'status' => $baselineSufficient ? 'tidak_ada_data' : 'belum_ada_baseline',
                'measurement_state' => 'tidak_ada_data',
                'expected_rest_seconds' => $expectedRestSeconds,
            ];
        }

        $recordedAt = Carbon::parse($lastSample->recorded_at)->setTimezone($tz);
        $ageSeconds = max(0, (int) round($recordedAt->diffInSeconds($now, false)));
        $bpm = (int) $lastSample->bpm;

        if ($ageSeconds <= $gapMinSeconds) {
            $measurementState = 'mengukur';
        } elseif ($ageSeconds <= $staleAfterSeconds) {
            $measurementState = 'istirahat_jam';
        } else {
            $measurementState = 'tidak_ada_data';
        }

        if (!$baselineSufficient || $p25 === null || $p75 === null) {
            $status = 'belum_ada_baseline';
        } else {
            $threshold = $p75 + $episodeMarginBpm;
            if ($bpm < $p25) {
                $status = 'di_bawah_rentang';
            } elseif ($bpm <= $p75) {
                $status = 'dalam_rentang';
            } elseif ($bpm <= $threshold) {
                $status = 'sedikit_di_atas';
            } else {
                $status = 'jauh_di_atas';
            }
        }

        return [
            'bpm' => $bpm,
            'recorded_at' => $recordedAt->toIso8601String(),
            'age_seconds' => $ageSeconds,
            'status' => $status,
            'measurement_state' => $measurementState,
            'expected_rest_seconds' => $expectedRestSeconds,
        ];
    }
}
