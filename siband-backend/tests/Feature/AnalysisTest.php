<?php

namespace Tests\Feature;

use App\Models\Child;
use App\Models\EventNote;
use App\Models\HeartRateLog;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class AnalysisTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    /**
     * Helper to seed >= 100 baseline samples 2 days before $now so baseline is sufficient:
     * 25 samples of 70 BPM, 50 samples of 80 BPM, 25 samples of 90 BPM -> p25=70, median=80, p75=90.
     * With episode_margin_bpm=10, threshold = 90 + 10 = 100 BPM.
     */
    private function seedSufficientBaseline(User $user, Child $child, Carbon $now): void
    {
        $baseStart = $now->copy()->subDays(2)->startOfDay();
        $bpms = array_merge(
            array_fill(0, 25, 70),
            array_fill(0, 50, 80),
            array_fill(0, 25, 90)
        );

        foreach ($bpms as $idx => $bpm) {
            HeartRateLog::create([
                'user_id' => $user->id,
                'child_id' => $child->id,
                'bpm' => $bpm,
                'recorded_at' => $baseStart->copy()->addSeconds($idx * 30),
            ]);
        }
    }

    #[Test]
    public function test_1_other_user_cannot_access_analysis_of_foreign_child(): void
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $owner->id]);

        $this->actingAs($other, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis")
            ->assertStatus(404);
    }

    #[Test]
    public function test_2_span_greater_than_7_days_returns_422(): void
    {
        $now = Carbon::parse('2026-11-06T12:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $from = urlencode($now->copy()->subDays(8)->toIso8601String());
        $to = urlencode($now->toIso8601String());

        $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis?from={$from}&to={$to}")
            ->assertStatus(422);
    }

    #[Test]
    public function test_3_insufficient_baseline_returns_empty_episodes_and_patterns_but_fills_series_and_quality(): void
    {
        $now = Carbon::parse('2026-11-06T10:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id, 'nickname' => 'Bima']);

        // Only 3 samples in window (< 100 minimum)
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'bpm' => 115,
            'recorded_at' => $now->copy()->subMinutes(5),
        ]);
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'bpm' => 120,
            'recorded_at' => $now->copy()->subMinutes(4),
        ]);
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'bpm' => 118,
            'recorded_at' => $now->copy()->subMinutes(2),
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis");

        $response->assertOk();
        $data = $response->json();

        $this->assertFalse($data['baseline']['sufficient']);
        $this->assertSame(3, $data['baseline']['sample_count']);
        $this->assertSame(100, $data['baseline']['min_samples']);
        $this->assertNull($data['baseline']['median']);
        $this->assertNull($data['baseline']['p25']);
        $this->assertNull($data['baseline']['p75']);

        $this->assertSame([], $data['episodes']);
        $this->assertFalse($data['patterns']['sufficient']);
        $this->assertSame([], $data['patterns']['hourly']);
        $this->assertSame([], $data['patterns']['by_note_type']);

        $this->assertCount(3, $data['series']);
        $this->assertSame(3, $data['quality']['sample_count']);
        $this->assertSame('belum_ada_baseline', $data['current']['status']);
    }

    #[Test]
    public function test_4_detects_single_episode_with_correct_peak_and_delta(): void
    {
        $now = Carbon::parse('2026-11-06T12:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child, $now);

        // Today window: threshold is 100 (p75=90 + 10), median=80
        // Normal reading before episode
        $t0 = Carbon::parse('2026-11-06T09:00:00Z');
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 82, 'recorded_at' => $t0]);

        // Episode: 09:01:00 to 09:04:00 (duration = 180s >= 120s), peak = 125, delta_from_median = 45
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 105, 'recorded_at' => $t0->copy()->addMinutes(1)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 125, 'recorded_at' => $t0->copy()->addMinutes(2)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 112, 'recorded_at' => $t0->copy()->addMinutes(4)]);

        // Sample <= threshold breaks the episode
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 95, 'recorded_at' => $t0->copy()->addMinutes(5)]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis");

        $response->assertOk();
        $episodes = $response->json('episodes');

        $this->assertCount(1, $episodes);
        $this->assertSame(1, $episodes[0]['index']);
        $this->assertSame(180, $episodes[0]['duration_seconds']);
        $this->assertSame(125, $episodes[0]['peak_bpm']);
        $this->assertEquals(45.0, $episodes[0]['delta_from_median']);
        $this->assertFalse($episodes[0]['has_sensor_gap']);
    }

    #[Test]
    public function test_5_samples_below_40_and_above_200_are_ignored(): void
    {
        $now = Carbon::parse('2026-11-06T12:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child, $now);

        $t0 = Carbon::parse('2026-11-06T08:00:00Z');
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 35, 'recorded_at' => $t0]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 85, 'recorded_at' => $t0->copy()->addMinutes(1)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 215, 'recorded_at' => $t0->copy()->addMinutes(2)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 88, 'recorded_at' => $t0->copy()->addMinutes(3)]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis");

        $response->assertOk();
        $data = $response->json();

        $this->assertCount(2, $data['series']);
        $this->assertSame(85, $data['series'][0]['bpm']);
        $this->assertSame(88, $data['series'][1]['bpm']);
        $this->assertSame(2, $data['quality']['sample_count']);
    }

    #[Test]
    public function test_6_episode_crossing_sensor_gap_sets_has_sensor_gap_true(): void
    {
        $now = Carbon::parse('2026-11-06T12:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child, $now);

        $t0 = Carbon::parse('2026-11-06T09:00:00Z');
        // Sample before gap (> 100)
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 110, 'recorded_at' => $t0]);
        // Sensor gap of 200 seconds (> gap_min_seconds=150), sample right after gap is also > 100
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 118, 'recorded_at' => $t0->copy()->addSeconds(200)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 114, 'recorded_at' => $t0->copy()->addSeconds(260)]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis");

        $response->assertOk();
        $episodes = $response->json('episodes');

        $this->assertCount(1, $episodes);
        $this->assertTrue($episodes[0]['has_sensor_gap']);
        $this->assertSame(260, $episodes[0]['duration_seconds']);
        $this->assertSame(118, $episodes[0]['peak_bpm']);
    }

    #[Test]
    public function test_7_sensor_gap_is_not_interpolated_in_series(): void
    {
        $now = Carbon::parse('2026-11-06T12:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $t1 = Carbon::parse('2026-11-06T08:00:00Z');
        $t2 = Carbon::parse('2026-11-06T08:05:00Z'); // 300s gap (> 150s)

        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 80, 'recorded_at' => $t1]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 84, 'recorded_at' => $t2]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis");

        $response->assertOk();
        $data = $response->json();

        // Series only has the 2 real points, no synthetic points inside the 300s gap
        $this->assertCount(2, $data['series']);
        $this->assertCount(1, $data['sensor_gaps']);
        $this->assertSame(300, $data['sensor_gaps'][0]['duration_seconds']);
    }

    #[Test]
    public function test_8_samples_after_aktivitas_fisik_note_do_not_form_episode(): void
    {
        $now = Carbon::parse('2026-11-06T12:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child, $now);

        $noteTime = Carbon::parse('2026-11-06T09:00:00Z');
        EventNote::create([
            'child_id' => $child->id,
            'type' => EventNote::TYPE_AKTIVITAS_FISIK,
            'note' => 'Anak berlari di halaman',
            'occurred_at' => $noteTime,
        ]);

        // High BPM samples within 10 minutes after aktivitas_fisik
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 130, 'recorded_at' => $noteTime->copy()->addMinutes(1)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 135, 'recorded_at' => $noteTime->copy()->addMinutes(3)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 128, 'recorded_at' => $noteTime->copy()->addMinutes(5)]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis");

        $response->assertOk();
        $this->assertSame([], $response->json('episodes'));
    }

    #[Test]
    public function test_9_suara_keras_and_meltdown_notes_do_not_exclude_episodes(): void
    {
        $now = Carbon::parse('2026-11-06T12:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child, $now);

        $noteTime = Carbon::parse('2026-11-06T09:00:00Z');
        EventNote::create([
            'child_id' => $child->id,
            'type' => EventNote::TYPE_SUARA_KERAS,
            'note' => 'Suara bor tetangga',
            'occurred_at' => $noteTime,
        ]);

        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 115, 'recorded_at' => $noteTime->copy()->addMinutes(1)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 122, 'recorded_at' => $noteTime->copy()->addMinutes(2)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 118, 'recorded_at' => $noteTime->copy()->addMinutes(4)]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis");

        $response->assertOk();
        $episodes = $response->json('episodes');
        $this->assertCount(1, $episodes);
        $this->assertSame('suara_keras', $episodes[0]['note']['type']);
    }

    #[Test]
    public function test_10_matches_closest_note_within_5_minutes_with_tie_breaker_and_null_when_none(): void
    {
        $now = Carbon::parse('2026-11-06T14:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child, $now);

        // Episode 1 starts at 09:00:00 -> tie between -120s and +120s -> earlier note wins
        $ep1Start = Carbon::parse('2026-11-06T09:00:00Z');
        $earlierNote = EventNote::create([
            'child_id' => $child->id,
            'type' => EventNote::TYPE_TRANSISI,
            'note' => 'Catatan lebih awal 2 menit',
            'occurred_at' => $ep1Start->copy()->subSeconds(120),
        ]);
        EventNote::create([
            'child_id' => $child->id,
            'type' => EventNote::TYPE_MELTDOWN,
            'note' => 'Catatan lebih akhir 2 menit',
            'occurred_at' => $ep1Start->copy()->addSeconds(120),
        ]);

        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 112, 'recorded_at' => $ep1Start]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 115, 'recorded_at' => $ep1Start->copy()->addMinutes(3)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 80, 'recorded_at' => $ep1Start->copy()->addMinutes(4)]);

        // Episode 2 starts at 11:00:00 -> note at 11:06:00 (360s > 300s) -> note = null
        $ep2Start = Carbon::parse('2026-11-06T11:00:00Z');
        EventNote::create([
            'child_id' => $child->id,
            'type' => EventNote::TYPE_SUARA_KERAS,
            'note' => 'Terlalu jauh dari mulai episode',
            'occurred_at' => $ep2Start->copy()->addSeconds(360),
        ]);

        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 114, 'recorded_at' => $ep2Start]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 119, 'recorded_at' => $ep2Start->copy()->addMinutes(3)]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis");

        $response->assertOk();
        $episodes = $response->json('episodes');
        $this->assertCount(2, $episodes);
        $this->assertSame($earlierNote->id, $episodes[0]['note']['id']);
        $this->assertNull($episodes[1]['note']);
    }

    #[Test]
    public function test_11_patterns_hourly_always_returns_24_entries_and_counts_episodes_accurately(): void
    {
        $now = Carbon::parse('2026-11-06T16:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child, $now);

        // Two episodes starting in hour 9, one episode starting in hour 14
        $t9a = Carbon::parse('2026-11-06T09:05:00Z');
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 110, 'recorded_at' => $t9a]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 115, 'recorded_at' => $t9a->copy()->addMinutes(3)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 80, 'recorded_at' => $t9a->copy()->addMinutes(4)]);

        $t9b = Carbon::parse('2026-11-06T09:30:00Z');
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 112, 'recorded_at' => $t9b]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 118, 'recorded_at' => $t9b->copy()->addMinutes(3)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 80, 'recorded_at' => $t9b->copy()->addMinutes(4)]);

        $t14 = Carbon::parse('2026-11-06T14:10:00Z');
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 111, 'recorded_at' => $t14]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 116, 'recorded_at' => $t14->copy()->addMinutes(3)]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis?tz=UTC");

        $response->assertOk();
        $hourly = $response->json('patterns.hourly');

        $this->assertCount(24, $hourly);
        $this->assertSame(9, $hourly[9]['hour']);
        $this->assertSame(2, $hourly[9]['episode_count']);
        $this->assertSame(14, $hourly[14]['hour']);
        $this->assertSame(1, $hourly[14]['episode_count']);
        $this->assertSame(0, $hourly[0]['episode_count']);
    }

    #[Test]
    public function test_12_patterns_by_note_type_marks_enough_false_when_notes_under_5_and_true_when_5(): void
    {
        $now = Carbon::parse('2026-11-06T18:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child, $now); // median = 80

        // Create 3 'transisi' notes (< 5) and 5 'suara_keras' notes (>= 5)
        for ($i = 0; $i < 3; $i++) {
            $nt = Carbon::parse('2026-11-06T08:00:00Z')->addMinutes($i * 20);
            EventNote::create(['child_id' => $child->id, 'type' => 'transisi', 'occurred_at' => $nt]);
            HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 100, 'recorded_at' => $nt->copy()->addMinutes(2)]);
        }

        for ($i = 0; $i < 5; $i++) {
            $nt = Carbon::parse('2026-11-06T11:00:00Z')->addMinutes($i * 20);
            EventNote::create(['child_id' => $child->id, 'type' => 'suara_keras', 'occurred_at' => $nt]);
            HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 110, 'recorded_at' => $nt->copy()->addMinutes(2)]);
        }

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis?tz=UTC");

        $response->assertOk();
        $byType = collect($response->json('patterns.by_note_type'))->keyBy('type');

        $this->assertFalse($byType->has('aktivitas_fisik'));

        $this->assertSame(3, $byType['transisi']['notes_used']);
        $this->assertFalse($byType['transisi']['enough']);
        $this->assertSame(20, $byType['transisi']['avg_rise_bpm']); // 100 - 80

        $this->assertSame(5, $byType['suara_keras']['notes_used']);
        $this->assertTrue($byType['suara_keras']['enough']);
        $this->assertSame(30, $byType['suara_keras']['avg_rise_bpm']); // 110 - 80
    }

    #[Test]
    public function test_13_quality_coverage_and_gap_count_match_manual_calculation(): void
    {
        $now = Carbon::parse('2026-11-06T10:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        // Window: 09:00:00 to 09:10:00 -> window_seconds = 600
        $from = Carbon::parse('2026-11-06T09:00:00Z');
        $to = Carbon::parse('2026-11-06T09:10:00Z');

        // Samples at:
        // 09:00:00, 09:01:00 (+60s <=150), 09:02:00 (+60s <=150), 09:07:00 (+300s >150 -> gap!), 09:08:00 (+60s <=150)
        // measured_seconds = 60 + 60 + 60 = 180s; gap_count = 1; gap_total_seconds = 300s
        // coverage_percent = (180 / 600) * 100 = 30.0%
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 80, 'recorded_at' => $from]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 82, 'recorded_at' => $from->copy()->addMinutes(1)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 81, 'recorded_at' => $from->copy()->addMinutes(2)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 85, 'recorded_at' => $from->copy()->addMinutes(7)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 83, 'recorded_at' => $from->copy()->addMinutes(8)]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/api/children/' . $child->id . '/analysis?tz=UTC&from=' . urlencode($from->toIso8601String()) . '&to=' . urlencode($to->toIso8601String()));

        $response->assertOk();
        $quality = $response->json('quality');

        $this->assertSame(600, $quality['window_seconds']);
        $this->assertSame(180, $quality['measured_seconds']);
        $this->assertEquals(30.0, $quality['coverage_percent']);
        $this->assertSame(5, $quality['sample_count']);
        $this->assertSame(1, $quality['gap_count']);
        $this->assertSame(300, $quality['gap_total_seconds']);
        $this->assertCount(24, $quality['per_hour']);
        $this->assertEquals(30.0, $quality['per_hour'][9]['coverage_percent']);
    }

    #[Test]
    public function test_14_current_measurement_state_for_three_conditions(): void
    {
        $now = Carbon::parse('2026-11-06T12:00:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();

        // 1. mengukur (age <= 150s)
        $child1 = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child1, $now);
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child1->id,
            'bpm' => 80,
            'recorded_at' => $now->copy()->subSeconds(60),
        ]);
        $res1 = $this->actingAs($user, 'sanctum')->getJson("/api/children/{$child1->id}/analysis")->assertOk();
        $this->assertSame('mengukur', $res1->json('current.measurement_state'));
        $this->assertSame('dalam_rentang', $res1->json('current.status'));

        // 2. istirahat_jam (150s < age <= 420s)
        $child2 = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child2, $now);
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child2->id,
            'bpm' => 95,
            'recorded_at' => $now->copy()->subSeconds(300),
        ]);
        $res2 = $this->actingAs($user, 'sanctum')->getJson("/api/children/{$child2->id}/analysis")->assertOk();
        $this->assertSame('istirahat_jam', $res2->json('current.measurement_state'));
        $this->assertSame('sedikit_di_atas', $res2->json('current.status'));

        // 3. tidak_ada_data (age > 420s)
        $child3 = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child3, $now);
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child3->id,
            'bpm' => 80,
            'recorded_at' => $now->copy()->subSeconds(600),
        ]);
        $res3 = $this->actingAs($user, 'sanctum')->getJson("/api/children/{$child3->id}/analysis")->assertOk();
        $this->assertSame('tidak_ada_data', $res3->json('current.measurement_state'));
    }

    #[Test]
    public function test_15_existing_routes_still_exist_and_response_contains_no_forbidden_words(): void
    {
        $uris = collect(Route::getRoutes()->getRoutes())->map(fn ($r) => $r->uri())->values()->all();

        $this->assertContains('api/devices/pair', $uris);
        $this->assertContains('api/heart-rate', $uris);
        $this->assertContains('api/children/{child}/baseline', $uris);
        $this->assertContains('api/share/{token}', $uris);
        $this->assertContains('api/children/{child}/analysis', $uris);

        $now = Carbon::parse('2026-11-06T12:00:00Z');
        Carbon::setTestNow($now);
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis")
            ->assertOk();

        $rawContent = strtolower($response->getContent());
        $this->assertStringNotContainsString('stres', $rawContent);
        $this->assertStringNotContainsString('emosi', $rawContent);
        $this->assertStringNotContainsString('cemas', $rawContent);
        $this->assertStringNotContainsString('prediksi', $rawContent);
    }

    #[Test]
    public function test_16_episode_at_0030_utc_with_jakarta_tz_falls_into_hour_7(): void
    {
        $now = Carbon::parse('2026-11-06T03:00:00Z'); // 10:00 in Asia/Jakarta
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child, $now);

        // Episode at 00:30 UTC -> 07:30 in Asia/Jakarta (+07:00)
        $epStart = Carbon::parse('2026-11-06T00:30:00Z');
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 112, 'recorded_at' => $epStart]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 120, 'recorded_at' => $epStart->copy()->addMinutes(2)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 115, 'recorded_at' => $epStart->copy()->addMinutes(3)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 80, 'recorded_at' => $epStart->copy()->addMinutes(4)]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis?tz=Asia/Jakarta")
            ->assertOk();

        $hourly = $response->json('patterns.hourly');
        $perHourQuality = $response->json('quality.per_hour');

        $this->assertSame(7, $hourly[7]['hour']);
        $this->assertSame(1, $hourly[7]['episode_count']);
        $this->assertSame(0, $hourly[0]['episode_count']);

        $this->assertGreaterThan(0, $perHourQuality[7]['coverage_percent']);
        $this->assertEquals(0.0, $perHourQuality[0]['coverage_percent']);
    }

    #[Test]
    public function test_17_default_window_follows_requested_tz_and_respects_explicit_offset_bounds(): void
    {
        // 2026-11-06T18:30:00Z is 2026-11-07T01:30:00+07:00 in Asia/Jakarta
        $now = Carbon::parse('2026-11-06T18:30:00Z');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        // 1. Default window with tz=Asia/Jakarta -> today 00:00 in Jakarta is 2026-11-07T00:00:00+07:00
        $resJakarta = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis?tz=Asia/Jakarta")
            ->assertOk();

        $this->assertSame('Asia/Jakarta', $resJakarta->json('window.timezone'));
        $this->assertSame('2026-11-07T00:00:00+07:00', $resJakarta->json('window.from'));
        $this->assertSame('2026-11-07T01:30:00+07:00', $resJakarta->json('window.to'));

        // 2. Default window with tz=UTC -> today 00:00 in UTC is 2026-11-06T00:00:00+00:00
        $resUtc = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis?tz=UTC")
            ->assertOk();

        $this->assertSame('UTC', $resUtc->json('window.timezone'));
        $this->assertSame('2026-11-06T00:00:00+00:00', $resUtc->json('window.from'));
        $this->assertSame('2026-11-06T18:30:00+00:00', $resUtc->json('window.to'));

        // 3. Explicit from/to with offset (+00:00) respected and converted to tz offset (+07:00)
        $fromExplicit = urlencode('2026-11-06T01:00:00+00:00');
        $toExplicit = urlencode('2026-11-06T05:00:00+00:00');
        $resExplicit = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis?tz=Asia/Jakarta&from={$fromExplicit}&to={$toExplicit}")
            ->assertOk();

        $this->assertSame('2026-11-06T08:00:00+07:00', $resExplicit->json('window.from'));
        $this->assertSame('2026-11-06T12:00:00+07:00', $resExplicit->json('window.to'));
    }

    #[Test]
    public function test_18_invalid_tz_returns_422(): void
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis?tz=Bukan/Timezone")
            ->assertStatus(422);

        $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis?tz=WIB")
            ->assertStatus(422);
    }

    #[Test]
    public function test_19_omitted_tz_uses_default_config_and_all_response_timestamps_carry_tz_offset(): void
    {
        $now = Carbon::parse('2026-11-06T05:00:00Z'); // 12:00:00+07:00 in Asia/Jakarta
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);
        $this->seedSufficientBaseline($user, $child, $now);

        // Episode at 02:00:00Z (09:00:00+07:00) to 02:03:00Z (09:03:00+07:00), followed by sensor gap to 02:10:00Z
        $t0 = Carbon::parse('2026-11-06T02:00:00Z');
        EventNote::create([
            'child_id' => $child->id,
            'type' => EventNote::TYPE_SUARA_KERAS,
            'note' => 'Suara keras pagi hari',
            'occurred_at' => $t0,
        ]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 115, 'recorded_at' => $t0]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 122, 'recorded_at' => $t0->copy()->addMinutes(3)]);
        HeartRateLog::create(['user_id' => $user->id, 'child_id' => $child->id, 'bpm' => 82, 'recorded_at' => $t0->copy()->addMinutes(10)]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis")
            ->assertOk();

        $data = $response->json();

        $this->assertSame('Asia/Jakarta', $data['window']['timezone']);
        $this->assertStringEndsWith('+07:00', $data['window']['from']);
        $this->assertStringEndsWith('+07:00', $data['window']['to']);
        $this->assertStringEndsWith('+07:00', $data['current']['recorded_at']);
        $this->assertStringEndsWith('+07:00', $data['series'][0]['t']);
        $this->assertStringEndsWith('+07:00', $data['sensor_gaps'][0]['from']);
        $this->assertStringEndsWith('+07:00', $data['sensor_gaps'][0]['to']);
        $this->assertStringEndsWith('+07:00', $data['notes'][0]['at']);
        $this->assertStringEndsWith('+07:00', $data['episodes'][0]['start']);
        $this->assertStringEndsWith('+07:00', $data['episodes'][0]['end']);
        $this->assertStringEndsWith('+07:00', $data['episodes'][0]['note']['at']);
    }

    #[Test]
    public function test_20_demo_analysis_command_generates_3_episodes_and_excludes_physical_activity(): void
    {
        $now = Carbon::parse('2026-11-06T16:00:00+07:00');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id, 'nickname' => 'Bima']);

        $this->artisan('siband:demo-analysis', [
            'child_id' => $child->id,
            '--date' => '2026-11-06',
            '--rest-minutes' => 5,
        ])->assertExitCode(0);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/analysis?tz=Asia/Jakarta")
            ->assertOk();

        $data = $response->json();

        $this->assertTrue($data['baseline']['sufficient']);
        $this->assertNotEmpty($data['sensor_gaps']);

        $episodes = $data['episodes'];
        $this->assertCount(3, $episodes);

        // Episode 1: 07:42 (6 minutes = 360s, peak 128), matched with transisi note at 07:40
        $this->assertSame('2026-11-06T07:42:00+07:00', $episodes[0]['start']);
        $this->assertSame(360, $episodes[0]['duration_seconds']);
        $this->assertSame(128, $episodes[0]['peak_bpm']);
        $this->assertNotNull($episodes[0]['note']);
        $this->assertSame('transisi', $episodes[0]['note']['type']);
        $this->assertSame('[DEMO] Berangkat sekolah', $episodes[0]['note']['text_preview']);

        // Episode 2: 10:15 (4 minutes = 240s, peak 118), matched with suara_keras note at 10:13
        $this->assertSame('2026-11-06T10:15:00+07:00', $episodes[1]['start']);
        $this->assertSame(240, $episodes[1]['duration_seconds']);
        $this->assertSame(118, $episodes[1]['peak_bpm']);
        $this->assertNotNull($episodes[1]['note']);
        $this->assertSame('suara_keras', $episodes[1]['note']['type']);
        $this->assertSame('[DEMO] Bel istirahat', $episodes[1]['note']['text_preview']);

        // Episode 3: 12:50 (9 minutes = 540s, peak 121), intentionally without note
        $this->assertSame('2026-11-06T12:50:00+07:00', $episodes[2]['start']);
        $this->assertSame(540, $episodes[2]['duration_seconds']);
        $this->assertSame(121, $episodes[2]['peak_bpm']);
        $this->assertNull($episodes[2]['note']);
    }

    #[Test]
    public function test_21_demo_analysis_command_refuses_in_production_and_fails_when_child_missing(): void
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $originalEnv = $this->app['env'];
        try {
            $this->app['env'] = 'production';
            $this->artisan('siband:demo-analysis', ['child_id' => $child->id])
                ->assertExitCode(1);
        } finally {
            $this->app['env'] = $originalEnv;
        }

        $this->assertSame(0, HeartRateLog::where('child_id', $child->id)->count());

        $this->artisan('siband:demo-analysis', ['child_id' => 999999])
            ->assertExitCode(1);
    }

    #[Test]
    public function test_22_demo_analysis_command_is_idempotent_and_purge_only_deletes_demo_data(): void
    {
        $now = Carbon::parse('2026-11-06T16:00:00+07:00');
        Carbon::setTestNow($now);

        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        // Create non-DEMO data that must never be touched
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'device_name' => 'Infinix XWatch H4',
            'bpm' => 84,
            'recorded_at' => Carbon::parse('2026-11-06T08:00:00+07:00')->setTimezone('UTC'),
        ]);
        EventNote::create([
            'child_id' => $child->id,
            'type' => EventNote::TYPE_LAINNYA,
            'note' => 'Catatan asli orang tua',
            'occurred_at' => Carbon::parse('2026-11-06T08:05:00+07:00')->setTimezone('UTC'),
        ]);

        // First run
        $this->artisan('siband:demo-analysis', [
            'child_id' => $child->id,
            '--date' => '2026-11-06',
        ])->assertExitCode(0);

        $logCountAfterFirst = HeartRateLog::where('child_id', $child->id)->count();
        $noteCountAfterFirst = EventNote::where('child_id', $child->id)->count();
        $this->assertGreaterThan(100, $logCountAfterFirst);
        $this->assertSame(4, $noteCountAfterFirst); // 1 real + 3 DEMO

        // Second run on the same date must not duplicate data
        $this->artisan('siband:demo-analysis', [
            'child_id' => $child->id,
            '--date' => '2026-11-06',
        ])->assertExitCode(0);

        $this->assertSame($logCountAfterFirst, HeartRateLog::where('child_id', $child->id)->count());
        $this->assertSame($noteCountAfterFirst, EventNote::where('child_id', $child->id)->count());

        // Purge must remove only DEMO data and leave real data intact
        $this->artisan('siband:demo-analysis', [
            'child_id' => $child->id,
            '--purge' => true,
        ])->assertExitCode(0);

        $this->assertSame(1, HeartRateLog::where('child_id', $child->id)->count());
        $this->assertSame('Infinix XWatch H4', HeartRateLog::where('child_id', $child->id)->first()->device_name);

        $this->assertSame(1, EventNote::where('child_id', $child->id)->count());
        $this->assertSame('Catatan asli orang tua', EventNote::where('child_id', $child->id)->first()->note);
    }
}
