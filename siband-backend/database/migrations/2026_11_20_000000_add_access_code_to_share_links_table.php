<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('share_links', function (Blueprint $table) {
            $table->string('short_code', 12)->nullable()->unique()->after('token_hash');
            $table->string('pin_hash', 255)->nullable()->after('short_code');
        });
    }

    public function down(): void
    {
        Schema::table('share_links', function (Blueprint $table) {
            $table->dropUnique(['short_code']);
            $table->dropColumn(['short_code', 'pin_hash']);
        });
    }
};
