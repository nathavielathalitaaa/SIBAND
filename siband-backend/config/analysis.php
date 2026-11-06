<?php

return [
    // Timezone default untuk jendela analisis dan pengelompokan jam lokal (IANA timezone)
    'default_timezone' => 'Asia/Jakarta',

    // Nilai sementara (pengamatan awal, belum terbukti secara klinis/empiris):

    // Selisih antar sampel di atas nilai ini dianggap jeda sensor (detik)
    'gap_min_seconds' => 150,

    // Tanpa data lebih lama dari nilai ini dianggap tidak_ada_data (detik)
    'stale_after_seconds' => 420,

    // Pengamatan awal, belum terbukti (perkiraan jeda istirahat sensor jam dalam detik)
    'expected_rest_seconds' => 300,

    // Margin di atas p75 baseline untuk mendeteksi episode kenaikan (BPM)
    'episode_margin_bpm' => 10,

    // Durasi minimal episode kenaikan agar dihitung (detik)
    'episode_min_duration_seconds' => 120,

    // Jendela pencocokan catatan kejadian terhadap waktu mulai episode (+- detik)
    'note_match_seconds' => 300,

    // Keputusan sementara, catatan kejadian hanya punya jam mulai
    'note_exclusion_minutes' => 10,
    'physical_activity_exclusion_minutes' => 30,

    // Jendela pengamatan pola kenaikan BPM setelah waktu catatan kejadian (detik)
    'pattern_window_seconds' => 600,

    // Jumlah minimal catatan terpakai per tipe agar pola dianggap cukup
    'min_notes_per_type' => 5,

    // Rentang waktu analisis maksimal yang diizinkan (hari)
    'max_span_days' => 7,

    // Jumlah titik maksimal pada series grafik sebelum dilakukan downsampling median per bucket
    'chart_max_points' => 1500,
];
