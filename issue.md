# [FEATURE] Dashboard Utama & Pencatatan Transaksi Pengeluaran (Multi-Currency & GL Account Integration)

---

## 📌 PANDUAN UNTUK DEVELOPER / AI AGENT
> **PENTING DIBACA SEBELUM CODING:**
> 1. Ikuti spesifikasi teknis dan struktur file yang telah ditentukan di bawah secara ketat.
> 2. Semua perhitungan uang **DILARANG** menggunakan tipe `float` / `double`. Gunakan `Decimal` (Python) dan format angka presisi di database (`NUMERIC(15, 2)`).
> 3. Halaman Dashboard adalah **Protected Route** (hanya bisa diakses jika user sudah login dan memiliki token valid).
> 4. Jangan hardcode data kurs, akun GL, atau metode pembayaran di frontend; semua wajib diambil dari endpoint API yang disediakan.
> 5. Selesaikan tugas secara modular: **Database Migrations & Seed -> Backend Endpoints -> Frontend Bloc & UI**.

---

## 1. Ringkasan Fitur (Feature Overview)
Fitur ini mencakup dua komponen utama:
1. **Halaman Dashboard Utama:** Menampilkan ringkasan keuangan pengguna (Total Pemasukan, Total Pengeluaran, dan Untung/Rugi) berdasarkan filter rentang waktu: **Lifetime** atau **Periodik** (Bulanan, Mingguan, Harian).
2. **Form Transaksi Pengeluaran & Akuntansi GL:** Halaman/modal untuk mencatat pengeluaran uang dengan kalkulasi multi-mata uang otomatis (*currency conversion*) berdasarkan kurs saat transaksi, pemilihan metode pembayaran resmi dari database yang terikat dengan Akun Buku Besar (*GL Account / Master Account*).

---

## 2. Kebutuhan Database & Relasi (PostgreSQL / SQLAlchemy)

Buat model dan migrasi untuk tabel-tabel berikut di backend (`backend/app/models/`):

### A. Tabel `MST_Account` (Master GL Account)
Tabel master buku besar (*General Ledger Account*) yang akan digunakan untuk mengklasifikasikan dan mencatat asal/tujuan dana transaksi.
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `Account` | `VARCHAR(10)` | **Primary Key**, Kode Akun Unik (misal: `'1001'`, `'1002'`), Not Null |
| `Description` | `VARCHAR(255)` | Nama / Deskripsi Akun (misal: `'Kas Tunai'`, `'Rekening Bank'`), Not Null |
| `Type` | `VARCHAR(10)` | Enum: `'Debit'` atau `'Credit'`, Not Null |
| `Dimensi1` | `VARCHAR(10)` | Nullable, Foreign Key refer ke `MST_Account.Account` (Self-referencing) |
| `Dimensi2` | `VARCHAR(10)` | Nullable, Foreign Key refer ke `MST_Account.Account` (Self-referencing) |
| `Dimensi3` | `VARCHAR(10)` | Nullable, Foreign Key refer ke `MST_Account.Account` (Self-referencing) |
| `Dimensi4` | `VARCHAR(10)` | Nullable, Foreign Key refer ke `MST_Account.Account` (Self-referencing) |
| `Active` | `BOOLEAN` | Default `true`, Not Null |
| `Created_At` | `TIMESTAMPTZ` | Default `NOW()` in UTC, Not Null |
| `created_by` | `UUID` | Foreign Key refer ke `users.id` (User yang membuat data akun) |

### B. Tabel `currencies`
Menyimpan daftar mata uang yang didukung sistem.
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `code` | `VARCHAR(3)` | Primary Key (misal: `'IDR'`, `'USD'`, `'EUR'`, `'SGD'`) |
| `name` | `VARCHAR(50)` | Nama mata uang (misal: `'Indonesian Rupiah'`) |
| `symbol` | `VARCHAR(5)` | Simbol (misal: `'Rp'`, `'$'`, `'€'`) |
| `is_active` | `BOOLEAN` | Default `true` |

### C. Tabel `currency_rates`
Menyimpan riwayat nilai tukar mata uang terhadap mata uang dasar lainnya.
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `id` | `UUID` | Primary Key, default `gen_random_uuid()` |
| `from_currency` | `VARCHAR(3)` | Foreign Key -> `currencies.code` |
| `to_currency` | `VARCHAR(3)` | Foreign Key -> `currencies.code` |
| `rate` | `NUMERIC(18, 6)` | Nilai kurs (misal: `1 USD = 15800.000000 IDR`) |
| `valid_from` | `TIMESTAMPTZ` | Mulai berlaku, default `NOW()` |
| `valid_to` | `TIMESTAMPTZ` | Nullable (null berarti kurs aktif saat ini) |

### D. Tabel `payment_methods`
Menyimpan opsi metode pembayaran yang tersedia dan terikat dengan akun GL asal (*FromAccount*).
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `id` | `UUID` | Primary Key, default `gen_random_uuid()` |
| `code` | `VARCHAR(30)` | Unique (misal: `'CASH'`, `'BANK_TRANSFER'`, `'E_WALLET'`, `'CREDIT_CARD'`) |
| `name` | `VARCHAR(50)` | Nama tampilan (misal: `'Tunai'`, `'Transfer Bank'`, `'E-Wallet'`) |
| `FromAccount` | `VARCHAR(10)` | **Foreign Key -> `MST_Account.Account`**, Not Null (Akun GL sumber dana metode pembayaran ini) |
| `is_active` | `BOOLEAN` | Default `true` |

### E. Tabel `transactions`
Menyimpan data transaksi keuangan.
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `id` | `UUID` | Primary Key, default `gen_random_uuid()` |
| `user_id` | `UUID` | Foreign Key -> `users.id` (Indexed, Cascade Delete) |
| `type` | `VARCHAR(10)` | Enum: `'EXPENSE'` atau `'INCOME'` |
| `currency_code` | `VARCHAR(3)` | Foreign Key -> `currencies.code` |
| `amount` | `NUMERIC(15, 2)` | Nominal asli yang diinput user |
| `exchange_rate` | `NUMERIC(18, 6)` | Kurs saat transaksi terjadi (terhadap `user.base_currency`) |
| `amount_in_base_currency`| `NUMERIC(15, 2)` | Hasil kali: `amount * exchange_rate` |
| `payment_method_id` | `UUID` | Foreign Key -> `payment_methods.id` |
| `notes` | `TEXT` | Keterangan bebas / catatan transaksi (Nullable) |
| `transaction_date` | `TIMESTAMPTZ` | Waktu transaksi (Default `NOW()`) |
| `created_at` | `TIMESTAMPTZ` | Default `NOW()` |
| `updated_at` | `TIMESTAMPTZ` | Default `NOW()` |

> **Seed Data Wajib:**
> Buat skrip migrasi/seed untuk mengisi nilai awal dengan urutan dependency yang benar:
> 1. `currencies`:
>    - `IDR` (Indonesian Rupiah, Symbol: `Rp`)
>    - `USD` (US Dollar, Symbol: `$`)
>    - `EUR` (Euro, Symbol: `€`)
>    - `SGD` (Singapore Dollar, Symbol: `S$`)
> 2. `currency_rates`:
>    - `USD` -> `IDR`: 15800.000000
>    - `EUR` -> `IDR`: 17000.000000
>    - `SGD` -> `IDR`: 11800.000000
>    - `IDR` -> `IDR`: 1.000000
> 3. `MST_Account`:
>    - `Account`: `'1001'`, `Description`: `'Kas Utama'`, `Type`: `'Debit'`
>    - `Account`: `'1002'`, `Description`: `'Bank Operasional'`, `Type`: `'Debit'`
>    - `Account`: `'1003'`, `Description`: `'Saldo E-Wallet'`, `Type`: `'Debit'`
>    - `Account`: `'2001'`, `Description`: `'Hutang Kartu Kredit'`, `Type`: `'Credit'`
> 4. `payment_methods`:
>    - Code: `'CASH'`, Name: `'Tunai'`, `FromAccount`: `'1001'`
>    - Code: `'BANK_TRANSFER'`, Name: `'Transfer Bank'`, `FromAccount`: `'1002'`
>    - Code: `'E_WALLET'`, Name: `'E-Wallet'`, `FromAccount`: `'1003'`
>    - Code: `'CREDIT_CARD'`, Name: `'Kartu Kredit'`, `FromAccount`: `'2001'`

---

## 3. Spesifikasi API Backend (FastAPI)

Semua endpoint berikut harus diletakkan di bawah router `/api/v1/` dan membutuhkan Header `Authorization: Bearer <access_token>`.

### 1. `GET /api/v1/dashboard/summary`
Mengambil kalkulasi ringkasan keuangan user dalam mata uang utama user (`base_currency`).
* **Query Parameters:**
  - `timeframe`: `lifetime` | `monthly` | `weekly` | `daily` (Wajib, default: `monthly`)
  - `reference_date`: ISO 8601 Date string (Opsional, default tanggal hari ini UTC)
* **Logika Perhitungan:**
  - Filter `transactions` milik `current_user.id`.
  - Jika `timeframe == 'lifetime'`, ambil semua transaksi.
  - Jika `monthly`, filter transaksi dalam bulan & tahun yang sama.
  - Jika `weekly`, filter transaksi dalam minggu berjalan (Senin - Minggu).
  - Jika `daily`, filter transaksi pada tanggal yang sama.
  - `total_income` = `SUM(amount_in_base_currency)` di mana `type == 'INCOME'`.
  - `total_expense` = `SUM(amount_in_base_currency)` di mana `type == 'EXPENSE'`.
  - `net_profit_loss` = `total_income - total_expense`.
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "base_currency": "IDR",
    "timeframe": "monthly",
    "period_start": "2026-09-01T00:00:00Z",
    "period_end": "2026-09-30T23:59:59Z",
    "total_income": 15000000.00,
    "total_expense": 4500000.00,
    "net_profit_loss": 10500000.00,
    "total_transactions": 24
  }
}
```

### 2. `GET /api/v1/currencies`
Mengambil daftar mata uang yang aktif untuk pilihan dropdown.
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {"code": "IDR", "name": "Indonesian Rupiah", "symbol": "Rp"},
    {"code": "USD", "name": "US Dollar", "symbol": "$"}
  ]
}
```

### 3. `GET /api/v1/payment-methods`
Mengambil daftar metode pembayaran yang tersedia beserta referensi `FromAccount`.
* **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "code": "CASH",
      "name": "Tunai",
      "from_account": "1001",
      "account_description": "Kas Utama"
    },
    {
      "id": "9a1b6679-7425-40de-944b-e07fc1f90ae8",
      "code": "BANK_TRANSFER",
      "name": "Transfer Bank",
      "from_account": "1002",
      "account_description": "Bank Operasional"
    }
  ]
}
```

### 4. `GET /api/v1/currency-rates/latest`
Mengambil rate kurs terbaru antara dua mata uang.
* **Query Parameters:** `from_currency=USD&to_currency=IDR`
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "from_currency": "USD",
    "to_currency": "IDR",
    "rate": 15800.000000,
    "updated_at": "2026-09-14T00:00:00Z"
  }
}
```

### 5. `POST /api/v1/transactions`
Mencatat transaksi pengeluaran baru.
* **Request Body:**
```json
{
  "type": "EXPENSE",
  "currency_code": "USD",
  "amount": 25.50,
  "payment_method_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "notes": "Langganan Cloud Server bulanan",
  "transaction_date": "2026-09-14T10:00:00Z"
}
```
* **Aturan Bisnis Backend:**
  1. Validasi `currency_code` dan `payment_method_id` ada di database.
  2. Cari kurs aktif dari `currency_code` ke `user.base_currency`. Jika sama, kurs = 1.0.
  3. Hitung `amount_in_base_currency = amount * exchange_rate`.
  4. Simpan transaksi ke tabel `transactions`.
* **Response (201 Created):**
```json
{
  "success": true,
  "message": "Transaksi pengeluaran berhasil disimpan.",
  "data": {
    "id": "e4eaaaf2-7642-11ed-a1eb-0242ac120002",
    "type": "EXPENSE",
    "currency_code": "USD",
    "amount": 25.50,
    "exchange_rate": 15800.000000,
    "amount_in_base_currency": 402900.00,
    "payment_method": {
      "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "name": "Tunai",
      "from_account": "1001"
    },
    "notes": "Langganan Cloud Server bulanan",
    "transaction_date": "2026-09-14T10:00:00Z"
  }
}
```

---

## 4. Spesifikasi Frontend (Flutter)

Implementasikan pada folder `frontend/lib/features/`:
- `frontend/lib/features/dashboard/` (Presentation, Domain, Data)
- `frontend/lib/features/transactions/` (Presentation, Domain, Data)

### A. Layar 1: Halaman Dashboard Utama (`DashboardScreen`)
1. **Proteksi Navigasi:** 
   - Hanya dirender jika status `AuthBloc` adalah `Authenticated`.
2. **Top App Bar / Header:**
   - Menyapa user: *"Halo, [Nama User]"*.
   - Badge mata uang utama user (misal: `IDR`).
   - Tombol Logout.
3. **Timeframe Selector:**
   - Opsi Tab/Segmented Control Utama:
     - **Lifetime (Semua Waktu)**
     - **Periodik**
   - Jika memilih **Periodik**, tampilkan sub-selector (Dropdown / Filter Chips):
     - **Harian**
     - **Mingguan**
     - **Bulanan** (Default)
   - Setiap kali filter berubah, trigger event `DashboardFetchRequested(timeframe)` ke Bloc untuk memuat data ringkasan baru.
4. **Kartu Metrik Keuangan (Summary Cards):**
   - **Total Pemasukan (Total Income):** Teks hijau, menampilkan nominal terformat (misal: `Rp 15.000.000`).
   - **Total Pengeluaran (Total Expense):** Teks merah/oranye, menampilkan nominal terformat (misal: `Rp 4.500.000`).
   - **Untung / Rugi (Net Profit / Loss):** 
     - Warna hijau jika positif (+), warna merah jika negatif (-).
     - Formula: `Total Income - Total Expense`.
5. **Navigasi Form Transaksi:**
   - Sediakan Floating Action Button (**FAB** `+`) atau tombol besar bertuliskan *"Catat Pengeluaran"* yang mengarahkan user ke layar `AddExpenseScreen` (atau modal Bottom Sheet).

### B. Layar 2: Form Input Transaksi Pengeluaran (`AddExpenseScreen`)
1. **Dropdown Mata Uang (`Currency`):**
   - Mengambil data dari endpoint `/api/v1/currencies`.
   - **Default terpilih:** `user.base_currency` (dari user saat ini).
2. **Input Nominal (`Amount`):**
   - Input khusus numerik/desimal.
   - Wajib diisi dan harus bernilai lebih besar dari 0 (`> 0`).
3. **Field Kalkulasi Otomatis ("Nominal dalam [Base Currency]"):**
   - Field *read-only* atau preview teks di bawah input nominal.
   - **Mekanisme Real-Time:**
     - Jika mata uang yang dipilih **sama** dengan mata uang user: tampilkan nominal yang sama (Kurs: 1.0).
     - Jika mata uang yang dipilih **berbeda**: panggil API `/api/v1/currency-rates/latest` dan kalikan: `Nominal * Rate`.
     - Tampilkan teks bantu: *"1 USD = Rp 15.800 (Estimasi: Rp 402.900)"*.
4. **Dropdown Metode Pembayaran (`Payment Method`):**
   - Mengambil data dari endpoint `/api/v1/payment-methods`.
   - Menampilkan nama metode pembayaran (misal: `'Tunai'`, `'Transfer Bank'`).
5. **Input Keterangan (`Notes`):**
   - Kolom teks bebas (TextArea multiline, opsional, maks. 500 karakter).
6. **Tombol Submit ("Simpan Transaksi"):**
   - Validasi form sebelum submit.
   - Tampilkan spinner (*loading state*) saat proses kirim API berlangsung.
   - Jika sukses:
     - Tampilkan notifikasi berhasil (SnackBar).
     - Otomatis kembali (*Pop*) ke Dashboard.
     - Memicu *refresh* data di Dashboard agar angka total pengeluaran langsung ter-update!

---

## 5. Kriteria Penerimaan (Definition of Done / DoD)

### Backend:
- [ ] Tabel `MST_Account` berhasil dibuat lengkap dengan kolom dimensi, tipe Debit/Credit, dan audit log (`created_by`, `Created_At`).
- [ ] Tabel `payment_methods` memiliki relasi Foreign Key `FromAccount` yang mengikat ke `MST_Account.Account`.
- [ ] Tabel `currencies`, `currency_rates`, dan `transactions` berhasil dibuat via migrasi.
- [ ] Database memiliki seed data awal yang saling terhubung: `currencies`, `currency_rates`, `MST_Account`, dan `payment_methods`.
- [ ] Endpoint `/dashboard/summary` menghasilkan angka yang akurat sesuai filter `lifetime`, `monthly`, `weekly`, dan `daily`.
- [ ] Endpoint `POST /transactions` otomatis menghitung `amount_in_base_currency` berdasarkan kurs aktif yang tersimpan.
- [ ] Validasi error `400 / 422` jika nominal <= 0 atau currency/payment_method tidak valid.

### Frontend:
- [ ] Halaman dashboard menampilkan kartu Total Pemasukan, Total Pengeluaran, dan Untung/Rugi dengan format mata uang yang rapi.
- [ ] Penggantian filter timeframe (Lifetime, Bulanan, Mingguan, Harian) sukses meng-update angka di dashboard.
- [ ] Tombol navigasi membuka form pengeluaran dengan lancar.
- [ ] Form pengeluaran otomatis mengeset mata uang default sesuai profil user.
- [ ] Pilihan metode pembayaran menampilkan opsi yang berasal dari backend.
- [ ] Kalkulasi konversi kurs berjalan otomatis dan menampilkan hasil perkiraan sebelum submit.
- [ ] Setelah submit pengeluaran berhasil, dashboard otomatis me-refresh dan memperbarui total pengeluaran secara akurat.
