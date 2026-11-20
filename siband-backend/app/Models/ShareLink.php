<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Hash;

class ShareLink extends Model
{
    use HasFactory;

    protected $fillable = [
        'child_id',
        'token_hash',
        'short_code',
        'pin_hash',
        'expires_at',
        'revoked_at',
        'last_accessed_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'revoked_at' => 'datetime',
        'last_accessed_at' => 'datetime',
    ];

    public function requiresPin(): bool
    {
        return $this->pin_hash !== null && $this->pin_hash !== '';
    }

    public function verifyPin(?string $pin): bool
    {
        if (! $this->requiresPin()) {
            return true;
        }
        if ($pin === null || trim($pin) === '') {
            return false;
        }

        return Hash::check(trim($pin), $this->pin_hash);
    }

    public function child()
    {
        return $this->belongsTo(Child::class);
    }

    public function isRevoked(): bool
    {
        return $this->revoked_at !== null;
    }

    public function isExpired(): bool
    {
        return $this->expires_at->isPast();
    }

    public function isValid(): bool
    {
        return !$this->isRevoked() && !$this->isExpired();
    }

    public function getStatusAttribute(): string
    {
        if ($this->revoked_at !== null) {
            return 'revoked';
        }
        if ($this->expires_at->isPast()) {
            return 'expired';
        }
        return 'active';
    }
}
