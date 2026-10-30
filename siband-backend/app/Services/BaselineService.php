<?php

namespace App\Services;

use App\Models\Child;
use App\Models\HeartRateLog;
use App\Models\EventNote;
use Carbon\Carbon;

class BaselineService
{
    /**
     * Compute baseline statistics for a child's heart rate.
     *
     * @param Child $child
     * @param int   $days  Number of days to look back (1-30)
     * @return array
     */
    public function computeBaseline(Child $child, int $days): array
    {
        $now = Carbon::now();
        $start = $now->copy()->subDays($days);

        // Fetch heart rate logs within the period and within BPM range
        $logs = HeartRateLog::where('child_id', $child->id)
            ->whereBetween('bpm', [40, 200])
            ->where('recorded_at', '>=', $start)
            ->orderBy('recorded_at')
            ->get();

        // Fetch relevant event notes for exclusion
        $eventNotes = EventNote::where('child_id', $child->id)
            ->whereIn('type', ['suara_keras', 'meltdown', 'aktivitas_fisik'])
            ->where('occurred_at', '>=', $start)
            ->get();

        $excludedCount = 0;
        $filtered = $logs->filter(function ($log) use ($eventNotes) {
            foreach ($eventNotes as $note) {
                $noteTime = Carbon::parse($note->occurred_at);
                $logTime = Carbon::parse($log->recorded_at);
                if ($logTime->greaterThanOrEqualTo($noteTime) && $logTime->lessThanOrEqualTo($noteTime->copy()->addMinutes(10))) {
                    return false; // exclude
                }
            }
            return true; // keep
        });

        $excludedCount = $logs->count() - $filtered->count();
        $values = $filtered->pluck('bpm')->sort()->values();
        $sampleCount = $values->count();
        $sufficient = $sampleCount >= 100;

        $median = null;
        $p25 = null;
        $p75 = null;
        if ($sampleCount > 0) {
            $median = $this->percentile($values, 50);
            $p25 = $this->percentile($values, 25);
            $p75 = $this->percentile($values, 75);
        }

        return [
            'child_id' => $child->id,
            'days' => $days,
            'median' => $median,
            'p25' => $p25,
            'p75' => $p75,
            'sample_count' => $sampleCount,
            'excluded_count' => $excludedCount,
            'sufficient' => $sufficient,
            'computed_at' => $now->toDateTimeString(),
        ];
    }

    /**
     * Simple percentile calculation (nearest-rank method).
     */
    private function percentile($sortedValues, int $percent)
    {
        $count = $sortedValues->count();
        if ($count === 0) {
            return null;
        }
        // Position using zero‑based index
        $rank = ($percent / 100) * ($count - 1);
        $lower = floor($rank);
        $upper = ceil($rank);
        $weight = $rank - $lower;
        if ($upper >= $count) {
            return $sortedValues[$lower];
        }
        $lowerVal = $sortedValues[$lower];
        $upperVal = $sortedValues[$upper];
        return $lowerVal + $weight * ($upperVal - $lowerVal);
    }
}
