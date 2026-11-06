<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use App\Models\User;
use App\Models\Child;
use App\Models\HeartRateLog;
use App\Models\EventNote;
use Carbon\Carbon;

use PHPUnit\Framework\Attributes\Test;
class BaselineTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function baseline_returns_statistics_when_enough_samples()
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        // Create 150 heart rate logs within last 7 days, BPM within range
        $now = Carbon::now();
        foreach (range(1, 150) as $i) {
            HeartRateLog::create([
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

    #[Test]
    public function baseline_excludes_out_of_range_and_event_related_samples()
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $now = Carbon::now();

        // In‑range log
        HeartRateLog::create([
            'child_id' => $child->id,
            'bpm' => 80,
            'recorded_at' => $now->copy()->subDays(1),
        ]);
        // Out‑of‑range log (should be excluded)
        HeartRateLog::create([
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
        HeartRateLog::create([
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

    #[Test]
    public function baseline_returns_insufficient_when_few_samples()
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        // 50 logs only
        foreach (range(1, 50) as $i) {
            HeartRateLog::create([
                'child_id' => $child->id,
                'bpm' => rand(60, 120),
                'recorded_at' => Carbon::now()->subDays(2),
            ]);
        }
        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/baseline?days=7");
        $response->assertOk()->assertJson(['sufficient' => false]);
    }

    #[Test]
    public function other_user_cannot_access_baseline_of_foreign_child()
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $owner->id]);
        $response = $this->actingAs($other, 'sanctum')
            ->getJson("/api/children/{$child->id}/baseline");
        $response->assertNotFound();
    }

    #[Test]
    public function baseline_excludes_sample_20_minutes_after_physical_activity_but_keeps_sample_20_minutes_after_suara_keras()
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $now = Carbon::now();

        // Catatan aktivitas_fisik (jendela pembuangan 30 menit) -> sampel +20 menit HARUS dibuang
        $physicalNoteTime = $now->copy()->subHours(6);
        EventNote::create([
            'child_id' => $child->id,
            'type' => EventNote::TYPE_AKTIVITAS_FISIK,
            'note' => 'Bermain sepeda',
            'occurred_at' => $physicalNoteTime,
        ]);
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'bpm' => 115,
            'recorded_at' => $physicalNoteTime->copy()->addMinutes(20),
        ]);

        // Catatan suara_keras (jendela pembuangan 10 menit) -> sampel +20 menit TIDAK dibuang
        $loudNoiseNoteTime = $now->copy()->subHours(3);
        EventNote::create([
            'child_id' => $child->id,
            'type' => EventNote::TYPE_SUARA_KERAS,
            'note' => 'Suara klakson',
            'occurred_at' => $loudNoiseNoteTime,
        ]);
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'bpm' => 84,
            'recorded_at' => $loudNoiseNoteTime->copy()->addMinutes(20),
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/baseline?days=7");

        $response->assertOk();
        $data = $response->json();

        // Sampel +20m setelah aktivitas_fisik dibuang (excluded_count=1), sampel +20m setelah suara_keras tetap dihitung (sample_count=1)
        $this->assertSame(1, $data['sample_count']);
        $this->assertSame(1, $data['excluded_count']);
    }
}
