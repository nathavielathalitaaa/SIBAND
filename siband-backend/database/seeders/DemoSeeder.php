<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DemoSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // User demo
        $user = \App\Models\User::create([
            'name' => 'Demo User',
            'email' => 'demo@siband.test',
            'password' => bcrypt('Demo_12345'),
        ]);

        // Child demo
        $child = \App\Models\Child::create([
            'user_id' => $user->id,
            'nickname' => 'Anak Demo',
            'birth_year' => 2018,
        ]);

        // Device demo
        $device = \App\Models\Device::create([
            'child_id' => $child->id,
            'name' => 'Infinix XWatch H4',
            'mac' => 'AA:BB:CC:DD:EE:FF',
            'last_seen_at' => now(),
        ]);

        // 100 heart rate logs over last 24h
        $now = \Carbon\Carbon::now();
        for ($i = 0; $i < 100; $i++) {
            $timestamp = $now->copy()->subMinutes(rand(0, 1440));
            \App\Models\HeartRateLog::create([
                'user_id' => $user->id,
                'child_id' => $child->id,
                'device_id' => $device->id,
                'device_name' => $device->name,
                'device_mac' => $device->mac,
                'bpm' => rand(70, 110),
                'recorded_at' => $timestamp,
            ]);
        }
    }
}
