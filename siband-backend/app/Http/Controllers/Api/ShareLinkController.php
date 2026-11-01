<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ShareLink;
use App\Services\RecapService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class ShareLinkController extends Controller
{
    /**
     * Create a new share link for a child (authenticated owner only).
     */
    public function store(Request $request, string $child): JsonResponse
    {
        $childModel = $request->user()->children()->findOrFail($child);

        $validated = $request->validate([
            'days' => 'nullable|integer|min:1|max:30',
        ]);

        $days = (int) ($validated['days'] ?? 7);

        // Generate 32 bytes random token formatted as hex (64 chars)
        $plainToken = bin2hex(random_bytes(32));
        $tokenHash = hash('sha256', $plainToken);
        $expiresAt = now()->addDays($days);

        $shareLink = $childModel->shareLinks()->create([
            'token_hash' => $tokenHash,
            'expires_at' => $expiresAt,
        ]);

        return response()->json([
            'id' => $shareLink->id,
            'token' => $plainToken,
            'expires_at' => $shareLink->expires_at->toIso8601String(),
            'status' => 'active',
        ], 201);
    }

    /**
     * List share links for a child (authenticated owner only).
     * Does NOT return plain token or token hash.
     */
    public function index(Request $request, string $child): JsonResponse
    {
        $childModel = $request->user()->children()->findOrFail($child);

        $links = $childModel->shareLinks()
            ->orderByDesc('created_at')
            ->get()
            ->map(function ($link) {
                return [
                    'id' => $link->id,
                    'expires_at' => $link->expires_at?->toIso8601String(),
                    'revoked_at' => $link->revoked_at?->toIso8601String(),
                    'last_accessed_at' => $link->last_accessed_at?->toIso8601String(),
                    'status' => $link->status,
                ];
            });

        return response()->json($links);
    }

    /**
     * Revoke a share link (authenticated owner only).
     */
    public function destroy(Request $request, string $id): JsonResponse
    {
        $shareLink = ShareLink::whereHas('child', function ($query) use ($request) {
            $query->where('user_id', $request->user()->id);
        })->findOrFail($id);

        if ($shareLink->revoked_at === null) {
            $shareLink->update([
                'revoked_at' => now(),
            ]);
        }

        return response()->json([
            'message' => 'Tautan berbagi berhasil dicabut.',
            'id' => $shareLink->id,
            'revoked_at' => $shareLink->revoked_at->toIso8601String(),
            'status' => 'revoked',
        ]);
    }

    /**
     * Public endpoint to view child's recap using share token.
     * Throttled, no auth required.
     */
    public function showPublic(Request $request, string $token, RecapService $recapService): JsonResponse
    {
        $tokenHash = hash('sha256', $token);
        $shareLink = ShareLink::where('token_hash', $tokenHash)->first();

        // Exact same 404 response if not found, expired, or revoked
        if (! $shareLink || $shareLink->isRevoked() || $shareLink->isExpired()) {
            return response()->json([
                'message' => 'Tautan berbagi tidak ditemukan atau sudah tidak berlaku.',
            ], 404);
        }

        // Record last accessed timestamp
        $shareLink->update([
            'last_accessed_at' => now(),
        ]);

        $child = $shareLink->child;
        $periode = now()->format('Y-m');
        $recap = $recapService->getRecap($child, $periode, true);

        // Sanitize: strictly strip forbidden fields (child_id, user_id, birth_year, device_mac, email, etc.)
        $forbiddenKeys = ['child_id', 'user_id', 'birth_year', 'device_mac', 'email', 'device_id'];
        $cleanRecap = $this->stripForbiddenFields($recap, $forbiddenKeys);

        return response()->json([
            'nickname' => $child->nickname,
            'periode' => $periode,
            'rekap' => $cleanRecap,
        ]);
    }

    /**
     * Recursively strip forbidden fields from response data.
     */
    private function stripForbiddenFields(array $data, array $forbiddenKeys): array
    {
        foreach ($data as $key => $value) {
            if (in_array((string) $key, $forbiddenKeys, true)) {
                unset($data[$key]);
                continue;
            }
            if (is_array($value)) {
                $data[$key] = $this->stripForbiddenFields($value, $forbiddenKeys);
            }
        }
        return $data;
    }
}
