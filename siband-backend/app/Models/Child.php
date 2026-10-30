<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Child extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'nickname',
        'birth_year',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function devices()
    {
        return $this->hasMany(Device::class);
    }

    public function heartRateLogs()
    {
        return $this->hasMany(HeartRateLog::class);
    }
}
