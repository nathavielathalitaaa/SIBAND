<?php

namespace App\Services;

use App\Models\Child;
use App\Models\HeartRateLog;
use App\Models\EventNote;
use Carbon\Carbon;

class RecapService
{
    protected BaselineService $baselineService;

    public function __construct(BaselineService $baselineService)
    {
        $this->baselineService = $baselineService;
    }

    /**
     * Compute monthly recap for a child.
     *
     * @param Child $child
     * @param string|null $month Format 'YYYY-MM' (defaults to current month)
     * @param bool $isPublic Whether this is for the public endpoint (filters internal IDs)
     * @return array
     */
    public function getRecap(Child $child, ?string $month = null, bool $isPublic = false): array
    {
        if (empty($month)) {
            $month = Carbon::now()->format('Y-m');
        }

        try {
            $carbonMonth = Carbon::createFromFormat('Y-m', $month);
        } catch (\Exception $e) {
            $carbonMonth = Carbon::now();
            $month = $carbonMonth->format('Y-m');
        }

        $startOfMonth = $carbonMonth->copy()->startOfMonth();
        $endOfMonth = $carbonMonth->copy()->endOfMonth();

        // 1. Fetch heart rate logs for the specified month within realistic BPM range [40, 200]
        $logs = HeartRateLog::where('child_id', $child->id)
            ->whereBetween('recorded_at', [$startOfMonth, $endOfMonth])
            ->whereBetween('bpm', [40, 200])
            ->orderBy('recorded_at')
            ->get();

        $sampleCount = $logs->count();
        $avgBpm = $sampleCount > 0 ? round($logs->avg('bpm'), 1) : null;
        $maxBpm = $sampleCount > 0 ? (int) $logs->max('bpm') : null;

        // 2. Compute baseline using existing BaselineService (default 30 days)
        $baseline = $this->baselineService->computeBaseline($child, 30);
        $isSufficient = ($baseline['sufficient'] ?? false) === true && ($baseline['p75'] ?? null) !== null;
        $p75 = $isSufficient ? (float) $baseline['p75'] : null;

        // If public or recap, remove internal child_id from baseline
        if ($isPublic) {
            unset($baseline['child_id']);
        }

        // 3. Group logs by day
        $groupedByDate = $logs->groupBy(function ($log) {
            return Carbon::parse($log->recorded_at)->toDateString();
        });

        $ringkasanPerHari = [];
        $totalAboveP75 = 0;

        foreach ($groupedByDate as $dateStr => $dayLogs) {
            $dayCount = $dayLogs->count();
            $dayAvg = round($dayLogs->avg('bpm'), 1);
            $dayMax = (int) $dayLogs->max('bpm');

            $aboveP75Count = null;
            if ($isSufficient) {
                $aboveP75Count = $dayLogs->where('bpm', '>', $p75)->count();
                $totalAboveP75 += $aboveP75Count;
            }

            $ringkasanPerHari[] = [
                'tanggal' => $dateStr,
                'rata_rata' => $dayAvg,
                'maksimum' => $dayMax,
                'jumlah_sampel' => $dayCount,
                'bacaan_di_atas_p75' => $aboveP75Count,
            ];
        }

        // Sort days chronologically
        usort($ringkasanPerHari, fn($a, $b) => strcmp($a['tanggal'], $b['tanggal']));

        // 4. Event notes for the month
        $eventNotes = EventNote::where('child_id', $child->id)
            ->whereBetween('occurred_at', [$startOfMonth, $endOfMonth])
            ->orderBy('occurred_at')
            ->get();

        $groupedByType = [];
        foreach ($eventNotes as $note) {
            $groupedByType[$note->type] = ($groupedByType[$note->type] ?? 0) + 1;
        }

        $daftarRingkas = $eventNotes->map(function ($note) {
            return [
                'tipe' => $note->type,
                'waktu' => Carbon::parse($note->occurred_at)->toIso8601String(),
                'catatan' => $note->note,
            ];
        })->values()->toArray();

        return [
            'periode' => $month,
            'jumlah_sampel' => $sampleCount,
            'rata_rata' => $avgBpm,
            'maksimum' => $maxBpm,
            'jumlah_hari' => count($ringkasanPerHari),
            'ringkasan_per_hari' => $ringkasanPerHari,
            'baseline' => $baseline,
            'bacaan_di_atas_p75' => $isSufficient ? $totalAboveP75 : null,
            'catatan_kejadian' => [
                'per_tipe' => $groupedByType,
                'daftar' => $daftarRingkas,
            ],
            'catatan_per_tipe' => $groupedByType,
            'daftar_catatan' => $daftarRingkas,
        ];
    }
}
