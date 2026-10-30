<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use App\Models\User;
use App\Models\Child;
use App\Models\HeartRateLog;
use App\Models\EventNote;
use Carbon\Carbon;

class BaselineTest extends TestCase
{
    use RefreshDatabase;

    /** @test */
    public function baseline_returns_statistics_when_enough_samples()
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        // Create 150 heart rate logs within last 7 days, BPM within range
        $now = Carbon::now();
        foreach (range(1, 150) as $i) {
            HeartRateLog::factory()->create([
                'child_id' => $child->id,
                'bpm' => rand(60, 120),
                'recorded_at' => $now->copy()->subDays(3)->subMinutes($i),
            ]);
        }

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/baseline?days=7");

        $response->assertOk()
            ->assertJsonFragment([
                'child_id' => $child->id,
                'days' => 7,
                'sufficient' => true,
            ])
            ->assertJsonStructure([
                'median', 'p25', 'p75', 'sample_count', 'excluded_count', 'computed_at'
            ]);
    }

    /** @test */
    public function baseline_excludes_out_of_range_and_event_related_samples()
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $now = Carbon::now();

        // In‑range log
        HeartRateLog::factory()->create([
            'child_id' => $child->id,
            'bpm' => 80,
            'recorded_at' => $now->copy()->subDays(1),
        ]);
        // Out‑of‑range log (should be excluded)
        HeartRateLog::factory()->create([
            'child_id' => $child->id,
            'bpm' => 30,
            'recorded_at' => $now->copy()->subDays(1),
        ]);
        // Event note and a log within 10 minutes after (should be excluded)
        $event = EventNote::factory()->create([
            'child_id' => $child->id,
            'type' => 'suara_keras',
            'occurred_at' => $now->copy()->subHours(5),
        ]);
        HeartRateLog::factory()->create([
            'child_id' => $child->id,
            'bpm' => 85,
            'recorded_at' => Carbon::parse($event->occurred_at)->addMinutes(5),
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/baseline?days=7");
        $response->assertOk();
        $data = $response->json();
        // Only the first in‑range log should be counted
        $this->assertEquals(1, $data['sample_count']);
        $this->assertEquals(1, $data['excluded_count']);
        $this->assertFalse($data['sufficient']);
    }

    /** @test */
    public function baseline_returns_insufficient_when_few_samples()
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        // 50 logs only
        foreach (range(1, 50) as $i) {
            HeartRateLog::factory()->create([
                'child_id' => $child->id,
                'bpm' => rand(60, 120),
                'recorded_at' => Carbon::now()->subDays(2),
            ]);
        }
        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/baseline?days=7");
        $response->assertOk()->assertJson(['sufficient' => false]);
    }

    /** @test */
    public function other_user_cannot_access_baseline_of_foreign_child()
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $owner->id]);
        $response = $this->actingAs($other, 'sanctum')
            ->getJson("/api/children/{$child->id}/baseline");
        $response->assertNotFound();
    }
}
