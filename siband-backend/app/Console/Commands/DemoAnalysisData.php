<?php

namespace App\Console\Commands;

use App\Models\Child;
use App\Models\EventNote;
use App\Models\HeartRateLog;
use Carbon\Carbon;
use Illuminate\Console\Command;

class DemoAnalysisData extends Command
{
    protected $signature = 'siband:demo-analysis
                            {child_id : ID anak yang akan diisi data demo}
                            {--date= : Tanggal data demo (YYYY-MM-DD), default hari ini di Asia/Jakarta}
                            {--rest-minutes=5 : Durasi jeda istirahat sensor tiruan dalam menit}
                            {--purge : Hapus hanya data DEMO milik anak tersebut}';

    protected $description = 'Buat atau hapus data demo analisis detak jantung dan catatan kejadian (khusus lokal/pengembangan).';

    public function handle(): int
    {
        if (app()->environment('production')) {
            $this->error('Perintah siband:demo-analysis tidak boleh dijalankan di environment production.');
            return self::FAILURE;
        }

        $childId = $this->argument('child_id');
        $child = Child::find($childId);

        if (!$child) {
            $this->error("Anak dengan ID {$childId} tidak ditemukan.");
            return self::FAILURE;
        }

        if ($this->option('purge')) {
            $deletedLogs = HeartRateLog::where('child_id', $child->id)
                ->where('device_name', 'DEMO')
                ->delete();

            $deletedNotes = EventNote::where('child_id', $child->id)
                ->where('note', 'like', '[DEMO] %')
                ->delete();

            $this->info("Data DEMO untuk anak #{$child->id} ({$child->nickname}) berhasil dihapus: {$deletedLogs} sampel, {$deletedNotes} catatan.");
            return self::SUCCESS;
        }

        $tz = 'Asia/Jakarta';
        $appTz = (string) config('app.timezone', 'UTC');
        $dateOption = $this->option('date');

        try {
            $targetDay = ($dateOption !== null && $dateOption !== '')
                ? Carbon::createFromFormat('Y-m-d', (string) $dateOption, $tz)->startOfDay()
                : Carbon::now($tz)->startOfDay();
        } catch (\Exception $e) {
            $this->error("Format --date tidak valid: {$dateOption}. Gunakan YYYY-MM-DD.");
            return self::FAILURE;
        }

        // Nilai tiruan untuk simulasi; siklus istirahat asli jam belum terbukti secara empiris
        $restMinutes = max(0, (int) $this->option('rest-minutes'));

        // Hapus data DEMO yang sudah ada pada tanggal tersebut agar idempoten
        $dayStartDb = $targetDay->copy()->startOfDay()->setTimezone($appTz);
        $dayEndDb = $targetDay->copy()->endOfDay()->setTimezone($appTz);

        HeartRateLog::where('child_id', $child->id)
            ->where('device_name', 'DEMO')
            ->whereBetween('recorded_at', [$dayStartDb, $dayEndDb])
            ->delete();

        EventNote::where('child_id', $child->id)
            ->where('note', 'like', '[DEMO] %')
            ->whereBetween('occurred_at', [$dayStartDb, $dayEndDb])
            ->delete();

        // Catatan kejadian DEMO:
        // 1. 07:40 transisi ("[DEMO] Berangkat sekolah") -> terhubung ke Episode 1 (07:42)
        // 2. 09:00 aktivitas_fisik -> mengecualikan kenaikan 09:00-09:30 dari episode
        // 3. 10:13 suara_keras ("[DEMO] Bel istirahat") -> terhubung ke Episode 2 (10:15)
        // Episode 3 (12:50) sengaja tanpa catatan kejadian.
        $demoNotes = [
            [
                'time' => '07:40:00',
                'type' => EventNote::TYPE_TRANSISI,
                'note' => '[DEMO] Berangkat sekolah',
            ],
            [
                'time' => '09:00:00',
                'type' => EventNote::TYPE_AKTIVITAS_FISIK,
                'note' => '[DEMO] Aktivitas fisik olahraga pagi',
            ],
            [
                'time' => '10:13:00',
                'type' => EventNote::TYPE_SUARA_KERAS,
                'note' => '[DEMO] Bel istirahat',
            ],
        ];

        foreach ($demoNotes as $n) {
            $occurredAt = Carbon::parse($targetDay->toDateString() . ' ' . $n['time'], $tz)->setTimezone($appTz);
            EventNote::create([
                'child_id' => $child->id,
                'type' => $n['type'],
                'note' => $n['note'],
                'occurred_at' => $occurredAt,
            ]);
        }

        // Definisi 3 episode kenaikan BPM (menit dihitung dari 06:00 WIB):
        // Episode 1: 07:42 (menit 102..108, durasi 6 menit, puncak 128)
        // Episode 2: 10:15 (menit 255..259, durasi 4 menit, puncak 118)
        // Episode 3: 12:50 (menit 410..419, durasi 9 menit, puncak 121)
        $episodeBpms = [
            // Episode 1: 07:42 - 07:48 (6 menit, puncak 128)
            102 => 114,
            103 => 119,
            104 => 124,
            105 => 128,
            106 => 123,
            107 => 118,
            108 => 112,
            // Episode 2: 10:15 - 10:19 (4 menit, puncak 118)
            255 => 110,
            256 => 114,
            257 => 118,
            258 => 115,
            259 => 111,
            // Episode 3: 12:50 - 12:59 (9 menit, puncak 121)
            410 => 110,
            411 => 113,
            412 => 116,
            413 => 119,
            414 => 121,
            415 => 120,
            416 => 118,
            417 => 115,
            418 => 112,
            419 => 110,
        ];

        // Menit yang wajib memiliki sampel (episode beserta 1 menit pembatas sebelum/sesudahnya)
        // agar episode tidak jatuh ke dalam jeda sensor tiruan.
        $protectedMinutes = [];
        foreach ([range(101, 109), range(254, 260), range(409, 420)] as $range) {
            foreach ($range as $m) {
                $protectedMinutes[$m] = true;
            }
        }

        // Siklus aktif 10-15 menit sebelum jeda istirahat sensor tiruan (--rest-minutes).
        // Nilai tiruan untuk simulasi; siklus asli jam belum terbukti.
        $activeBurstLengths = [12, 14, 11, 15, 13];
        $burstIndex = 0;
        $activeCounter = 0;
        $restRemaining = 0;

        $baseVariations = [-5, -3, -2, -1, 0, 0, 1, 2, 3, 5];
        $activityVariations = [-2, -1, 0, 1, 2];

        $startTimeLocal = $targetDay->copy()->setTime(6, 0, 0);
        $nowSql = Carbon::now($appTz)->toDateTimeString();
        $rows = [];

        // 06:00 sampai 14:00 WIB = 480 menit (indeks 0..480)
        for ($minute = 0; $minute <= 480; $minute++) {
            $isProtected = isset($protectedMinutes[$minute]);

            if (!$isProtected && $restMinutes > 0) {
                if ($restRemaining > 0) {
                    $restRemaining--;
                    continue;
                }

                $targetBurst = $activeBurstLengths[$burstIndex % count($activeBurstLengths)];
                if ($activeCounter >= $targetBurst) {
                    $burstIndex++;
                    $activeCounter = 0;
                    // Hentikan sampel selama --rest-minutes menit (nilai tiruan, siklus asli jam belum terbukti)
                    $restRemaining = $restMinutes - 1;
                    continue;
                }
            }

            $activeCounter++;

            if (isset($episodeBpms[$minute])) {
                $bpm = $episodeBpms[$minute];
            } elseif ($minute >= 180 && $minute <= 210) {
                // Aktivitas fisik 09:00-09:30 WIB: BPM naik wajar sekitar 115
                $bpm = 115 + $activityVariations[$minute % count($activityVariations)];
            } else {
                // BPM dasar sekitar 92 dengan variasi kecil +-5
                $bpm = 92 + $baseVariations[$minute % count($baseVariations)];
            }

            $sampleTimeDb = $startTimeLocal->copy()->addMinutes($minute)->setTimezone($appTz);

            $rows[] = [
                'user_id' => $child->user_id,
                'child_id' => $child->id,
                'device_id' => null,
                'device_name' => 'DEMO',
                'device_mac' => null,
                'bpm' => $bpm,
                'recorded_at' => $sampleTimeDb->toDateTimeString(),
                'created_at' => $nowSql,
                'updated_at' => $nowSql,
            ];
        }

        foreach (array_chunk($rows, 200) as $chunk) {
            HeartRateLog::insert($chunk);
        }

        $sampleCount = count($rows);
        $noteCount = count($demoNotes);
        $dateStr = $targetDay->toDateString();

        $this->info("Data demo analisis berhasil dibuat untuk anak #{$child->id} ({$child->nickname}) pada {$dateStr}: {$sampleCount} sampel, {$noteCount} catatan.");

        return self::SUCCESS;
    }
}
