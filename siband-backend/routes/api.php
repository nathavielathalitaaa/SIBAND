<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\HeartRateController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::post('/heart-rate', [HeartRateController::class, 'store']);
    Route::get('/heart-rate', [HeartRateController::class, 'index']);
});
