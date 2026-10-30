<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Child;
use App\Services\BaselineService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class BaselineController extends Controller
{
    /**
     * Get baseline heart rate statistics for a child.
     */
    public function index(Request $request, string $child): JsonResponse
    {
        // Ensure the child belongs to the authenticated user
        $childModel = $request->user()->children()->findOrFail($child);
        $days = (int) $request->query('days', 7);
        $days = max(1, min($days, 30));

        $service = app(BaselineService::class);
        $result = $service->computeBaseline($childModel, $days);

        return response()->json($result);
    }
}
