<?php

namespace Database\Factories;

use App\Models\EventNote;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<EventNote>
 */
class EventNoteFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'child_id' => \App\Models\Child::factory(),
            'type' => $this->faker->randomElement(['transisi', 'suara_keras', 'meltdown', 'aktivitas_fisik', 'lainnya']),
            'note' => $this->faker->optional()->sentence(),
            'occurred_at' => $this->faker->dateTimeBetween('-1 month', 'now'),
        ];
    }
}
