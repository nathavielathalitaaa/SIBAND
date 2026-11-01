<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use App\Models\User;
use App\Models\Child;
use App\Models\ShareLink;
use App\Models\HeartRateLog;
use Carbon\Carbon;

class ShareLinkTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_create_share_link_and_token_only_appears_once_and_is_not_stored_as_plain_in_db(): void
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson("/api/children/{$child->id}/share-links", [
                'days' => 7,
            ]);


        $response->assertStatus(201)
            ->assertJsonStructure(['id', 'token', 'expires_at', 'status'])
            ->assertJson([
                'status' => 'active',
            ]);

        $plainToken = $response->json('token');
        $this->assertNotEmpty($plainToken);
        $this->assertSame(64, strlen($plainToken)); // 32 bytes hex = 64 characters

        // Verify database: ONLY SHA-256 hash is stored, never plain token
        $expectedHash = hash('sha256', $plainToken);
        $this->assertDatabaseHas('share_links', [
            'child_id' => $child->id,
            'token_hash' => $expectedHash,
        ]);

        $this->assertDatabaseMissing('share_links', [
            'token_hash' => $plainToken,
        ]);

        $shareLink = ShareLink::first();
        $this->assertSame($expectedHash, $shareLink->token_hash);
        $this->assertNotSame($plainToken, $shareLink->token_hash);
    }

    public function test_owner_can_list_share_links_and_token_or_hash_never_returned(): void
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $plainToken = bin2hex(random_bytes(32));
        $tokenHash = hash('sha256', $plainToken);

        $shareLink = ShareLink::create([
            'child_id' => $child->id,
            'token_hash' => $tokenHash,
            'expires_at' => now()->addDays(7),
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/share-links");

        $response->assertOk()
            ->assertJsonCount(1)
            ->assertJsonFragment([
                'id' => $shareLink->id,
                'status' => 'active',
            ]);

        // MUST NOT contain token or token_hash
        $json = $response->json();
        $this->assertArrayNotHasKey('token', $json[0]);
        $this->assertArrayNotHasKey('token_hash', $json[0]);
        $response->assertDontSee($plainToken);
        $response->assertDontSee($tokenHash);
    }

    public function test_owner_can_revoke_share_link(): void
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $plainToken = bin2hex(random_bytes(32));
        $shareLink = ShareLink::create([
            'child_id' => $child->id,
            'token_hash' => hash('sha256', $plainToken),
            'expires_at' => now()->addDays(7),
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->deleteJson("/api/share-links/{$shareLink->id}");

        $response->assertOk()
            ->assertJson([
                'id' => $shareLink->id,
                'status' => 'revoked',
            ]);

        $this->assertNotNull($shareLink->fresh()->revoked_at);
        $this->assertTrue($shareLink->fresh()->isRevoked());
    }

    public function test_other_user_cannot_create_view_or_revoke_another_users_share_link(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $childA = Child::factory()->create(['user_id' => $userA->id]);

        $plainToken = bin2hex(random_bytes(32));
        $shareLink = ShareLink::create([
            'child_id' => $childA->id,
            'token_hash' => hash('sha256', $plainToken),
            'expires_at' => now()->addDays(7),
        ]);

        // User B attempts to create link for User A's child
        $this->actingAs($userB, 'sanctum')
            ->postJson("/api/children/{$childA->id}/share-links", ['days' => 5])
            ->assertStatus(404);

        // User B attempts to view links of User A's child
        $this->actingAs($userB, 'sanctum')
            ->getJson("/api/children/{$childA->id}/share-links")
            ->assertStatus(404);

        // User B attempts to revoke link of User A's child
        $this->actingAs($userB, 'sanctum')
            ->deleteJson("/api/share-links/{$shareLink->id}")
            ->assertStatus(404);

        // Assert link was NOT revoked
        $this->assertNull($shareLink->fresh()->revoked_at);
    }

    public function test_public_can_access_valid_share_link_without_auth_and_last_accessed_is_updated(): void
    {
        $user = User::factory()->create();
        $child = Child::factory()->create([
            'user_id' => $user->id,
            'nickname' => 'Bintang',
            'birth_year' => 2017,
        ]);

        $plainToken = bin2hex(random_bytes(32));
        $shareLink = ShareLink::create([
            'child_id' => $child->id,
            'token_hash' => hash('sha256', $plainToken),
            'expires_at' => now()->addDays(7),
            'last_accessed_at' => null,
        ]);

        // Public access without auth
        $response = $this->getJson("/api/share/{$plainToken}");

        $response->assertOk()
            ->assertJson([
                'nickname' => 'Bintang',
                'periode' => now()->format('Y-m'),
            ])
            ->assertJsonStructure([
                'nickname',
                'periode',
                'rekap' => [
                    'periode',
                    'jumlah_sampel',
                    'rata_rata',
                    'maksimum',
                    'jumlah_hari',
                    'ringkasan_per_hari',
                    'baseline',
                    'catatan_kejadian',
                ],
            ]);

        $this->assertNotNull($shareLink->fresh()->last_accessed_at);
    }

    public function test_public_response_does_not_contain_forbidden_fields(): void
    {
        $user = User::factory()->create(['email' => 'private_parent@example.com']);
        $child = Child::factory()->create([
            'user_id' => $user->id,
            'nickname' => 'Bintang',
            'birth_year' => 2017,
        ]);

        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'device_name' => 'Watch1',
            'device_mac' => '11:22:33:44:55:66',
            'bpm' => 88,
            'recorded_at' => now(),
        ]);

        $plainToken = bin2hex(random_bytes(32));
        ShareLink::create([
            'child_id' => $child->id,
            'token_hash' => hash('sha256', $plainToken),
            'expires_at' => now()->addDays(7),
        ]);

        $response = $this->getJson("/api/share/{$plainToken}");
        $response->assertOk();

        $content = $response->getContent();

        // Check strictly that forbidden strings / values are not in the raw response
        $this->assertStringNotContainsString('private_parent@example.com', $content);
        $this->assertStringNotContainsString('11:22:33:44:55:66', $content);
        $this->assertStringNotContainsString('"birth_year"', $content);
        $this->assertStringNotContainsString('"child_id"', $content);
        $this->assertStringNotContainsString('"user_id"', $content);
        $this->assertStringNotContainsString('"device_mac"', $content);
        $this->assertStringNotContainsString('"device_id"', $content);
    }

    public function test_expired_revoked_and_invalid_tokens_return_exact_same_404(): void
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        // 1. Bogus / non-existent token
        $responseBogus = $this->getJson('/api/share/this_token_does_not_exist_at_all');
        $responseBogus->assertStatus(404);

        // 2. Expired token
        $expiredToken = bin2hex(random_bytes(32));
        ShareLink::create([
            'child_id' => $child->id,
            'token_hash' => hash('sha256', $expiredToken),
            'expires_at' => now()->subDay(),
        ]);
        $responseExpired = $this->getJson("/api/share/{$expiredToken}");
        $responseExpired->assertStatus(404);

        // 3. Revoked token
        $revokedToken = bin2hex(random_bytes(32));
        ShareLink::create([
            'child_id' => $child->id,
            'token_hash' => hash('sha256', $revokedToken),
            'expires_at' => now()->addDays(7),
            'revoked_at' => now()->subHour(),
        ]);
        $responseRevoked = $this->getJson("/api/share/{$revokedToken}");
        $responseRevoked->assertStatus(404);

        // Assert all 3 return EXACT same payload and message
        $this->assertSame($responseBogus->json(), $responseExpired->json());
        $this->assertSame($responseBogus->json(), $responseRevoked->json());
        $this->assertSame('Tautan berbagi tidak ditemukan atau sudah tidak berlaku.', $responseBogus->json('message'));
    }
}
