<?php

namespace Database\Factories;

use App\Models\Device;
use App\Models\Child;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Device> */
class DeviceFactory extends Factory
{
    protected $model = Device::class;

    public function definition()
    {
        return [
            'child_id' => Child::factory(),
            'name' => $this->faker->word . ' Watch',
            'mac' => strtoupper(implode(':', str_split($this->faker->hexcolor, 2))),
            'last_seen_at' => now(),
        ];
    }
}
