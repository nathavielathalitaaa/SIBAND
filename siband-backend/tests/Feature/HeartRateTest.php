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
}
