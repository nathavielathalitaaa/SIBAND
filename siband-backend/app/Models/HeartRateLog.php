<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class HeartRateLog extends Model
{
    protected $fillable = [
        'device_name',
        'device_mac',
        'bpm',
        'recorded_at',
    ];

    protected function casts(): array
    {
        return [
            'recorded_at' => 'datetime',
        ];
    }
}
