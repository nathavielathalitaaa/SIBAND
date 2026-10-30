<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Device;
use App\Models\Child;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Http\Response;
use Illuminate\Http\JsonResponse;

class DeviceController extends Controller
{
    /**
     * List devices belonging to the authenticated user's children.
     */
    public function index(): Response
    {
        $user = Auth::user();
        $devices = Device::whereHas('child', function ($q) use ($user) {
            $q->where('user_id', $user->id);
        })->get();
        return response()->json($devices);
    }

    /**
     * Pair a device to a child owned by the authenticated user.
     * If a device with the same MAC already exists for this user, reassign it.
     */

    public function pair(Request $request): JsonResponse
    {
        $request->validate([
            'mac' => 'required|string',
            'name' => 'required|string',
            'child_id' => 'required|integer|exists:children,id',
        ]);

        $user = Auth::user();
        // Verify child belongs to the authenticated user
        $child = Child::find($request->input('child_id'));
        if (! $child || $child->user_id !== $user->id) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        // Check if a device with the same MAC already exists
        $existingDevice = Device::where('mac', $request->input('mac'))->first();
        if ($existingDevice) {
            $ownerUserId = $existingDevice->child->user_id ?? null;
            if ($ownerUserId && $ownerUserId !== $user->id) {
                // The MAC belongs to a child of another user – reject
                return response()->json(['message' => 'Device already paired to another user'], 403);
            }
            // Device belongs to the same user – allow reassign to the requested child
            $existingDevice->update([
                'child_id' => $child->id,
                'name' => $request->input('name'),
            ]);
            return response()->json($existingDevice);
        }

        // No existing device – create new one
        $device = Device::create([
            'mac' => $request->input('mac'),
            'name' => $request->input('name'),
            'child_id' => $child->id,
        ]);
        return response()->json($device, 201);
    }




    /**
     * Store a new device for a child owned by the user.
     */
    public function store(Request $request): Response
    {
        $request->validate([
            'child_id' => 'required|integer|exists:children,id',
            'name' => 'required|string',
            'mac' => 'required|string', // No regex to avoid breaking BPM endpoint
            'last_seen_at' => 'nullable|date',
        ]);

        $user = Auth::user();
        $child = Child::findOrFail($request->input('child_id'));
        if ($child->user_id !== $user->id) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        $device = Device::create($request->only(['child_id', 'name', 'mac', 'last_seen_at']));
        return response()->json($device, 201);
    }

    /**
     * Show a specific device if it belongs to the user's child.
     */
    public function show(string $id): Response
    {
        $user = Auth::user();
        $device = Device::where('id', $id)
            ->whereHas('child', fn($q) => $q->where('user_id', $user->id))
            ->firstOrFail();
        return response()->json($device);
    }

    /**
     * Update a device with ownership check.
     */
    public function update(Request $request, string $id): Response
    {
        $user = Auth::user();
        $device = Device::where('id', $id)
            ->whereHas('child', fn($q) => $q->where('user_id', $user->id))
            ->firstOrFail();

        $request->validate([
            'name' => 'sometimes|required|string',
            'mac' => 'sometimes|required|string',
            'last_seen_at' => 'nullable|date',
        ]);

        $device->update($request->only(['name', 'mac', 'last_seen_at']));
        return response()->json($device);
    }

    /**
     * Delete a device with ownership verification.
     */
    public function destroy(string $id): Response
    {
        $user = Auth::user();
        $device = Device::where('id', $id)
            ->whereHas('child', fn($q) => $q->where('user_id', $user->id))
            ->firstOrFail();
        $device->delete();
        return response()->json(['message' => 'Deleted']);
    }
}
