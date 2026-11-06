# SIBAND

> **Siband** adalah platform pemantauan denyut jantung (*Heart Rate*) dan manajemen kesehatan/stres anak secara *real-time* berbasis IoT Smartband (**Infinix XWatch H4**), aplikasi mobile **Flutter**, dan backend API **Laravel**.

---

## 📌 Context & Project Overview

* **Tujuan Proyek**: Pengolahan data sensorik denyut jantung (BPM) dari smartband fisik ke aplikasi mobile Flutter dan sinkronisasi ke backend server untuk analisis data riwayat.
* **Asal-usul**: Pengembangan lanjutan dari proposal proyek lomba CalmiBand yang kini diimplementasikan sebagai proyek aplikasi akhir semester/kenaikan kelas.
* **Nama Repository/Folder**: `SIBAND` (folder `siband`). *Penamaan folder dipertahankan untuk kompatibilitas struktur.*

---

## 🏗️ Architecture Overview

Sistem terdiri dari 3 lapisan utama:

```
┌─────────────────────────┐          BLE (GATT 0x180D / 0xFEEA)         ┌─────────────────────────┐
│                         │ ──────────────────────────────────────────> │                         │
│  Infinix XWatch H4      │                                             │   Flutter Mobile App    │
│  (Smartwatch Sensor)    │ <────────────────────────────────────────── │   (CalmiBand Client)    │
└─────────────────────────┘      Write Payload [0xFE, 0xEA, ...]        └────────────┬────────────┘
                                                                                     │
                                                                       ADB Reverse (TCP 8000)
                                                                       HTTP REST API (POST/GET)
                                                                                     │
                                                                                     ▼
                                                                        ┌─────────────────────────┐
                                                                        │   Laravel 13 REST API   │
                                                                        │   (siband-backend)      │
                                                                        │   MySQL Database        │
                                                                        └─────────────────────────┘
```

### 1. Hardware & BLE Protocol Layer (`Infinix XWatch H4`)
* **Standard GATT Service**: `0x180D` (Heart Rate Service).
* **Standard GATT Characteristic**: `0x2A37` (Heart Rate Measurement). Notifikasi dikirimkan dalam format standar Bluetooth SIG (Flags byte + Uint8/Uint16 BPM).
* **Custom GATT Service (Trigger Command)**: Service `0xFEEA`.
  - **Dynamic Resolution**: Menggunakan pencarian properti (`writeWithoutResponse` & `notify`), bukan hardcode UUID yang ambigu (`FEE1` vs `FEE2`).
  - **Trigger Payload (Start Continuous Measurement)**:
    `[0xFE, 0xEA, 0x20, 0x08, 0xB9, 0x09, 0x01, 0x01]`
  - **Stop Payload (Stop Measurement)**:
    `[0xFE, 0xEA, 0x20, 0x07, 0xB9, 0x10, 0x00]`

> ⚠️ **IMPORTANT HARDWARE BEHAVIOR (PERHATIAN PENTING UNTUK AI & DEVELOPER)**:
> Sensor Heart Rate pada Infinix XWatch H4 memiliki pola **duty-cycle alami dari firmware jam**:
> - Jam akan membaca data BPM selama **~10-15 kali pembacaan kontinyu**, lalu berhenti sejenak (**~5 menit pause/resting**), kemudian otomatis melanjutkan membaca lagi.
> - **INI BUKAN BUG ATAU KONEKSI PUTUS!** Jangan pernah menganggap ini error dan **jangan mencoba menambalnya dengan re-trigger periodik**, karena itu adalah mekanisme hemat daya alami dari firmware Infinix.

---

### 2. Mobile Client Layer (`Flutter`)
Ditempatkan di folder utama `lib/`:
* [`lib/services/ble_service.dart`](lib/services/ble_service.dart):
  - Mengelola koneksi BLE via `flutter_blue_plus`.
  - Memiliki fungsi `getBondedDevices()` untuk mengambil perangkat terpasang (*paired*).
  - Memiliki fungsi `triggerContinuousHrMeasurement()` dan `stopHrMeasurement()`.
  - Melakukan parsing byte data `0x2A37` secara presisi (`_parseHeartRate`).
  - Hanya menggunakan **single subscription** pada `onValueReceived` untuk mencegah log ganda.
* [`lib/screens/bpm_dashboard_screen.dart`](lib/screens/bpm_dashboard_screen.dart):
  - Layar utama monitoring.
  - Memiliki mode switcher: **Mode Dummy** (simulasi) & **Mode BLE Asli** (XWatch H4).
  - Mengelola 3 status sensor (`HrSensorStatus`):
    - 🟢 `measuring` (`Mengukur...`): Data BPM masuk secara aktif.
    - 🟠 `resting` (`Sensor istirahat sejenak (normal)`): Tidak ada data baru >6 detik (durasi jeda duty-cycle jam).
    - 🔴 `disconnected` (`Terputus dari device`): Koneksi BLE terputus.
  - Merender UI secara real-time via `setState()` (Teks BPM 72pt + `fl_chart` LineChart).
* [`lib/services/api_service.dart`](lib/services/api_service.dart):
  - Client HTTP REST API untuk berinteraksi dengan backend.

---

### 3. Backend Layer (`Laravel 13 REST API`)
Ditempatkan di folder `siband-backend/`:
* **Database**: SQLite (`database/database.sqlite`).
* **Model Main**: `App\Models\HeartRateLog` (tabel `heart_rate_logs`).
* **Controller**: `App\Http\Controllers\Api\HeartRateController`.
* **API Endpoints**:
  - `POST /api/heart-rate`: Menyimpan log BPM dari Flutter (`bpm`, `device_name`, `device_mac`).
  - `GET /api/heart-rate`: Mengambil daftar riwayat BPM untuk chart dashboard.
* **Koneksi HP Fisik ke Server Lokal**:
  Menggunakan `adb reverse tcp:8000 tcp:8000` sehingga HP fisik mengakses `http://127.0.0.1:8000/api` yang diteruskan ke server host `php artisan serve --host=0.0.0.0 --port=8000`.

---

## 📊 Feature Progress Status

| Fitur / Komponen | Status | Keterangan |
| :--- | :---: | :--- |
| **Welcome / Login / Register** | ✅ Selesai | Layar awal, autentikasi masuk, dan pendaftaran akun orang tua. |
| **Autentikasi** | ✅ Selesai | Manajemen sesi auth & token berbasis Laravel Sanctum. |
| **Profil Anak** | ✅ Selesai | Kelola data profil anak, tambah, edit, dan switch profil aktif. |
| **Pairing Jam (Backend + Layar Flutter)** | ✅ Selesai | Pencarian BLE, pemilihan perangkat terikat, sinkron MAC ke backend. |
| **Baseline** | ✅ Selesai | Perhitungan nilai dasar BPM (median, p25, p75) berbasis riwayat bacaan. |
| **Catatan Kejadian** | ✅ Selesai | Pencatatan kejadian/pemicu dengan tipe terstandar dan catatan detail. |
| **Rekap Bulanan** | ✅ Selesai | Ringkasan agregasi bulanan, rata-rata, maksimum BPM, dan grafik harian. |
| **Tautan Terapis (Backend + Halaman Web)** | ✅ Selesai | Pembuatan token share link dan web statis `share.html` baca-saja. |
| **Panduan** | ✅ Selesai (konten statis) | Layar panduan relaksasi, tips penanganan, dan edukasi terapis. |
| **Profil, Jurnal & privasi, dan Bantuan** | ✅ Selesai | Kartu profil anak aktif, edit profil, informasi pendamping, jurnal kejadian, privasi, dan bantuan. |
| **Tab GPS** | 🟡 Tampilan contoh (tanpa data lokasi nyata, di luar cakupan) | Tampilan statis mode contoh tanpa pembacaan GPS maupun pemanggilan backend. |
| **Alert / Notifikasi** | ⏳ Belum | Sistem peringatan dini saat BPM melewati ambang batas tertentu. |
| **Sinkron Riwayat dari Jam** | ⏳ Belum | Penarikan data riwayat offline/buffer internal smartwatch. |
| **Uji BLE di HP** | ⏳ Belum | Pengujian komprehensif end-to-end langsung pada perangkat fisik. |

---

## 🌐 Pengecualian Aturan UI

Satu-satunya halaman web di sisi server adalah `siband-backend/public/share.html`, halaman statis baca-saja untuk terapis (tanpa Blade, tanpa framework) yang memanggil `GET /api/share/{token}`. Semua UI aplikasi tetap 100% Flutter; Laravel tetap Headless REST API.

---

## ⚠️ Kendala Teknis & Karakteristik Hardware

* **Jeda Sensor Alami (Duty-Cycle ±5 Menit)**:
  Sensor Heart Rate pada Infinix XWatch H4 memiliki pola hemat daya alami dari firmware pabrik: jam membaca BPM selama ~10-15 kali pembacaan kontinyu, lalu istirahat sejenak (**pause/resting ~5 menit**), kemudian melanjutkan membaca kembali secara otomatis.
  > ⚠️ **PENTING**: Ini adalah perilaku normal bawaan firmware smartwatch, bukan koneksi putus atau error. Dilarang menambahkan timer re-trigger periodik.
* **Koneksi Jaringan Lokal HP Fisik**:
  Saat pengujian pada HP fisik melalui kabel data USB, koneksi API membutuhkan port forwarding `adb reverse tcp:8000 tcp:8000` agar `http://127.0.0.1:8000/api` dapat menjangkau server Laravel di komputer host.

---

## 🚀 Local Development Setup Guide

### Prasyarat:
1. Flutter SDK (`>=3.0.0`)
2. PHP (`>=8.2`) & Composer
3. Android Phone dengan USB Debugging aktif
4. Smartwatch Infinix XWatch H4 (telah di-pair di Bluetooth HP)

### Langkah-langkah Menjalankan Proyek:

#### 1. Menjalankan Backend Laravel
```bash
cd siband-backend
php artisan serve --host=0.0.0.0 --port=8000
```

#### 2. Konfigurasi Port Forwarding USB ADB (Wajib untuk HP Fisik)
Di terminal laptop/PC:
```bash
adb reverse tcp:8000 tcp:8000
```

#### 3. Menjalankan Flutter App
Di folder root proyek:
```bash
flutter pub get
flutter run
```

#### 4. Menjalankan Analisis Kode Static
```bash
flutter analyze
```
*(Harus selalu 0 errors dan 0 warnings).*

---

## 🤖 Guidelines for AI Assistants & Developers

Jika Anda adalah **AI Agent** atau **Developer baru** yang melanjutkan proyek ini, ikuti aturan ketat berikut:

1. **JANGAN UBAH LOGIK TRIGGER BLE**:
   Jangan mengubah payload atau alur pemanggilan `triggerContinuousHrMeasurement()` dan `stopHrMeasurement()` di [`lib/services/ble_service.dart`](lib/services/ble_service.dart).
2. **JANGAN COBA MEMPERBAIKI PAUSE ~5 MENIT JAM**:
   Pause setelah ~10x bacaan BPM adalah perilaku duty-cycle alami dari firmware Infinix XWatch H4. **Jangan menambah timer re-trigger periodik** untuk memaksa jam membaca terus-menerus.
3. **STRATEGI REALTIME**:
   Proyek ini menggunakan **REST API (POST & GET)** dengan polling/pull-to-refresh. Jangan mencoba mengimplementasikan Server-Sent Events (SSE) atau WebSocket kecuali diminta secara eksplisit.
4. **PEMISAHAN UI (DART/FLUTTER) VS BACKEND (LARAVEL REST API)**:
   - **UI 100% Flutter (Dart)**: Seluruh tampilan antarmuka (Dashboard, Grafik, Device Picker Modal, Status Sensor, Form Auth/Profil, Rekap, Panduan) **WAJIB HANYA** dibuat di Flutter menggunakan bahasa **Dart** (`lib/`).
   - **Laravel 100% Headless REST API (PHP)**: Laravel (`siband-backend/`) **HANYA** berfungsi sebagai Headless REST API yang mengembalikan response JSON dan mengelola database SQLite. Dilarang membuat template Blade di Laravel untuk kebutuhan aplikasi mobile ini.
   - **Pengecualian aturan UI**: Satu-satunya halaman web di sisi server adalah `siband-backend/public/share.html`, halaman statis baca-saja untuk terapis (tanpa Blade, tanpa framework) yang memanggil `GET /api/share/{token}`. Semua UI aplikasi tetap 100% Flutter; Laravel tetap Headless REST API.
5. **PEMELIHARAAN KODE**:
   Pastikan setiap kali melakukan perubahan, jalankan `flutter analyze` dan pastikan hasil analisis tetap **No issues found! (0 errors, 0 warnings)**.

