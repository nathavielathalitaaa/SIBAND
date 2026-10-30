<?php

use App\Http\Controllers\EventNoteController;
use App\Http\Controllers\Api\ChildController;
use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\HeartRateController;
use App\Http\Controllers\Api\AuthController;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::post('/heart-rate', [HeartRateController::class, 'store']);
    Route::get('/heart-rate', [HeartRateController::class, 'index']);
    Route::apiResource('children', \App\Http\Controllers\Api\ChildController::class);
    Route::post('/devices/pair', [App\Http\Controllers\Api\DeviceController::class, 'pair']);
    // Event notes routes
    Route::get('/children/{child}/event-notes', [EventNoteController::class, 'index']);
    Route::post('/children/{child}/event-notes', [EventNoteController::class, 'store']);
    Route::delete('/event-notes/{id}', [EventNoteController::class, 'destroy']);
    });
