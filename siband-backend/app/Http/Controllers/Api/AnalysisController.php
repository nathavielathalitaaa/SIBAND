<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AnalysisService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AnalysisController extends Controller
{
    protected AnalysisService $analysisService;

    public function __construct(AnalysisService $analysisService)
    {
        $this->analysisService = $analysisService;
    }

    /**
     * Get comprehensive heart rate and event note analysis for a child.
     */
    public function show(Request $request, string $child): JsonResponse
    {
        $childModel = $request->user()->children()->findOrFail($child);

        $defaultTz = (string) config('analysis.default_timezone', 'Asia/Jakarta');
        $tzParam = $request->query('tz');
        $tz = ($tzParam !== null && $tzParam !== '') ? $tzParam : $defaultTz;

        if (!is_string($tz) || !in_array($tz, \DateTimeZone::listIdentifiers(), true)) {
            return response()->json([
                'message' => 'Parameter tz tidak valid.',
                'errors' => ['tz' => ['Timezone harus berupa identifier IANA yang valid.']],
            ], 422);
        }

        $now = Carbon::now($tz);
        $maxSpanDays = (int) config('analysis.max_span_days', 7);
        $maxSpanSeconds = $maxSpanDays * 86400;

        $fromParam = $request->query('from');
        $toParam = $request->query('to');

        try {
            $from = $fromParam !== null && $fromParam !== ''
                ? Carbon::parse($fromParam, $tz)->setTimezone($tz)
                : $now->copy()->startOfDay();
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Parameter from tidak valid.',
                'errors' => ['from' => ['Format waktu from tidak valid.']],
            ], 422);
        }

        try {
            $to = $toParam !== null && $toParam !== ''
                ? Carbon::parse($toParam, $tz)->setTimezone($tz)
                : $now->copy();
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Parameter to tidak valid.',
                'errors' => ['to' => ['Format waktu to tidak valid.']],
            ], 422);
        }

        if ($to->greaterThan($now)) {
            $to = $now->copy();
        }

        if ($to->lessThanOrEqualTo($from)) {
            return response()->json([
                'message' => 'Rentang waktu tidak valid: to harus lebih besar dari from.',
                'errors' => ['to' => ['Waktu akhir harus setelah waktu mulai.']],
            ], 422);
        }

        $spanSeconds = (int) round($from->diffInSeconds($to, false));
        if ($spanSeconds > $maxSpanSeconds) {
            return response()->json([
                'message' => "Rentang waktu maksimal adalah {$maxSpanDays} hari.",
                'errors' => ['window' => ["Rentang waktu melebihi {$maxSpanDays} hari."]],
            ], 422);
        }

        $result = $this->analysisService->analyze($childModel, $from, $to, $tz);

        return response()->json($result);
    }
}
