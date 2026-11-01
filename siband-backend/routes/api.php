<?php

use App\Http\Controllers\EventNoteController;
use App\Http\Controllers\Api\ChildController;
use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\HeartRateController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BaselineController;
use App\Http\Controllers\Api\RecapController;
use App\Http\Controllers\Api\ShareLinkController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// Public share link endpoint (throttled, no auth)
Route::get('/share/{token}', [ShareLinkController::class, 'showPublic'])->middleware('throttle:20,1');

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::post('/heart-rate', [HeartRateController::class, 'store']);
    Route::post('/devices/pair', [DeviceController::class, 'pair']);
    Route::get('/heart-rate', [HeartRateController::class, 'index']);
    Route::apiResource('children', ChildController::class);
    Route::get('/children/{child}/baseline', [BaselineController::class, 'index']);
    // Event notes routes
    Route::get('/children/{child}/event-notes', [EventNoteController::class, 'index']);
    Route::post('/children/{child}/event-notes', [EventNoteController::class, 'store']);
    Route::delete('/event-notes/{id}', [EventNoteController::class, 'destroy']);

    // Share links routes
    Route::post('/children/{child}/share-links', [ShareLinkController::class, 'store']);
    Route::get('/children/{child}/share-links', [ShareLinkController::class, 'index']);
    Route::delete('/share-links/{id}', [ShareLinkController::class, 'destroy']);

    // Monthly recap route
    Route::get('/children/{child}/recap', [RecapController::class, 'show']);
});
