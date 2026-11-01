<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\RecapService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class RecapController extends Controller
{
    protected RecapService $recapService;

    public function __construct(RecapService $recapService)
    {
        $this->recapService = $recapService;
    }

    /**
     * Get monthly recap for a child (authenticated owner only).
     */
    public function show(Request $request, string $child): JsonResponse
    {
        $childModel = $request->user()->children()->findOrFail($child);
        $month = $request->query('month');

        $recap = $this->recapService->getRecap($childModel, $month, false);

        return response()->json($recap);
    }
}
