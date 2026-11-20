<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/share', function () {
    return response()->file(public_path('share.html'));
});
