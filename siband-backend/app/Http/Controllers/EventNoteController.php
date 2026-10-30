<?php

namespace App\Http\Controllers;

use App\Models\EventNote;
use App\Models\Child;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Http\JsonResponse;

class EventNoteController extends Controller
{
    /**
     * List event notes for a child.
     */
    public function index(Request $request, string $child): JsonResponse
    {
        $childModel = $request->user()->children()->findOrFail($child);
        $query = $childModel->eventNotes();
        if ($request->filled('from')) {
            $query->where('occurred_at', '>=', $request->query('from'));
        }
        if ($request->filled('to')) {
            $query->where('occurred_at', '<=', $request->query('to'));
        }
        return response()->json($query->get());
    }

    /**
     * Store a new event note for a child.
     */
    public function store(Request $request, string $child): JsonResponse
    {
        $validated = $request->validate([
            'type' => ['required', Rule::in(['transisi', 'suara_keras', 'meltdown', 'aktivitas_fisik', 'lainnya'])],
            'note' => ['nullable', 'string', 'max:500'],
            'occurred_at' => ['nullable', 'date'],
        ]);
        $childModel = $request->user()->children()->findOrFail($child);
        $event = EventNote::create([
            'child_id' => $childModel->id,
            'type' => $validated['type'],
            'note' => $validated['note'] ?? null,
            'occurred_at' => $validated['occurred_at'] ?? now(),
        ]);
        return response()->json($event, 201);
    }

    /**
     * Delete an event note.
     */
    public function destroy(Request $request, string $id): JsonResponse
    {
        $note = EventNote::where('id', $id)
            ->whereHas('child', function ($q) use ($request) {
                $q->whereIn('id', $request->user()->children()->pluck('id'));
            })->firstOrFail();
        $note->delete();
        return response()->json(['deleted' => true]);
    }
}
