<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Child;

class EventNote extends Model
{
    use HasFactory;

    public const TYPE_TRANSISI = 'transisi';
    public const TYPE_SUARA_KERAS = 'suara_keras';
    public const TYPE_MELTDOWN = 'meltdown';
    public const TYPE_AKTIVITAS_FISIK = 'aktivitas_fisik';
    public const TYPE_PERUBAHAN_AKTIVITAS = 'perubahan_aktivitas';
    public const TYPE_AKTIVITAS_SULIT = 'aktivitas_sulit';
    public const TYPE_INTERAKSI_SOSIAL = 'interaksi_sosial';
    public const TYPE_LAINNYA = 'lainnya';

    public const TYPES = [
        self::TYPE_TRANSISI,
        self::TYPE_SUARA_KERAS,
        self::TYPE_MELTDOWN,
        self::TYPE_AKTIVITAS_FISIK,
        self::TYPE_PERUBAHAN_AKTIVITAS,
        self::TYPE_AKTIVITAS_SULIT,
        self::TYPE_INTERAKSI_SOSIAL,
        self::TYPE_LAINNYA,
    ];

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

