<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ShareLink;
use App\Services\RecapService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;

class ShareLinkController extends Controller
{
    private function generateShortCode(): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $max = strlen($alphabet) - 1;

        for ($attempt = 0; $attempt < 10; $attempt++) {
            $code = '';
            for ($i = 0; $i < 6; $i++) {
                $code .= $alphabet[random_int(0, $max)];
            }
            if (! ShareLink::where('short_code', $code)->exists()) {
                return $code;
            }
        }

        return strtoupper(bin2hex(random_bytes(4)));
    }

    /**
     * Create a new share link for a child (authenticated owner only).
     */
    public function store(Request $request, string $child): JsonResponse
    {
        $childModel = $request->user()->children()->findOrFail($child);

        $validated = $request->validate([
            'days' => 'nullable|integer|min:1|max:30',
            'use_pin' => 'nullable|boolean',
            'pin' => ['nullable', 'string', 'regex:/^\d{4,8}$/'],
        ]);

        $days = (int) ($validated['days'] ?? 7);
        $customPin = isset($validated['pin']) ? trim((string) $validated['pin']) : null;
        $usePin = (bool) ($validated['use_pin'] ?? ($customPin !== null && $customPin !== ''));

        $plainPin = null;
        $pinHash = null;
        if ($usePin) {
            $plainPin = ($customPin !== null && $customPin !== '')
                ? $customPin
                : str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
            $pinHash = Hash::make($plainPin);
        }

        // Generate 32 bytes random token formatted as hex (64 chars)
        $plainToken = bin2hex(random_bytes(32));
        $tokenHash = hash('sha256', $plainToken);
        $shortCode = $this->generateShortCode();
        $expiresAt = now()->addDays($days);

        $shareLink = $childModel->shareLinks()->create([
            'token_hash' => $tokenHash,
            'short_code' => $shortCode,
            'pin_hash' => $pinHash,
            'expires_at' => $expiresAt,
        ]);

        $response = [
            'id' => $shareLink->id,
            'token' => $plainToken,
            'short_code' => $shortCode,
            'has_pin' => $usePin,
            'expires_at' => $shareLink->expires_at->toIso8601String(),
            'status' => 'active',
        ];
        if ($plainPin !== null) {
            $response['pin'] = $plainPin;
        }

        return response()->json($response, 201);
    }

    /**
     * List share links for a child (authenticated owner only).
     * Does NOT return plain token, token hash, or pin hash.
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
                    'short_code' => $link->short_code,
                    'has_pin' => $link->requiresPin(),
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
     * Public endpoint to view child's recap using share token or short code.
     * Throttled, no auth required.
     */
    public function showPublic(Request $request, string $token, RecapService $recapService): JsonResponse
    {
        $pin = $request->header('X-Share-Pin');

        return $this->resolveAndRespond($token, is_string($pin) ? $pin : null, $recapService);
    }

    /**
     * Public POST endpoint to open recap using short code/token + optional PIN.
     */
    public function accessPublic(Request $request, RecapService $recapService): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'required|string|max:128',
            'pin' => 'nullable|string|max:32',
        ]);

        return $this->resolveAndRespond(
            (string) $validated['code'],
            isset($validated['pin']) ? (string) $validated['pin'] : null,
            $recapService
        );
    }

    private function resolveAndRespond(string $rawCode, ?string $pin, RecapService $recapService): JsonResponse
    {
        $trimmed = trim($rawCode);
        if ($trimmed === '') {
            return response()->json([
                'message' => 'Tautan berbagi tidak ditemukan atau sudah tidak berlaku.',
            ], 404);
        }

        $tokenHash = hash('sha256', $trimmed);
        $normalizedShort = strtoupper(str_replace([' ', '-'], '', $trimmed));

        $shareLink = ShareLink::where('token_hash', $tokenHash)
            ->orWhere('short_code', $normalizedShort)
            ->first();

        // Exact same 404 response if not found, expired, or revoked
        if (! $shareLink || $shareLink->isRevoked() || $shareLink->isExpired()) {
            return response()->json([
                'message' => 'Tautan berbagi tidak ditemukan atau sudah tidak berlaku.',
            ], 404);
        }

        if ($shareLink->requiresPin()) {
            if ($pin === null || trim($pin) === '') {
                return response()->json([
                    'requires_pin' => true,
                    'message' => 'Masukkan kode PIN untuk membuka rekap.',
                ], 403);
            }
            if (! $shareLink->verifyPin($pin)) {
                return response()->json([
                    'requires_pin' => true,
                    'invalid_pin' => true,
                    'message' => 'Kode PIN tidak sesuai.',
                ], 403);
            }
        }

        // Record last accessed timestamp
        $shareLink->update([
            'last_accessed_at' => now(),
        ]);

        $child = $shareLink->child;
        $periode = now()->format('Y-m');
        $recap = $recapService->getRecap($child, $periode, true);

        // Sanitize: strictly strip forbidden fields (child_id, user_id, birth_year, device_mac, email, etc.)
        $forbiddenKeys = ['child_id', 'user_id', 'birth_year', 'device_mac', 'email', 'device_id', 'pin_hash', 'token_hash'];
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
