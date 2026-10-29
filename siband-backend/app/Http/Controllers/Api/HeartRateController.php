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

        $validated['user_id'] = $request->user()->id;

        $log = HeartRateLog::create($validated);

        return response()->json([
            'message' => 'Heart rate log stored successfully',
            'data' => $log,
        ], 201);
    }

    public function index(Request $request)
    {
        $query = HeartRateLog::where('user_id', $request->user()->id)->latest('recorded_at');

        if ($request->filled('hours')) {
            $query->where('recorded_at', '>=', now()->subHours((int) $request->hours));
        }

        return response()->json($query->limit(100)->get(), 200);
    }
}
