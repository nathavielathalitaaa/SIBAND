<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Child;
use App\Models\Device;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class DeviceCrudTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function user_can_pair_device()
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $child = Child::factory()->create(['user_id' => $user->id]);

        $response = $this->postJson('/api/devices/pair', [
            'mac' => 'AA:BB:CC:DD:EE:FF',
            'name' => 'My Device',
            'child_id' => $child->id,
        ]);
        $response->assertStatus(201);
        $this->assertDatabaseHas('devices', [
            'mac' => 'AA:BB:CC:DD:EE:FF',
            'name' => 'My Device',
            'child_id' => $child->id,
        ]);
    }

    #[Test]
    public function user_can_repair_device_to_another_child_of_same_user()
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $child1 = Child::factory()->create(['user_id' => $user->id]);
        $child2 = Child::factory()->create(['user_id' => $user->id]);

        $this->postJson('/api/devices/pair', [
            'mac' => 'AA:BB:CC:DD:EE:FF',
            'name' => 'Device One',
            'child_id' => $child1->id,
        ])->assertStatus(201);

        $response = $this->postJson('/api/devices/pair', [
            'mac' => 'AA:BB:CC:DD:EE:FF',
            'name' => 'Device One Updated',
            'child_id' => $child2->id,
        ]);
        $response->assertStatus(200);
        $this->assertDatabaseHas('devices', [
            'mac' => 'AA:BB:CC:DD:EE:FF',
            'name' => 'Device One Updated',
            'child_id' => $child2->id,
        ]);
    }

    #[Test]
    public function other_user_cannot_pair_device_to_foreign_child()
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $owner->id]);

        Sanctum::actingAs($other);

        $this->postJson('/api/devices/pair', [
            'mac' => 'AA:BB:CC:DD:EE:FF',
            'name' => 'Bad Device',
            'child_id' => $child->id,
        ])->assertStatus(403);
    }
}
