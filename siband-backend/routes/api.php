<?php

use App\Http\Controllers\Api\HeartRateController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

Route::post('/heart-rate', [HeartRateController::class, 'store']);
Route::get('/heart-rate', [HeartRateController::class, 'index']);

