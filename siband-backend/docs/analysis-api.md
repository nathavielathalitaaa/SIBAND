# Dokumentasi Endpoint Analisis (`GET /api/children/{child}/analysis`)

Endpoint ini menyediakan data analisis detak jantung (*heart rate*) dan catatan kejadian (*event notes*) anak untuk layar **Analisis** di aplikasi Siband. Endpoint ini bersifat baca-saja (*read-only*) dan dilindungi autentikasi `auth:sanctum`.

---

## 1. Endpoint & Parameter Query

```http
GET /api/children/{child}/analysis?from=<ISO8601>&to=<ISO8601>&tz=<IANA_Timezone>
Authorization: Bearer <token>
Accept: application/json
```

### Parameter Path
| Parameter | Tipe | Wajib | Keterangan |
| :--- | :---: | :---: | :--- |
| `child` | `integer` | Ya | ID anak milik pengguna yang sedang login. Jika milik pengguna lain atau tidak ditemukan, mengembalikan `404 Not Found`. |

### Parameter Query
| Parameter | Tipe | Wajib | Default | Keterangan |
| :--- | :---: | :---: | :--- | :--- |
| `tz` | `string` (IANA Timezone) | Tidak | `Asia/Jakarta` (`config('analysis.default_timezone')`) | Identifier zona waktu IANA (divalidasi terhadap `DateTimeZone::listIdentifiers()`, misalnya `Asia/Jakarta`, `Asia/Makassar`, `UTC`). Menentukan perhitungan awal hari default (`00:00`), pengelompokan jam lokal pada `patterns.hourly` dan `quality.per_hour`, serta offset seluruh timestamp pada respons JSON. |
| `from` | `string` (ISO 8601) | Tidak | Hari ini pukul `00:00:00` di `tz` | Waktu awal jendela analisis. Jika dikirim eksplisit dengan offset, nilainya dihormati dan dikonversi ke offset `tz`. |
| `to` | `string` (ISO 8601) | Tidak | Waktu sekarang (`now` di `tz`) | Waktu akhir jendela analisis. Jika dikirim eksplisit dengan offset, nilainya dihormati. Jika melebihi waktu sekarang, otomatis dibatasi (*clamped*) ke waktu sekarang. |

### Validasi Parameter & Rentang Waktu (`422 Unprocessable Entity`)
- `tz` bukan identifier zona waktu IANA yang valid menurut `DateTimeZone::listIdentifiers()`.
- Format `from` atau `to` tidak dapat di-parse sebagai tanggal/waktu valid.
- `to <= from`.
- Selisih `to - from` melebihi batas maksimal `config('analysis.max_span_days')` (default `7` hari).

---

## 2. Daftar Parameter Konfigurasi (`config/analysis.php`)

> **Catatan Penting:** Seluruh angka di bawah ini merupakan **nilai sementara** hasil pengamatan awal pada perangkat prototipe dan belum terbukti secara klinis maupun empiris.

| Kunci Konfigurasi | Nilai Default | Status | Keterangan |
| :--- | :---: | :---: | :--- |
| `default_timezone` | `'Asia/Jakarta'` | Konfigurasi | Zona waktu IANA default bila parameter query `tz` tidak dikirim. |
| `gap_min_seconds` | `150` | Nilai sementara | Selisih waktu antar sampel berurutan (detik) di atas nilai ini dikategorikan sebagai jeda sensor (`sensor_gaps`). |
| `stale_after_seconds` | `420` | Nilai sementara | Batas usia sampel terakhir (detik) sebelum status pengukuran dinyatakan `tidak_ada_data`. |
| `expected_rest_seconds` | `300` | Nilai sementara | Perkiraan durasi istirahat alami sensor jam (*duty-cycle* ~5 menit, pengamatan awal, belum terbukti). |
| `episode_margin_bpm` | `10` | Nilai sementara | Margin tambahan di atas `p75` baseline (`ambang = p75 + episode_margin_bpm`) untuk mendeteksi episode kenaikan BPM. |
| `episode_min_duration_seconds` | `120` | Nilai sementara | Durasi minimal (detik) deretan sampel di atas ambang agar dihitung sebagai satu episode. |
| `note_match_seconds` | `300` | Nilai sementara | Jendela waktu pencocokan catatan kejadian (`±300` detik dari awal episode). |
| `note_exclusion_minutes` | `10` | Nilai sementara | Durasi pembuangan sampel setelah catatan kejadian non-fisik (`suara_keras`, `meltdown`) dari perhitungan baseline (menit). |
| `physical_activity_exclusion_minutes` | `30` | Nilai sementara | Durasi pembuangan sampel setelah catatan `aktivitas_fisik` dari perhitungan baseline dan deteksi episode (menit). |
| `pattern_window_seconds` | `600` | Nilai sementara | Jendela waktu setelah catatan kejadian (`[at, at + 600s]`) untuk menghitung rata-rata kenaikan BPM per tipe catatan. |
| `min_notes_per_type` | `5` | Nilai sementara | Jumlah minimal catatan yang memiliki sampel pada jendela pola agar `enough` bernilai `true`. |
| `max_span_days` | `7` | Nilai sementara | Rentang waktu maksimal (hari) yang diizinkan untuk satu permintaan analisis. |
| `chart_max_points` | `1500` | Nilai sementara | Batas jumlah titik pada `series` sebelum dilakukan pereduksian (*downsampling*) menggunakan **median** per bucket waktu (`60` detik untuk rentang `<= 1` hari, `300` detik untuk `> 1` hari). |

Parameter `note_exclusion_minutes` (`10` menit) dan `physical_activity_exclusion_minutes` (`30` menit) merupakan keputusan sementara untuk menentukan jendela pembuangan sampel setelah waktu mulai catatan karena catatan kejadian hanya menyimpan jam mulai tanpa waktu selesai.

---

## 3. Contoh Respons JSON (`200 OK`)

```json
{
  "child": {
    "id": 1,
    "name": "Bima",
    "nickname": "Bima"
  },
  "window": {
    "from": "2026-11-06T00:00:00+07:00",
    "to": "2026-11-06T12:00:00+07:00",
    "timezone": "Asia/Jakarta"
  },
  "baseline": {
    "sufficient": true,
    "sample_count": 120,
    "min_samples": 100,
    "median": 80,
    "p25": 70,
    "p75": 90
  },
  "current": {
    "bpm": 84,
    "recorded_at": "2026-11-06T11:59:00+07:00",
    "age_seconds": 60,
    "status": "dalam_rentang",
    "measurement_state": "mengukur",
    "expected_rest_seconds": 300
  },
  "series": [
    {
      "t": "2026-11-06T09:00:00+07:00",
      "bpm": 82
    },
    {
      "t": "2026-11-06T09:01:00+07:00",
      "bpm": 105
    },
    {
      "t": "2026-11-06T09:02:00+07:00",
      "bpm": 125
    },
    {
      "t": "2026-11-06T09:04:00+07:00",
      "bpm": 112
    }
  ],
  "resolution_seconds": 0,
  "sensor_gaps": [
    {
      "from": "2026-11-06T09:04:00+07:00",
      "to": "2026-11-06T09:10:00+07:00",
      "duration_seconds": 360
    }
  ],
  "notes": [
    {
      "id": 10,
      "type": "suara_keras",
      "at": "2026-11-06T09:00:30+07:00",
      "text_preview": "Suara petir di dekat rumah"
    }
  ],
  "episodes": [
    {
      "index": 1,
      "start": "2026-11-06T09:01:00+07:00",
      "end": "2026-11-06T09:04:00+07:00",
      "duration_seconds": 180,
      "peak_bpm": 125,
      "delta_from_median": 45,
      "has_sensor_gap": false,
      "note": {
        "id": 10,
        "type": "suara_keras",
        "at": "2026-11-06T09:00:30+07:00",
        "text_preview": "Suara petir di dekat rumah"
      }
    }
  ],
  "patterns": {
    "sufficient": true,
    "hourly": [
      { "hour": 0, "episode_count": 0 },
      { "hour": 1, "episode_count": 0 },
      { "hour": 2, "episode_count": 0 },
      { "hour": 3, "episode_count": 0 },
      { "hour": 4, "episode_count": 0 },
      { "hour": 5, "episode_count": 0 },
      { "hour": 6, "episode_count": 0 },
      { "hour": 7, "episode_count": 0 },
      { "hour": 8, "episode_count": 0 },
      { "hour": 9, "episode_count": 1 },
      { "hour": 10, "episode_count": 0 },
      { "hour": 11, "episode_count": 0 },
      { "hour": 12, "episode_count": 0 },
      { "hour": 13, "episode_count": 0 },
      { "hour": 14, "episode_count": 0 },
      { "hour": 15, "episode_count": 0 },
      { "hour": 16, "episode_count": 0 },
      { "hour": 17, "episode_count": 0 },
      { "hour": 18, "episode_count": 0 },
      { "hour": 19, "episode_count": 0 },
      { "hour": 20, "episode_count": 0 },
      { "hour": 21, "episode_count": 0 },
      { "hour": 22, "episode_count": 0 },
      { "hour": 23, "episode_count": 0 }
    ],
    "by_note_type": [
      {
        "type": "transisi",
        "avg_rise_bpm": null,
        "notes_used": 0,
        "notes_total": 0,
        "enough": false
      },
      {
        "type": "suara_keras",
        "avg_rise_bpm": 45,
        "notes_used": 1,
        "notes_total": 1,
        "enough": false
      }
    ]
  },
  "quality": {
    "window_seconds": 43200,
    "measured_seconds": 180,
    "coverage_percent": 0.4,
    "sample_count": 4,
    "gap_count": 1,
    "gap_total_seconds": 360,
    "per_hour": [
      { "hour": 0, "coverage_percent": 0 },
      { "hour": 9, "coverage_percent": 5 }
    ]
  },
  "meta": {
    "parameters": {
      "default_timezone": "Asia/Jakarta",
      "gap_min_seconds": 150,
      "stale_after_seconds": 420,
      "expected_rest_seconds": 300,
      "episode_margin_bpm": 10,
      "episode_min_duration_seconds": 120,
      "note_match_seconds": 300,
      "pattern_window_seconds": 600,
      "min_notes_per_type": 5,
      "max_span_days": 7,
      "chart_max_points": 1500
    },
    "limitations": [
      "Jam beristirahat di antara rangkaian pengukuran sehingga kejadian singkat bisa terlewat.",
      "Detak jantung saja tidak menunjukkan penyebab; konteks dari catatan kejadian.",
      "Bukan alat diagnosis."
    ]
  }
}
```

---

## 4. Data Demo Lokal (`siband:demo-analysis`)

Untuk pengujian tampilan pada lingkungan lokal/pengembangan (ditolak otomatis pada `production`), jalankan `php artisan siband:demo-analysis {child_id} [--date=YYYY-MM-DD] [--rest-minutes=5]` guna mengisi sampel detak jantung (`device_name='DEMO'`) beserta catatan kejadian (`[DEMO] ...`) pukul 06:00–14:00 WIB, atau tambahkan opsi `--purge` (`php artisan siband:demo-analysis {child_id} --purge`) untuk menghapus khusus data DEMO milik anak tersebut tanpa menyentuh data asli. **Peringatan:** Seluruh data yang dihasilkan oleh perintah ini adalah **data tiruan (sintetis)** semata untuk simulasi antarmuka, **bukan hasil pengukuran perangkat maupun subjek nyata**, serta **tidak boleh dikutip atau disajikan sebagai hasil pengujian/penelitian**.
