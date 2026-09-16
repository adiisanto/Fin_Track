# [FEATURE] Manajemen Multi-Currency (Admin / Superadmin Only)

---

## 📌 PANDUAN UNTUK DEVELOPER / AI AGENT
> **PENTING DIBACA SEBELUM CODING:**
> 1. Ikuti spesifikasi teknis, arsitektur, dan struktur file yang telah ditentukan di bawah ini secara ketat.
> 2. Proyek ini menerapkan pembagian arsitektur:
>    - **Backend**: FastAPI, SQLAlchemy 2.0 (Async + asyncpg), Pydantic v2, Python 3.13.
>    - **Frontend**: Flutter (BLoC pattern, Dio client, Clean Architecture 3 lapis: `data/`, `domain/`, `presentation/`).
> 3. Halaman dan Endpoint ini bersifat **Restricted / Superadmin Only** (User biasa **DILARANG** mengakses endpoint penambahan/penghapusan currency maupun layarnya di frontend).
> 4. Selesaikan pekerjaan secara berurutan sesuai langkah kerja:
>    - **Langkah 1**: Pembaruan Skema Database & Seed (`backend/app/models/`, `backend/init_db.py`, `docs/table.md`).
>    - **Langkah 2**: Backend API Endpoints & Auth Dependency (`backend/app/api/v1/`, `backend/app/schemas/`, `docs/routes.md`).
>    - **Langkah 3**: Frontend BLoC & Screen (`frontend/lib/features/currency/` atau `finance/`).
>    - **Langkah 4**: Pembaruan Dokumen Pelacak (`docs/features.md`).

---

## 1. Ringkasan Fitur (Feature Overview)

Fitur ini menyediakan antarmuka dan API bagi pengguna dengan hak akses **Superadmin** untuk mengelola daftar mata uang (*multi-currency*) yang berlaku di dalam sistem Fin_Track:
1. **Daftar Mata Uang (List Currencies):** Menampilkan seluruh data mata uang yang ada di tabel `currencies`, termasuk waktu dibuat (`created_at` dalam format UTC).
2. **Tambah Mata Uang (Add Currency):** Form modal/dialog untuk menambahkan mata uang baru dengan validasi kode ISO 3 huruf kapital unik (contoh: `JPY`, `GBP`). Field `created_at` otomatis terisi waktu saat penambahan dalam UTC.
3. **Hapus Mata Uang (Delete Currency):** 
   - Tombol hapus dengan proteksi integritas data:
     - **TIDAK BISA DIHAPUS** jika kode mata uang sudah pernah digunakan di tabel transaksi (`transactions`). Backend wajib menolak dan mengembalikan HTTP 400 Bad Request.
     - **BISA DIHAPUS** jika belum pernah tercatat di transaksi.
   - Jika berhasil dihapus, **seluruh data kurs terkait di mana mata uang tersebut menjadi mata uang asal (`currency_rates.from_currency`) wajib ikut dihapus**.

---

## 2. Kebutuhan Database & Relasi (PostgreSQL / SQLAlchemy)

### A. Modifikasi Tabel `users`
Tambahkan kolom untuk membedakan user biasa dengan superadmin:
- **File target**: `backend/app/models/user.py`
- **Kolom baru**:
  | Kolom | Tipe Data | Constraint | Keterangan |
  | :--- | :--- | :--- | :--- |
  | `is_superuser` | `BOOLEAN` | `default=False, nullable=False` | `True` jika user adalah superadmin |

### B. Modifikasi Tabel `currencies`
Tambahkan kolom pencatatan waktu pembuatan data currency dalam format UTC:
- **File target**: `backend/app/models/finance.py`
- **Kolom baru**:
  | Kolom | Tipe Data | Constraint | Keterangan |
  | :--- | :--- | :--- | :--- |
  | `created_at` | `TIMESTAMPTZ` | `server_default=func.now(), nullable=False` | Waktu dibuat dalam UTC |

### C. Pembaruan Seed Data (`backend/init_db.py`)
1. Pastikan user superadmin dibuat atau diset saat inisialisasi:
   - Contoh: Akun email `admin@fintrack.com` dengan password ter-hash dan `is_superuser=True`.
2. Pastikan entri seed mata uang default (`IDR`, `USD`, `EUR`, `SGD`) menyertakan/mengisi nilai `created_at`.

---

## 3. Spesifikasi API Backend (FastAPI)

Semua endpoint berikut berada di bawah prefix `/api/v1`.

### A. Auth Helper / Dependency Baru
- **File**: `backend/app/api/deps.py`
- **Fungsi**: `get_current_superadmin(current_user: User = Depends(get_current_user)) -> User`
  - Validasi: `if not current_user.is_superuser:`
  - Raise: `HTTPException(status_code=403, detail="Akses ditolak. Fitur ini hanya untuk Superadmin.")`

---

### B. Endpoint 1: Mendapatkan List Mata Uang
- **Endpoint**: `GET /api/v1/currencies`
- **Akses**: Public / Authenticated User
- **Method**: `GET`
- **Query Param (Opsional)**: `include_inactive=true/false` (default: `false` untuk publik, `true` jika admin)
- **Response (200 OK)**:
```json
{
  "success": true,
  "data": [
    {
      "code": "IDR",
      "name": "Indonesian Rupiah",
      "symbol": "Rp",
      "is_active": true,
      "created_at": "2026-09-16T10:00:00Z"
    },
    {
      "code": "USD",
      "name": "US Dollar",
      "symbol": "$",
      "is_active": true,
      "created_at": "2026-09-16T10:00:00Z"
    }
  ]
}
```

---

### C. Endpoint 2: Menambahkan Mata Uang Baru (Superadmin Only)
- **Endpoint**: `POST /api/v1/admin/currencies`
- **Akses**: **Protected (Superadmin Only)** -> Gunakan `Depends(get_current_superadmin)`
- **Request Body**:
```json
{
  "code": "JPY",
  "name": "Japanese Yen",
  "symbol": "¥",
  "is_active": true
}
```
- **Aturan Validasi Backend (Pydantic / Service)**:
  1. `code`: Wajib berupa 3 huruf alfabet, otomatis di-*uppercase* (`JPY`).
  2. Cek apakah `code` sudah terdaftar di tabel `currencies`. Jika sudah ada, kembalikan:
     - `HTTP 409 Conflict`: `{"detail": "Kode mata uang JPY sudah terdaftar."}`
  3. Set kolom `created_at` menggunakan waktu sekarang dalam UTC (`datetime.now(timezone.utc)`).
- **Response (201 Created)**:
```json
{
  "success": true,
  "message": "Mata uang JPY berhasil ditambahkan.",
  "data": {
    "code": "JPY",
    "name": "Japanese Yen",
    "symbol": "¥",
    "is_active": true,
    "created_at": "2026-09-16T12:45:30.123456Z"
  }
}
```

---

### D. Endpoint 3: Menghapus Mata Uang (Superadmin Only)
- **Endpoint**: `DELETE /api/v1/admin/currencies/{code}`
- **Akses**: **Protected (Superadmin Only)** -> Gunakan `Depends(get_current_superadmin)`
- **Path Parameter**: `code` (string, misal: `JPY`)
- **Aturan Bisnis & Integritas Data**:
  1. Cari currency berdasarkan `code`. Jika data tidak ditemukan:
     - Return `HTTP 404 Not Found`: `{"detail": "Mata uang tidak ditemukan."}`
  2. **Validasi Keterikatan Transaksi**:
     - Jalankan query ke tabel `transactions` untuk mengecek apakah ada transaksi yang menggunakan `currency_code == code`.
     - **JIKA ADA**: Batalkan proses penghapusan!
     - Return `HTTP 400 Bad Request`:
       ```json
       {
         "detail": "Mata uang JPY tidak dapat dihapus karena sudah digunakan pada data transaksi."
       }
       ```
  3. **Pembersihan Data Kurs (`currency_rates`)**:
     - **JIKA TIDAK ADA TRANSAKSI TERKAIT**:
     - Hapus semua data pada tabel `currency_rates` yang memiliki `from_currency == code`.
       *(Eksekusi: `DELETE FROM currency_rates WHERE from_currency = :code`)*.
     - Hapus record currency dari tabel `currencies`.
     - Lakukan `db.commit()`.
- **Response (200 OK)**:
```json
{
  "success": true,
  "message": "Mata uang JPY beserta data kurs terkait berhasil dihapus."
}
```

---

## 4. Spesifikasi Frontend (Flutter)

### A. Domain & Data Layer
- **Model**: `CurrencyModel` (menambahkan field `DateTime createdAt`).
- **Repository**: Tambahkan fungsi pada `FinanceRepository` (atau buat `CurrencyRepository`):
  - `Future<List<CurrencyModel>> getCurrencies({bool includeInactive = false})`
  - `Future<CurrencyModel> addCurrency({required String code, required String name, required String symbol, bool isActive = true})`
  - `Future<void> deleteCurrency(String code)`

### B. State Management (`CurrencyBloc`)
- **Folder**: `frontend/lib/features/currency/presentation/bloc/` (atau di bawah `finance/`)
- **Events**:
  - `CurrencyFetchRequested()`
  - `CurrencyCreateRequested(code, name, symbol, isActive)`
  - `CurrencyDeleteRequested(code)`
- **States**:
  - `CurrencyInitial`
  - `CurrencyLoading`
  - `CurrencyLoaded(List<CurrencyModel> currencies)`
  - `CurrencyOperationSuccess(String message)`
  - `CurrencyError(String errorMessage)`

### C. UI Screen: `CurrencyManagementScreen`
- **File**: `frontend/lib/features/currency/presentation/screens/currency_management_screen.dart`
- **Proteksi Halaman (Role Check)**:
  - Sebelum merender, periksa apakah `user.isSuperuser == true`.
  - Jika bukan superadmin, tampilkan teks *"Akses Ditolak: Halaman ini hanya untuk Superadmin"*.
- **Tampilan Utama**:
  - **AppBar**: Judul *"Manajemen Mata Uang"*.
  - **Tombol Tambah**: Floating Action Button (FAB) atau tombol di AppBar bertuliskan *"+ Tambah Mata Uang"*.
  - **Body (List / Table)**:
    - Menampilkan kartu atau `DataTable` yang memuat:
      - Kode (misal: `IDR`, `USD`)
      - Nama (misal: `Indonesian Rupiah`)
      - Simbol (misal: `Rp`)
      - Waktu Dibuat (`created_at` diformat: `YYYY-MM-DD HH:mm UTC`)
      - Status (`Aktif` / `Nonaktif`)
      - Tombol Aksi: Icon Hapus (merah).
- **Dialog Tambah Mata Uang**:
  - Input `Code`: Maksimal 3 huruf (auto-capitalized).
  - Input `Name`: Teks nama lengkap mata uang.
  - Input `Symbol`: Teks simbol ($, Rp, €, ¥).
  - Tombol Batal & Simpan.
  - Validasi: Semua field wajib diisi.
- **Dialog Konfirmasi Hapus**:
  - Menampilkan modal dialog: *"Apakah Anda yakin ingin menghapus mata uang [CODE]? Semua data kurs terkait juga akan dihapus."*
  - Tombol *Batal* & *Hapus*.
- **Handling Error Responsif**:
  - Jika penghapusan gagal karena mata uang sudah terpakai di transaksi (HTTP 400), tampilkan `SnackBar` merah dengan pesan error langsung dari backend.
  - Jika berhasil, tampilkan `SnackBar` hijau dan otomatis *reload* list mata uang.

---

## 5. Pembaruan Dokumentasi Wajib (Docs Updates)

Setelah pengerjaan kode selesai, developer/AI wajib memperbarui file-file dokumentasi berikut:
1. **`docs/table.md`**:
   - Tambahkan kolom `is_superuser` pada tabel `users`.
   - Tambahkan kolom `created_at` pada tabel `currencies`.
2. **`docs/routes.md`**:
   - Tambahkan rute `POST /api/v1/admin/currencies` dan `DELETE /api/v1/admin/currencies/{code}`.
   - Tambahkan layar `CurrencyManagementScreen` pada bagian Frontend navigation.
3. **`docs/features.md`**:
   - Update baris fitur `Multi-Currency & Exchange Rates`: Ubah status pengerjaan dan tambahkan catatan implementasi manajemen mata uang admin.

---

## 6. Kriteria Penerimaan (Definition of Done / DoD)

### Backend:
- [ ] Kolom `is_superuser` terpasang di model `User` dan `created_at` terpasang di model `Currency`.
- [ ] Dependency `get_current_superadmin` menolak request dengan HTTP 403 jika user bukan superadmin.
- [ ] `POST /api/v1/admin/currencies` berhasil menyimpan data baru dengan `created_at` berformat UTC.
- [ ] Validasi kode duplikat menghasilkan HTTP 409.
- [ ] `DELETE /api/v1/admin/currencies/{code}` menolak penghapusan dengan HTTP 400 jika mata uang terkait sudah digunakan pada tabel `transactions`.
- [ ] Jika belum digunakan di `transactions`, penghapusan mata uang berhasil sekaligus menghapus record terkait di tabel `currency_rates` (`where from_currency == code`).
- [ ] Script `init_db.py` berhasil dieksekusi ulang tanpa error.

### Frontend:
- [ ] Halaman `CurrencyManagementScreen` hanya dapat diakses oleh user dengan hak `is_superuser`.
- [ ] Menampilkan list mata uang lengkap dengan waktu pembuatan (UTC) dan simbol.
- [ ] Form pop-up tambah mata uang dapat mengirim request dan memvalidasi input.
- [ ] Dialog konfirmasi muncul sebelum penghapusan.
- [ ] Error HTTP 400 (currency terpakai transaksi) ditampilkan secara ramah kepada user via SnackBar.
- [ ] Halaman otomatis ter-refresh setelah penambahan atau penghapusan data.
- [ ] Static analysis lulus (`flutter analyze` tanpa warning/error).
