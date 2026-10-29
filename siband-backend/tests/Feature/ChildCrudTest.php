<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Child;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ChildCrudTest extends TestCase
{
    use RefreshDatabase;

    /** @test */
    public function user_can_crud_own_child()
    {
        // Create a user and authenticate
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Create child
        $response = $this->postJson('/api/children', [
            'nickname' => 'Anak A',
            'birth_year' => 2020,
        ]);
        $response->assertStatus(201);
        $childId = $response->json('id');

        // Show child
        $this->getJson("/api/children/{$childId}")->assertStatus(200);

        // Update child
        $this->putJson("/api/children/{$childId}", ['nickname' => 'Anak B'])->assertStatus(200);

        // Delete child
        $this->deleteJson("/api/children/{$childId}")->assertStatus(200);
    }

    /** @test */
    public function other_user_cannot_access_foreign_child()
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        Sanctum::actingAs($owner);
        $child = Child::factory()->create(['user_id' => $owner->id]);

        Sanctum::actingAs($other);
        $this->getJson("/api/children/{$child->id}")->assertStatus(403);
        $this->putJson("/api/children/{$child->id}", ['nickname' => 'X'])->assertStatus(403);
        $this->deleteJson("/api/children/{$child->id}")->assertStatus(403);
    }
}
