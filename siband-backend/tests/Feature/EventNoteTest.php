<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use App\Models\User;
use App\Models\Child;
use App\Models\EventNote;

class EventNoteTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_list_own_child_event_notes()
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        EventNote::factory()->count(3)->create(['child_id' => $child->id]);

        $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/event-notes")
            ->assertOk()
            ->assertJsonCount(3);
    }

    public function test_user_can_create_event_note_for_own_child()
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $payload = [
            'type' => 'transisi',
            'note' => 'Test note',
        ];

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/children/{$child->id}/event-notes", $payload)
            ->assertCreated()
            ->assertJsonFragment(['type' => 'transisi', 'note' => 'Test note']);
    }

    public function test_validation_fails_for_invalid_type()
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $payload = ['type' => 'invalid_type'];

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/children/{$child->id}/event-notes", $payload)
            ->assertStatus(422);
    }

    public function test_user_cannot_access_another_users_child_event_notes()
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $owner->id]);
        EventNote::factory()->create(['child_id' => $child->id]);

        $this->actingAs($other, 'sanctum')
            ->getJson("/api/children/{$child->id}/event-notes")
            ->assertNotFound();
    }

    public function test_user_can_delete_own_event_note()
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $note = EventNote::factory()->create(['child_id' => $child->id]);

        $this->actingAs($user, 'sanctum')
            ->deleteJson("/api/event-notes/{$note->id}")
            ->assertOk()
            ->assertJson(['deleted' => true]);
    }

    public function test_user_cannot_delete_event_note_of_another_user()
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $owner->id]);
        $note = EventNote::factory()->create(['child_id' => $child->id]);

        $this->actingAs($other, 'sanctum')
            ->deleteJson("/api/event-notes/{$note->id}")
            ->assertStatus(404);
    }
}
