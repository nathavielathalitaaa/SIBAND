<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Child;
use App\Models\Device;
use App\Models\HeartRateLog;
use Illuminate\Http\Request;

class HeartRateController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'child_id' => 'nullable|integer|exists:children,id',
            'device_id' => 'nullable|integer|exists:devices,id',
            'device_name' => 'nullable|string',
            'device_mac' => 'nullable|string',
            'bpm' => 'required|integer|min:30|max:220',
            'recorded_at' => 'required|date',
        ]);

        $user = $request->user();
        $child = null;
        $device = null;

        if (! empty($validated['child_id'])) {
            $child = Child::find($validated['child_id']);
            if (! $child || $child->user_id !== $user->id) {
                return response()->json(['message' => 'Forbidden'], 403);
            }
        }

        if (! empty($validated['device_id'])) {
            $device = Device::with('child')->find($validated['device_id']);
            if (! $device || ! $device->child || $device->child->user_id !== $user->id) {
                return response()->json(['message' => 'Forbidden'], 403);
            }
        }

        if ($child !== null && $device !== null && (int) $device->child_id !== (int) $child->id) {
            return response()->json([
                'message' => 'Device is not paired to the specified child.',
                'errors' => [
                    'device_id' => ['The selected device is not paired to the specified child.'],
                ],
            ], 422);
        }

        if (empty($validated['child_id']) && $device !== null) {
            $validated['child_id'] = $device->child_id;
        }

        $validated['user_id'] = $user->id;

        $log = HeartRateLog::create($validated);

        return response()->json([
            'message' => 'Heart rate log stored successfully',
            'data' => $log,
        ], 201);
    }

    public function index(Request $request)
    {
        $validated = $request->validate([
            'child_id' => 'nullable|integer|exists:children,id',
        ]);

        $user = $request->user();
        $query = HeartRateLog::where('user_id', $user->id)->latest('recorded_at');

        if (! empty($validated['child_id'])) {
            $child = Child::find($validated['child_id']);
            if (! $child || $child->user_id !== $user->id) {
                return response()->json(['message' => 'Forbidden'], 403);
            }
            $query->where('child_id', $child->id);
        }

        if ($request->filled('hours')) {
            $query->where('recorded_at', '>=', now()->subHours((int) $request->hours));
        }

        return response()->json($query->limit(100)->get(), 200);
    }
}
