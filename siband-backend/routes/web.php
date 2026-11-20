<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/share', function () {
    return response()->file(public_path('share.html'));
});

Route::get('/download', function () {
    return response()->file(public_path('download.html'));
});

Route::get('/download/siband.apk', function () {
    $apkPath = public_path('downloads/siband.apk');
    if (! is_file($apkPath)) {
        abort(404, 'File APK rilis Siband belum tersedia di server.');
    }

    return response()->download($apkPath, 'siband-release.apk', [
        'Content-Type' => 'application/vnd.android.package-archive',
        'Cache-Control' => 'no-store',
    ]);
});
