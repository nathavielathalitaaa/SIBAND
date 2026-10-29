<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Models\Child;

class ChildController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        $user = Auth::user();
        $children = Child::where('user_id', $user->id)->get();
        return response()->json($children);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $request->validate([
            'nickname' => 'required|string',
            'birth_year' => 'required|integer',
        ]);
        $user = Auth::user();
        $child = Child::create([
            'user_id' => $user->id,
            'nickname' => $request->input('nickname'),
            'birth_year' => $request->input('birth_year'),
        ]);
        return response()->json($child, 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        $user = Auth::user();
        $child = Child::where('id', $id)->where('user_id', $user->id)->firstOrFail();
        return response()->json($child);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        $user = Auth::user();
        $child = Child::where('id', $id)->where('user_id', $user->id)->firstOrFail();
        $request->validate([
            'nickname' => 'sometimes|required|string',
            'birth_year' => 'sometimes|required|integer',
        ]);
        $child->update($request->only(['nickname', 'birth_year']));
        return response()->json($child);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        $user = Auth::user();
        $child = Child::where('id', $id)->where('user_id', $user->id)->firstOrFail();
        $child->delete();
        return response()->json(['message' => 'Deleted']);
    }
}
