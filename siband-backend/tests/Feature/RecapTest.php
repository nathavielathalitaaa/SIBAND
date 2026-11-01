<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use App\Models\User;
use App\Models\Child;
use App\Models\HeartRateLog;
use App\Models\EventNote;
use Carbon\Carbon;

class RecapTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_get_monthly_recap_with_correct_calculations(): void
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        // Known readings on 2026-11-05
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'bpm' => 80,
            'recorded_at' => Carbon::parse('2026-11-05 08:00:00'),
        ]);
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'bpm' => 100,
            'recorded_at' => Carbon::parse('2026-11-05 10:00:00'),
        ]);
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'bpm' => 120,
            'recorded_at' => Carbon::parse('2026-11-05 12:00:00'),
        ]);

        // Known readings on 2026-11-06
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'bpm' => 70,
            'recorded_at' => Carbon::parse('2026-11-06 09:00:00'),
        ]);
        HeartRateLog::create([
            'user_id' => $user->id,
            'child_id' => $child->id,
            'bpm' => 90,
            'recorded_at' => Carbon::parse('2026-11-06 15:00:00'),
        ]);

        // Event notes
        EventNote::create([
            'child_id' => $child->id,
            'type' => 'suara_keras',
            'note' => 'Sirine ambulans',
            'occurred_at' => Carbon::parse('2026-11-05 10:01:00'),
        ]);
        EventNote::create([
            'child_id' => $child->id,
            'type' => 'suara_keras',
            'note' => 'Petir menggelegar',
            'occurred_at' => Carbon::parse('2026-11-06 14:30:00'),
        ]);
        EventNote::create([
            'child_id' => $child->id,
            'type' => 'transisi',
            'note' => 'Pindah ruangan kelas',
            'occurred_at' => Carbon::parse('2026-11-06 15:30:00'),
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/recap?month=2026-11");

        $response->assertOk()
            ->assertJson([
                'periode' => '2026-11',
                'jumlah_sampel' => 5,
                'rata_rata' => 92.0,
                'maksimum' => 120,
                'jumlah_hari' => 2,
            ]);

        $json = $response->json();

        // Verify ringkasan per hari
        $this->assertCount(2, $json['ringkasan_per_hari']);
        $day1 = $json['ringkasan_per_hari'][0];
        $this->assertSame('2026-11-05', $day1['tanggal']);
        $this->assertSame(100.0, (float) $day1['rata_rata']);
        $this->assertSame(120, $day1['maksimum']);
        $this->assertSame(3, $day1['jumlah_sampel']);

        $day2 = $json['ringkasan_per_hari'][1];
        $this->assertSame('2026-11-06', $day2['tanggal']);
        $this->assertSame(80.0, (float) $day2['rata_rata']);
        $this->assertSame(90, $day2['maksimum']);
        $this->assertSame(2, $day2['jumlah_sampel']);

        // Verify catatan kejadian grouped and list
        $this->assertSame(2, $json['catatan_kejadian']['per_tipe']['suara_keras']);
        $this->assertSame(1, $json['catatan_kejadian']['per_tipe']['transisi']);
        $this->assertCount(3, $json['catatan_kejadian']['daftar']);
    }

    public function test_recap_without_data_does_not_error(): void
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/recap?month=2025-01");

        $response->assertOk()
            ->assertJson([
                'periode' => '2025-01',
                'jumlah_sampel' => 0,
                'rata_rata' => null,
                'maksimum' => null,
                'jumlah_hari' => 0,
                'ringkasan_per_hari' => [],
                'catatan_kejadian' => [
                    'per_tipe' => [],
                    'daftar' => [],
                ],
            ]);
    }

    public function test_recap_defaults_to_current_month_when_month_param_omitted(): void
    {
        $user = User::factory()->create();
        $child = Child::factory()->create(['user_id' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson("/api/children/{$child->id}/recap");

        $response->assertOk()
            ->assertJson([
                'periode' => Carbon::now()->format('Y-m'),
            ]);
    }

    public function test_other_user_cannot_access_recap_of_another_users_child(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $childA = Child::factory()->create(['user_id' => $userA->id]);

        $this->actingAs($userB, 'sanctum')
            ->getJson("/api/children/{$childA->id}/recap")
            ->assertStatus(404);
    }
}
