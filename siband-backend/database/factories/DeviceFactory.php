<?php

/** @var \Illuminate\Database\Eloquent\Factory\Factory $factory */

use App\Models\Device;
use App\Models\Child;
use Faker\Generator as Faker;

$factory->define(Device::class, function (Faker $faker) {
    return [
        'child_id' => Child::factory(),
        'name' => $faker->word . ' Watch',
        'mac' => strtoupper(implode(':', str_split($faker->hexcolor, 2))),
        'last_seen_at' => now(),
    ];
});
