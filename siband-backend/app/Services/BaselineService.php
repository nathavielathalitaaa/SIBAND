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
            return !$this->isWithinNoteExclusionWindow(Carbon::parse($log->recorded_at), $eventNotes);
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
     * Check whether a sample timestamp falls within the exclusion window after any given note.
     * Physical activity notes cover up to 30 minutes; other excluded notes cover 10 minutes.
     */
    public function isWithinNoteExclusionWindow(Carbon $logTime, iterable $eventNotes): bool
    {
        foreach ($eventNotes as $note) {
            $noteTime = Carbon::parse($note->occurred_at);
            $windowMinutes = ($note->type ?? null) === EventNote::TYPE_AKTIVITAS_FISIK ? 30 : 10;
            if ($logTime->greaterThanOrEqualTo($noteTime) && $logTime->lessThanOrEqualTo($noteTime->copy()->addMinutes($windowMinutes))) {
                return true;
            }
        }
        return false;
    }

    /**
     * Simple percentile calculation (nearest-rank method).
     */
    public function percentile($sortedValues, int $percent)
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
