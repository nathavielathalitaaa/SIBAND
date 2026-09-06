<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HeartRateLog;
use Illuminate\Http\Request;

class HeartRateController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'device_name' => 'nullable|string',
            'device_mac' => 'nullable|string',
            'bpm' => 'required|integer|min:30|max:220',
            'recorded_at' => 'required|date',
        ]);

        $log = HeartRateLog::create($validated);

        return response()->json([
            'message' => 'Heart rate log stored successfully',
            'data' => $log,
        ], 201);
    }

    public function index(Request $request)
    {
        $logs = HeartRateLog::latest('recorded_at')->limit(100)->get();

        return response()->json($logs, 200);
    }
}
