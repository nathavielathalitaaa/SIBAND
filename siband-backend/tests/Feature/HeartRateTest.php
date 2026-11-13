<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Child;
use App\Models\Device;
use App\Models\HeartRateLog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class HeartRateTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function user_can_store_heart_rate()
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $child = Child::factory()->create(['user_id' => $user->id]);
        $device = Device::factory()->create(['child_id' => $child->id]);

        $payload = [
            'device_name' => $device->name,
            'device_mac' => $device->mac,
            'bpm' => 72,
            'recorded_at' => now()->toDateTimeString(),
        ];

        $response = $this->postJson('/api/heart-rate', $payload);
        $response->assertStatus(201);
        $this->assertDatabaseHas('heart_rate_logs', [
            'user_id' => $user->id,
            'bpm' => 72,
        ]);
    }

    #[Test]
    public function store_with_child_id_and_device_id_persists_both_in_database()
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $child = Child::factory()->create(['user_id' => $user->id]);
        $device = Device::factory()->create(['child_id' => $child->id]);

        $response = $this->postJson('/api/heart-rate', [
            'child_id' => $child->id,
            'device_id' => $device->id,
            'device_name' => $device->name,
            'device_mac' => $device->mac,
            'bpm' => 88,
            'recorded_at' => now()->toDateTimeString(),
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.child_id', $child->id)
            ->assertJsonPath('data.device_id', $device->id);

        $this->assertDatabaseHas('heart_rate_logs', [
            'user_id' => $user->id,
            'child_id' => $child->id,
            'device_id' => $device->id,
            'bpm' => 88,
        ]);
    }

    #[Test]
    public function store_with_another_users_child_id_returns_403()
    {
        $user = User::factory()->create();
        $otherUser = User::factory()->create();
        $otherChild = Child::factory()->create(['user_id' => $otherUser->id]);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/heart-rate', [
            'child_id' => $otherChild->id,
            'bpm' => 85,
            'recorded_at' => now()->toDateTimeString(),
        ]);

        $response->assertStatus(403);
    }

    #[Test]
    public function store_with_another_users_device_id_returns_403()
    {
        $user = User::factory()->create();
        $otherUser = User::factory()->create();
        $otherChild = Child::factory()->create(['user_id' => $otherUser->id]);
        $otherDevice = Device::factory()->create(['child_id' => $otherChild->id]);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/heart-rate', [
            'device_id' => $otherDevice->id,
            'bpm' => 85,
            'recorded_at' => now()->toDateTimeString(),
        ]);

        $response->assertStatus(403);
    }

    #[Test]
    public function store_with_mismatched_child_id_and_device_id_returns_422()
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $childA = Child::factory()->create(['user_id' => $user->id]);
        $childB = Child::factory()->create(['user_id' => $user->id]);
        $deviceOfB = Device::factory()->create(['child_id' => $childB->id]);

        $response = $this->postJson('/api/heart-rate', [
            'child_id' => $childA->id,
            'device_id' => $deviceOfB->id,
            'bpm' => 90,
            'recorded_at' => now()->toDateTimeString(),
        ]);

        $response->assertStatus(422);
    }

    #[Test]
    public function store_with_only_device_id_autofills_child_id_from_device()
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $child = Child::factory()->create(['user_id' => $user->id]);
        $device = Device::factory()->create(['child_id' => $child->id]);

        $response = $this->postJson('/api/heart-rate', [
            'device_id' => $device->id,
            'bpm' => 92,
            'recorded_at' => now()->toDateTimeString(),
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.child_id', $child->id)
            ->assertJsonPath('data.device_id', $device->id);

        $this->assertDatabaseHas('heart_rate_logs', [
            'user_id' => $user->id,
            'child_id' => $child->id,
            'device_id' => $device->id,
            'bpm' => 92,
        ]);
    }

    #[Test]
    public function store_with_legacy_payload_without_child_id_or_device_id_returns_201()
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/heart-rate', [
            'device_name' => 'LEGACY_WATCH',
            'device_mac' => '11:22:33:44:55:66',
            'bpm' => 76,
            'recorded_at' => now()->toDateTimeString(),
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('heart_rate_logs', [
            'user_id' => $user->id,
            'child_id' => null,
            'device_id' => null,
            'bpm' => 76,
        ]);
    }

    #[Test]
    public function index_with_child_id_returns_only_logs_for_that_child()
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $childA = Child::factory()->create(['user_id' => $user->id]);
        $childB = Child::factory()->create(['user_id' => $user->id]);

        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $childA->id,
            'bpm' => 80,
            'recorded_at' => now()->subMinutes(5),
        ]);

        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $childB->id,
            'bpm' => 110,
            'recorded_at' => now()->subMinutes(2),
        ]);

        $response = $this->getJson('/api/heart-rate?child_id=' . $childA->id);

        $response->assertStatus(200)
            ->assertJsonCount(1)
            ->assertJsonPath('0.child_id', $childA->id)
            ->assertJsonPath('0.bpm', 80);
    }
}
