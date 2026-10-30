<?php

namespace Database\Factories;

use App\Models\Child;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends \Illuminate\Database\Eloquent\Factories\Factory<Child> */
class ChildFactory extends Factory
{
    protected $model = Child::class;

    public function definition()
    {
        return [
            'user_id' => User::factory(),
            'nickname' => $this->faker->firstName,
            'birth_year' => $this->faker->numberBetween(2010, 2022),
        ];
    }
}
