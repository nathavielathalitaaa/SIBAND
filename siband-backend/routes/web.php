<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->file(public_path('download.html'));
});

Route::get('/share', function () {
    return response()->file(public_path('share.html'));
});

Route::get('/download', function () {
    return response()->file(public_path('download.html'));
});

Route::get('/download/siband.apk', function () {
    $apkPath = public_path('downloads/siband.apk');
    if (is_file($apkPath)) {
        return response()->download($apkPath, 'siband-release.apk', [
            'Content-Type' => 'application/vnd.android.package-archive',
            'Cache-Control' => 'no-store',
        ]);
    }

    $externalApkUrl = trim((string) env('APK_DOWNLOAD_URL', ''));
    if ($externalApkUrl !== '' && preg_match('#^https?://#i', $externalApkUrl)) {
        return redirect()->away($externalApkUrl);
    }

    abort(404, 'File APK rilis Siband belum tersedia di server.');
});
