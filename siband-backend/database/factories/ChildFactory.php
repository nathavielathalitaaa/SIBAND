<?php

/** @var \Illuminate\Database\Eloquent\Factory\Factory $factory */

use App\Models\Child;
use App\Models\User;
use Faker\Generator as Faker;

$factory->define(Child::class, function (Faker $faker) {
    return [
        'user_id' => User::factory(),
        'nickname' => $faker->firstName,
        'birth_year' => $faker->numberBetween(2010, 2022),
    ];
});
