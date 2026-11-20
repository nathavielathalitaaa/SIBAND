<?php

// Entrypoint Laravel untuk Vercel Serverless PHP (filesystem /var/task bersifat read-only).

// 1. Siapkan direktori writable di /tmp
$tmpDirs = [
    '/tmp/storage/app',
    '/tmp/storage/framework/cache/data',
    '/tmp/storage/framework/sessions',
    '/tmp/storage/framework/views',
    '/tmp/storage/logs',
    '/tmp/bootstrap/cache',
];
foreach ($tmpDirs as $dir) {
    if (! is_dir($dir)) {
        @mkdir($dir, 0775, true);
    }
}

// 2. Sambungkan otomatis env database dari Vercel Storage (Neon Postgres) ke Laravel DB_URL
$neonUrl = getenv('DB_URL')
    ?: getenv('DATABASE_URL')
    ?: getenv('POSTGRES_URL')
    ?: getenv('STORAGE_DATABASE_URL')
    ?: getenv('STORAGE_POSTGRES_URL')
    ?: getenv('STORAGE_URL')
    ?: '';
if ($neonUrl !== '') {
    putenv("DB_URL={$neonUrl}");
    $_ENV['DB_URL'] = $neonUrl;
    $_SERVER['DB_URL'] = $neonUrl;

    if (! getenv('DB_CONNECTION')) {
        putenv('DB_CONNECTION=pgsql');
        $_ENV['DB_CONNECTION'] = 'pgsql';
        $_SERVER['DB_CONNECTION'] = 'pgsql';
    }
}

// 3. Normalisasi APP_KEY bila pengguna mengisi string bebas tanpa awalan base64:
$appKey = getenv('APP_KEY') ?: '';
if ($appKey !== '' && ! str_starts_with($appKey, 'base64:')) {
    $normalized = 'base64:'.base64_encode(hash('sha256', $appKey, true));
    putenv("APP_KEY={$normalized}");
    $_ENV['APP_KEY'] = $normalized;
    $_SERVER['APP_KEY'] = $normalized;
}

// 4. Otomatis jalankan migrasi pertama kali pada cold start bila tabel belum ada (pakai instance terpisah)
define('LARAVEL_START', microtime(true));

require __DIR__.'/../vendor/autoload.php';

$migratedMarker = '/tmp/.siband_migrated';
if ($neonUrl !== '' && ! is_file($migratedMarker)) {
    try {
        /** @var \Illuminate\Foundation\Application $migrateApp */
        $migrateApp = require __DIR__.'/../bootstrap/app.php';
        $migrateApp->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();
        if (! \Illuminate\Support\Facades\Schema::hasTable('users') ||
            ! \Illuminate\Support\Facades\Schema::hasColumn('share_links', 'short_code')) {
            \Illuminate\Support\Facades\Artisan::call('migrate', ['--force' => true]);
        }
        @file_put_contents($migratedMarker, (string) time());
    } catch (\Throwable $e) {
        // Biarkan request tetap lanjut agar log error tampil jelas di Vercel Runtime Logs.
        error_log('[Siband Vercel Auto-Migrate] '.$e->getMessage());
    }
}

/** @var \Illuminate\Foundation\Application $app */
$app = require __DIR__.'/../bootstrap/app.php';

// Cegah Symfony/Laravel memotong prefix '/api' karena entrypoint berada di /api/index.php
$_SERVER['SCRIPT_NAME'] = '/index.php';
$_SERVER['SCRIPT_FILENAME'] = __DIR__.'/../public/index.php';
$_SERVER['PHP_SELF'] = '/index.php';

$app->handleRequest(\Illuminate\Http\Request::capture());
