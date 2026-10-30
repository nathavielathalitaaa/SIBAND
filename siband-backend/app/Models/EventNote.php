<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Child;

class EventNote extends Model
{
    use HasFactory;

    protected $fillable = [
        'child_id',
        'type',
        'note',
        'occurred_at',
    ];

    public function child()
    {
        return $this->belongsTo(Child::class);
    }
}

