# Feature Matrix & Roadmap - Fin_Track

Dokumen ini mencatat seluruh fitur yang ada, sedang dikerjakan, maupun yang direncanakan pada proyek **Fin_Track**. Dokumen ini **wajib diperbarui** setiap kali ada penambahan fitur baru, perubahan status pengerjaan, maupun penambahan pengujian (*automated/manual test*).

---

## 📌 Status Legend

### Status Pengerjaan
- 🟢 **Selesai (Done)**: Fitur sudah diimplementasikan (Backend API & Frontend UI) dan berfungsi normal.
- 🟡 **Parsial (In-Progress)**: Baru selesai sebagian (misal: backend sudah siap, frontend belum, atau sebaliknya).
- ⚪ **Belum Dimulai (Planned)**: Masuk dalam *backlog* atau rencana pengembangan selanjutnya.

### Status Test
- ✅ **Automated Pass**: Sudah memiliki unit/widget/integration test otomatis dan lolos.
- ⚠️ **Manual Verified**: Sudah diverifikasi secara fungsional melalui pengetesan manual, namun belum memiliki automated test.
- ⏳ **Belum Dites (Untested)**: Belum melalui proses pengujian komprehensif.
- ❌ **Failed**: Ditemukan bug / test gagal.

---

## 📊 Feature Matrix Overview

| No | Feature Name | Domain | Status Pengerjaan | Status Test | Keterangan Singkat |
| :---: | :--- | :--- | :---: | :---: | :--- |
| 1 | **User Authentication & Session** | Auth | 🟢 Selesai | ⚠️ Manual Verified | Register, Login, JWT access/refresh token, Profile |
| 2 | **Dashboard Summary** | Finance | 🟢 Selesai | ⚠️ Manual Verified | Rekap pemasukan, pengeluaran, net profit/loss, filter timeframe |
| 3 | **Expense Tracking (Catat Pengeluaran)** | Finance | 🟢 Selesai | ⚠️ Manual Verified | Form catat biaya, konversi kurs otomatis, binding GL account |
| 4 | **Multi-Currency & Exchange Rates** | Master/Finance | 🟡 Parsial | ⚠️ Manual Verified | Master mata uang & kurs terbaru sudah jalan; UI kelola kurs belum ada |
| 5 | **Payment Methods & GL Mapping** | Master/Finance | 🟡 Parsial | ⚠️ Manual Verified | Relasi ke `mst_account` aktif; form CRUD payment method belum ada |
| 6 | **Income Tracking (Catat Pemasukan)** | Finance | ⚪ Belum Dimulai | ⏳ Belum Dites | Backend sudah siap menerima type `INCOME`, form UI di Flutter belum dibuat |
| 7 | **Transaction History & Filter** | Finance | ⚪ Belum Dimulai | ⏳ Belum Dites | Halaman riwayat daftar transaksi dengan pagination & search |
| 8 | **General Ledger (COA Management)** | Finance | 🟡 Parsial | ⏳ Belum Dites | Skema tabel `mst_account` & seed data sudah siap; CRUD UI belum ada |
| 9 | **Budgeting / Target Anggaran** | Finance | ⚪ Belum Dimulai | ⏳ Belum Dites | Batasan pengeluaran per kategori / akun GL dalam periode tertentu |
| 10 | **Export & Financial Reports** | Finance | ⚪ Belum Dimulai | ⏳ Belum Dites | Unduh laporan laba/rugi, arus kas, ekspor CSV/PDF |

---

## 🔍 Rincian Fitur

### 1. User Authentication & Session
- **Deskripsi**: Registrasi pengguna baru dengan preferensi base currency, login email & password, penyimpanan aman token (`flutter_secure_storage`), serta auto-login via auth gate.
- **Backend**: Endpoint `/api/v1/auth/register`, `/login`, `/refresh`, `/me`. Password hashing menggunakan Argon2.
- **Frontend**: `LoginScreen`, `RegisterScreen`, `AuthBloc`, state-driven `AppNavigator`.
- **Status Pengerjaan**: 🟢 Selesai
- **Status Test**: ⚠️ Manual Verified (Automated test `pytest` & `flutter test` belum dibuat)

### 2. Dashboard Summary
- **Deskripsi**: Menampilkan ringkasan kondisi keuangan pengguna (Total Pemasukan, Total Pengeluaran, Untung/Rugi) dengan konversi ke base currency pengguna.
- **Fitur Utama**:
  - Filter rentang waktu: `daily`, `weekly`, `monthly`, `lifetime`.
  - Tampilan kartu ringkasan visual dinamis.
- **Backend**: Endpoint `/api/v1/dashboard/summary`.
- **Frontend**: `DashboardScreen`, `DashboardBloc`.
- **Status Pengerjaan**: 🟢 Selesai
- **Status Test**: ⚠️ Manual Verified

### 3. Expense Tracking (Catat Pengeluaran)
- **Deskripsi**: Formulir pencatatan transaksi pengeluaran uang dengan kalkulasi kurs *realtime* dan pemilihan metode pembayaran yang terikat ke akun GL kas/bank.
- **Backend**: Endpoint `POST /api/v1/transactions` (type: `EXPENSE`).
- **Frontend**: `AddExpenseScreen`, `TransactionBloc`.
- **Status Pengerjaan**: 🟢 Selesai
- **Status Test**: ⚠️ Manual Verified

### 4. Multi-Currency & Kurs
- **Deskripsi**: Dukungan multi-mata uang untuk transaksi non-base currency dengan konversi otomatis ke base currency pengguna berdasarkan tabel `currency_rates`.
- **Backend**: Endpoint `/api/v1/currencies`, `/api/v1/currency-rates/latest`.
- **Frontend**: Dropdown pemilihan mata uang & kalkulator konversi pada form transaksi.
- **Status Pengerjaan**: 🟡 Parsial (Konsumsi data transaksi sudah berjalan; UI administrasi penambahan kurs/mata uang baru belum ada).
- **Status Test**: ⚠️ Manual Verified

### 5. Payment Methods & Master GL (`MST_Account`)
- **Deskripsi**: Integrasi metode pembayaran dengan Buku Besar / Chart of Accounts (COA) dengan hierarki dimensi 1-4.
- **Backend**: Model `PaymentMethod` terhubung FK ke `MST_Account.account`.
- **Frontend**: Dropdown metode pembayaran menampilkan nama dan keterangan akun GL.
- **Status Pengerjaan**: 🟡 Parsial (Struktur core GL & konsumsi di transaksi selesai; layar pengelolaan akun GL dan CRUD payment method belum dibuat).
- **Status Test**: ⚠️ Manual Verified

### 6. Income Tracking (Catat Pemasukan)
- **Deskripsi**: Pencatatan penerimaan kas/pendapatan (gaji, investasi, dll) ke dalam sistem.
- **Backend**: Endpoint `POST /api/v1/transactions` telah mendukung `INCOME`.
- **Frontend**: Belum ada layar `AddIncomeScreen` atau tombol aksi pemasukan pada Dashboard.
- **Status Pengerjaan**: ⚪ Belum Dimulai
- **Status Test**: ⏳ Belum Dites

---

## 🎯 Rekomendasi Prioritas Pengerjaan Selanjutnya

1. **Catat Pemasukan (Income Tracking)**: Melengkapi alur input transaksi agar metrik pemasukan di Dashboard dapat terisi secara riil.
2. **Transaction History**: Memudahkan user meninjau dan menghapus/mengedit transaksi yang sudah diinput.
3. **Automated Unit Tests**: Menulis test suite pertama (`pytest` untuk backend dan `flutter test` untuk BLoC/Repository) agar status test beralih dari *Manual Verified* ke *Automated Pass*.
