# Issue: COA (Chart of Accounts) Management & Multi-Level Hierarchy (User-Scoped & Soft Delete)

## 1. Ringkasan Fitur
Fitur **COA (Chart of Accounts / Bagan Akun Buku Besar) Management** memungkinkan pengguna (*authenticated user*) untuk mengelola daftar akun akuntansi mereka sendiri secara mandiri (melihat, menambah, mengedit, dan me-soft delete akun). Setiap akun terisolasi per pengguna (*user-scoped*), sehingga perubahan atau penambahan akun oleh suatu pengguna **tidak akan mempengaruhi pengguna lain**.

Fitur ini mencakup:
1. **Akses Terproteksi**: Halaman COA Management hanya dapat diakses oleh user setelah berhasil login (*authenticated user*).
2. **Operasi CRUD Lengkap dengan Soft Delete**:
   - Pengguna dapat membuat (*Create*), melihat (*Read*), mengedit (*Update*), dan menghapus (*Delete*) akun.
   - Penghapusan dilakukan secara **Soft Delete** (mengubah flag `active = FALSE`), data akun tidak pernah dihapus permanen dari database (*hard delete dilarang*).
3. **Aturan Integritas Data Transaksi (Transaction Guard)**:
   - **Proteksi Hapus**: Apabila sebuah akun sudah pernah digunakan dalam transaksi (misalnya terhubung ke metode pembayaran yang memiliki transaksi, atau transaksi jurnal langsung), akun tersebut **TIDAK DAPAT dihapus / di-soft delete** sebelum data transaksi yang bersangkutan dihapus terlebih dahulu.
   - **Proteksi Kode Akun & Tipe**: Sama seperti aturan hapus, nilai `account` (kode akun) dan `type` (Debit/Credit) **TIDAK DAPAT diubah** jika akun tersebut sudah memiliki riwayat transaksi. Hanya `description`, `dimensi1` s/d `dimensi4`, dan status `active` (jika tidak ada transaksi) yang diizinkan untuk diedit.
4. **Struktur Data Akun**:
   - `account`: Kode akun (string, misal: `1001`, `1101.01`), wajib diisi, unik per pengguna.
   - `description`: Nama/keterangan akun (misal: `Kas Utama`, `Bank Mandiri`, `Beban Sewa`), wajib diisi.
   - `type`: Tipe saldo normal akun, bernilai Enum `Debit` atau `Credit`.
   - `dimensi1` s/d `dimensi4`: Opsional (*nullable*), mereferensi ke `account` milik pengguna yang sama. Digunakan untuk pengelompokan hierarki akun hingga **4 tingkat/level** (Level 1 s/d Level 4).
   - **Popup Lookup Modal untuk Dimensi**: Tersedia dialog popup interaktif untuk memilih nilai `dimensi1` hingga `dimensi4` dengan fitur pencarian/filter berdasarkan kode akun maupun deskripsi akun.
   - `active`: Checkbox status aktif akun (Default: `ACTIVE` / `True`).
   - `created_at`: Timestamp UTC saat akun pertama kali dibuat (Otomatis dibuat oleh sistem, *read-only*, tidak dapat diubah).
   - `created_by`: User ID pembuat akun (Otomatis terisi dari user yang sedang login, *read-only*, tidak dapat diubah).
5. **Template Bawaan Otomatis Saat Registrasi (Default COA Template)**:
   - Ketika pengguna baru menyelesaikan proses registrasi (`POST /api/v1/auth/register`), sistem secara otomatis menyalin (*copy/seed*) paket template akun COA standar (seperti Kas, Bank, Piutang, Hutang, Ekuitas, Pendapatan, dan Beban Operasional) ke dalam akun pengguna tersebut dengan `created_by = user.id`.

---

## 2. Perubahan Skema Database (Database & Models)

### A. Model `MST_Account` (`backend/app/models/finance.py`)
Tabel `mst_account` harus disesuaikan agar mendukung kepemilikan per pengguna (*user-scoped*), multi-level grouping (`dimensi1` s/d `dimensi4`), dan integrasi relasional yang aman:

#### Kolom & Tipe Data:
| Kolom | Tipe Data | Nullable | Default | Keterangan |
| :--- | :--- | :---: | :---: | :--- |
| `id` | `UUID` | No | `uuid.uuid4` | Primary Key unik baris data |
| `account` | `VARCHAR(20)` | No | - | Kode akun bisnis (misal: `1001`, `1.1.01`) |
| `description` | `VARCHAR(255)`| No | - | Keterangan / nama akun |
| `type` | `VARCHAR(10)` | No | - | Enum nilai: `'Debit'` atau `'Credit'` |
| `dimensi1` | `VARCHAR(20)` | **Yes** | `None` | Referensi ke kode akun induk Level 1 (milik user yang sama) |
| `dimensi2` | `VARCHAR(20)` | **Yes** | `None` | Referensi ke kode akun induk Level 2 (milik user yang sama) |
| `dimensi3` | `VARCHAR(20)` | **Yes** | `None` | Referensi ke kode akun induk Level 3 (milik user yang sama) |
| `dimensi4` | `VARCHAR(20)` | **Yes** | `None` | Referensi ke kode akun induk Level 4 (milik user yang sama) |
| `active` | `BOOLEAN` | No | `True` | Status aktif akun. Jika `False`, akun berstatus soft-deleted |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | No | `func.now()` | Timestamp UTC saat akun dibuat (Immutable) |
| `created_by` | `UUID` | **Yes** | `None` | FK ke `users.id` (ON DELETE CASCADE). `NULL` hanya untuk template sistem global |

#### Constraints & Indexes:
1. **Composite Unique Constraint**:
   - `UniqueConstraint('created_by', 'account', name='uq_user_coa_account')`
   - *Tujuan*: Memastikan kode akun unik untuk masing-masing user, namun memungkinkan User A dan User B memiliki kode akun yang sama (misal sama-sama memiliki `1001`).
2. **Index**:
   - Index pada `created_by` untuk optimasi filter akun pengguna aktif.
   - Index pada `account`.

### B. Relasi Antar Tabel & Dependensi Transaksi:
- Tabel `payment_methods`:
  - Kolom `from_account`: Menyimpan string kode akun (`VARCHAR(20)`).
  - Pengecekan transaksi terkait:
    ```sql
    SELECT COUNT(*) FROM transactions t
    JOIN payment_methods pm ON t.payment_method_id = pm.id
    WHERE pm.from_account = :account_code AND pm.user_id = :user_id;
    ```
- Jika count > 0, akun dianggap **sudah digunakan dalam transaksi**, sehingga proteksi hapus dan proteksi perubahan kode/tipe wajib aktif.

### C. Pembaruan Seed Data Template (`backend/init_db.py`)
- Sediakan daftar akun template default sistem (dengan `created_by = None` atau fungsi seed) yang mencakup struktur 4 level dimensi standar, contohnya:
  - `1000` - ASET LANCAR (`Debit`)
  - `1100` - Kas & Bank (`Debit`, `dimensi1="1000"`)
  - `1001` - Kas Utama (`Debit`, `dimensi1="1000"`, `dimensi2="1100"`)
  - `1002` - Bank Operasional (`Debit`, `dimensi1="1000"`, `dimensi2="1100"`)
  - `1003` - Saldo E-Wallet (`Debit`, `dimensi1="1000"`, `dimensi2="1100"`)
  - `2000` - KEWAJIBAN (`Credit`)
  - `2100` - Hutang Jangka Pendek (`Credit`, `dimensi1="2000"`)
  - `2001` - Hutang Kartu Kredit (`Credit`, `dimensi1="2000"`, `dimensi2="2100"`)
  - `3000` - EKUITAS / MODAL (`Credit`)
  - `4000` - PENDAPATAN (`Credit`)
  - `4101` - Pendapatan Gaji (`Credit`, `dimensi1="4000"`)
  - `5000` - BEBAN OPERASIONAL (`Debit`)
  - `5101` - Beban Makan & Minum (`Debit`, `dimensi1="5000"`)

---

## 3. Desain Backend API (FastAPI)

Semua endpoint di bawah ini wajib dilindungi (*Protected*) menggunakan dependency `current_user: User = Depends(get_current_user)`.

### A. Pydantic Schemas (`backend/app/schemas/finance.py`)

```python
class AccountTypeEnum(str, Enum):
    DEBIT = "Debit"
    CREDIT = "Credit"

class AccountCreate(BaseModel):
    account: str = Field(..., min_length=1, max_length=20, description="Kode Akun")
    description: str = Field(..., min_length=1, max_length=255, description="Deskripsi Akun")
    type: AccountTypeEnum
    dimensi1: Optional[str] = Field(None, max_length=20)
    dimensi2: Optional[str] = Field(None, max_length=20)
    dimensi3: Optional[str] = Field(None, max_length=20)
    dimensi4: Optional[str] = Field(None, max_length=20)
    active: bool = True

class AccountUpdate(BaseModel):
    account: Optional[str] = Field(None, min_length=1, max_length=20)
    description: Optional[str] = Field(None, min_length=1, max_length=255)
    type: Optional[AccountTypeEnum] = None
    dimensi1: Optional[str] = Field(None, max_length=20)
    dimensi2: Optional[str] = Field(None, max_length=20)
    dimensi3: Optional[str] = Field(None, max_length=20)
    dimensi4: Optional[str] = Field(None, max_length=20)
    active: Optional[bool] = None

class AccountResponse(BaseModel):
    id: UUID
    account: str
    description: str
    type: str
    dimensi1: Optional[str] = None
    dimensi2: Optional[str] = None
    dimensi3: Optional[str] = None
    dimensi4: Optional[str] = None
    active: bool
    created_at: datetime
    created_by: Optional[UUID] = None
    has_transactions: bool = False

    class Config:
        from_attributes = True

class AccountLookupResponse(BaseModel):
    account: str
    description: str
    type: str
    active: bool

    class Config:
        from_attributes = True
```

---

### B. Endpoint API (`backend/app/api/v1/finance.py`)

#### 1. `GET /api/v1/coa`
- **Tujuan**: Mengambil daftar COA milik pengguna yang sedang login.
- **Query Parameters**:
  - `include_inactive`: `bool` (default: `False`). Jika `False`, hanya tampilkan `active == True`.
  - `search`: `Optional[str]` (pencarian teks pada `account` atau `description`).
  - `type`: `Optional[str]` (`Debit` atau `Credit`).
- **Response**: `200 OK`
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "c1f7a4a2-...",
        "account": "1001",
        "description": "Kas Utama",
        "type": "Debit",
        "dimensi1": "1000",
        "dimensi2": "1100",
        "dimensi3": null,
        "dimensi4": null,
        "active": true,
        "created_at": "2026-09-17T12:00:00Z",
        "created_by": "94e3a905-...",
        "has_transactions": true
      }
    ]
  }
  ```

#### 2. `POST /api/v1/coa`
- **Tujuan**: Membuat akun baru untuk pengguna aktif.
- **Validasi Bisnis**:
  - Kode `account` harus unik untuk `current_user.id`. Jika sudah digunakan, kembalikan HTTP `409 Conflict` (*"Kode akun sudah terdaftar."*).
  - Nilai `dimensi1` s/d `dimensi4` tidak boleh sama dengan `account` akun itu sendiri (*mencegah circular reference langsung*).
  - Jika dimensi diisi, pastikan akun dimensi tersebut ada di daftar akun milik user aktif.
  - Set `created_by = current_user.id` dan `created_at = datetime.now(timezone.utc)`.
- **Response**: `201 Created`

#### 3. `PUT /api/v1/coa/{id}`
- **Tujuan**: Mengubah konfigurasi akun.
- **Validasi Proteksi Transaksi**:
  1. Ambil data akun berdasarkan `id` dan pastikan `created_by == current_user.id`. Jika tidak ditemukan, kembalikan HTTP `404`.
  2. Periksa apakah akun ini telah digunakan dalam transaksi:
     - Jika **sudah ada transaksi**:
       - Cek apakah payload mencoba mengubah `account` atau `type`.
       - Jika nilai `account` atau `type` berbeda dari data saat ini, **TOLAK** dengan HTTP `400 Bad Request`:
         > *"Kode akun dan tipe akun (Debit/Credit) tidak dapat diubah karena akun ini sudah memiliki riwayat transaksi."*
       - Perubahan pada `description` dan `dimensi1..4` tetap diizinkan.
  3. Jika **belum ada transaksi**:
     - Pengguna bebas mengubah `account`, `description`, `type`, `dimensi1..4`, maupun `active`.
     - Jika kode `account` diubah, lakukan validasi duplikasi untuk memastikan kode baru belum dipakai akun lain milik user.
- **Response**: `200 OK`

#### 4. `DELETE /api/v1/coa/{id}` (Soft Delete)
- **Tujuan**: Menonaktifkan akun (*Soft Delete*).
- **Validasi Proteksi Transaksi**:
  1. Ambil data akun berdasarkan `id` dan pastikan `created_by == current_user.id`. Jika tidak ada, kembalikan HTTP `404`.
  2. Periksa apakah akun memiliki riwayat transaksi:
     - Jika **ada transaksi**, **TOLAK** dengan HTTP `400 Bad Request`:
       > *"Akun tidak dapat dinonaktifkan atau dihapus karena sudah terdapat transaksi yang menggunakan akun ini. Hapus data transaksi terkait terlebih dahulu."*
  3. Jika **tidak ada transaksi**:
     - Lakukan soft delete: set `active = False`.
     - Simpan perubahan ke database.
- **Response**: `200 OK`
  ```json
  {
    "success": true,
    "message": "Akun berhasil dinonaktifkan (soft deleted)."
  }
  ```

#### 5. `GET /api/v1/coa/lookup`
- **Tujuan**: Menyediakan data pencarian untuk modal dialog lookup (digunakan saat memilih `dimensi1` s/d `dimensi4` maupun saat pemilihan akun pada form Payment Method).
- **Query Parameters**:
  - `q`: `Optional[str]` (kata kunci pencarian kode atau deskripsi).
  - `exclude_account`: `Optional[str]` (opsional: kode akun yang sedang diedit agar tidak muncul sebagai opsi dimensi untuk mencegah referensi ke diri sendiri).
- **Filter**: Hanya mengembalikan akun milik `current_user.id` yang berstatus `active == True`.
- **Response**: `200 OK`

---

### C. Registration Hook: Copy Template Default (`backend/app/api/v1/auth.py`)
Pada endpoint registrasi pengguna baru:
1. Setelah entitas `db_user` berhasil di-commit ke database, panggil helper function:
   ```python
   await seed_default_user_coa(db: AsyncSession, user_id: UUID)
   ```
2. Fungsi ini menduplikasi daftar akun template standar ke tabel `mst_account` dengan `created_by = user_id`, `active = True`, dan mempertahankan struktur hierarki `dimensi1..4`.
3. Setelah registrasi selesai, user baru langsung memiliki bagan akun COA lengkap siap pakai tanpa harus membuat dari nol.

---

## 4. Desain Frontend UI/UX (Flutter)

### A. Struktur Arsitektur Fitur (`frontend/lib/features/finance/`)

```
lib/features/finance/
├── domain/
│   └── models.dart                     # Model MSTAccount diperbarui
├── data/
│   └── finance_repository.dart         # Method API: getCoa, createCoa, updateCoa, deleteCoa, lookupCoa
└── presentation/
    ├── bloc/
    │   ├── coa_bloc.dart               # State Management COA
    │   ├── coa_event.dart
    │   └── coa_state.dart
    ├── screens/
    │   └── coa_management_screen.dart   # Halaman utama konfigurasi COA
    └── widgets/
        ├── coa_form_dialog.dart        # Dialog Tambah/Edit Akun
        ├── coa_lookup_dialog.dart      # Dialog Popup Lookup Nilai Dimensi
        └── coa_hierarchy_view.dart     # (Opsional) Visualisasi hierarki level 1-4
```

---

### B. Spesifikasi Layar & Komponen UI

#### 1. Halaman Utama: `CoaManagementScreen`
- **Akses Navigasi**: Dapat dibuka dari **Drawer Menu Utama** di `DashboardScreen`: *"Manajemen Bagan Akun (COA)"*.
- **Header & Filter Bar**:
  - Search bar interaktif dengan pencarian cepat (*filter by code or description*).
  - Filter Switch: "Tampilkan Akun Nonaktif" (`include_inactive`).
  - Filter Tipe Saldo: Semua / Debit / Credit.
- **Daftar Akun (ListView / DataTable / Card Grouping)**:
  - Setiap baris menampilkan:
    - **Kode Akun (`account`)**: Ditampilkan tebal (*bold*), misal `1001`.
    - **Nama Akun (`description`)**: Nama lengkap akun.
    - **Badge Tipe Saldo**:
      - `Debit` : Chip berwarna biru terang (`Colors.blue.shade100` / teks biru tua).
      - `Credit`: Chip berwarna oranye/amber terang (`Colors.orange.shade100` / teks cokelat/oranye).
    - **Tag Dimensi (Hierarki Level)**:
      - Menampilkan chip kecil dimensi yang terisi, misal: `L1: 1000`, `L2: 1100` untuk memudahkan membaca hierarki.
    - **Indikator Terkunci Transaksi**:
      - Jika `has_transactions == true`, tampilkan ikon gembok abu-abu dengan Tooltip: *"Akun telah digunakan dalam transaksi (Kode & Tipe terkunci)"*.
    - **Aksi Cepat**:
      - Switch/Toggle status `active` (hanya bisa diubah jika belum ada transaksi).
      - Tombol **Edit** (ikon pensil).
      - Tombol **Hapus** (ikon tempat sampah merah).
- **Floating Action Button**:
  - Tombol bertuliskan "+ Tambah Akun" untuk membuka `CoaFormDialog` dalam mode penambahan baru.

---

#### 2. Dialog Form Akun: `CoaFormDialog`
Digunakan untuk **Tambah Akun Baru** maupun **Edit Akun**.

- **Field Input & Validasi**:
  1. **Kode Akun (`account`)**:
     - Text field (Maks 20 karakter, huruf kapital/angka).
     - *Validasi*: Wajib diisi.
     - *State Khusus*: Jika dalam mode edit dan `has_transactions == true`, text field berstatus **READ-ONLY / DISABLED** dengan keterangan: *"Tidak dapat diubah karena akun telah digunakan dalam transaksi."*
  2. **Nama / Deskripsi Akun (`description`)**:
     - Text field (Maks 255 karakter).
     - *Validasi*: Wajib diisi. Selalu dapat diedit.
  3. **Tipe Akun (`type`)**:
     - Dropdown / Segmented Button: `Debit` atau `Credit`.
     - *Validasi*: Wajib dipilih.
     - *State Khusus*: Jika dalam mode edit dan `has_transactions == true`, input ini berstatus **DISABLED**.
  4. **Dimensi 1 hingga Dimensi 4 (Hierarki Akun)**:
     - Disediakan 4 baris input opsional untuk `dimensi1`, `dimensi2`, `dimensi3`, dan `dimensi4`.
     - Setiap baris dimensi memiliki:
       - Label jelas, misal: *"Dimensi 1 (Induk Level 1)"*, *"Dimensi 2 (Induk Level 2)"*, dst.
       - Teks deskriptif akun terpilih (misal: `1000 - ASET LANCAR`) atau *"Belum diatur (Opsional)"*.
       - **Ikon Pencarian (Lookup)**: Membuka `CoaLookupDialog` untuk mencari dan memilih akun.
       - **Ikon Hapus / Clear**: Mengosongkan nilai dimensi kembali menjadi `null`.
  5. **Checkbox Status Aktif (`active`)**:
     - Checkbox / Switch dengan label *"Status Aktif"*. Default bernilai `True`.
     - Jika dinonaktifkan, akun tidak dapat dipilih lagi pada transaksi mendatang.
  6. **Informasi Audit Sistem (Read-Only)**:
     - Ditampilkan pada mode edit di bagian bawah form:
       - `created_at`: Menampilkan tanggal dan jam pembuatan akun (format lokal user atau UTC).
       - `created_by`: Menampilkan ID / nama pemilik akun.
- **Banner Peringatan Transaksi**:
  - Jika akun memiliki transaksi, tampilkan kotak info berwarna oranye/kuning di atas form:
    > *"⚠️ Perhatian: Akun ini sudah memiliki catatan transaksi. Kode akun dan tipe saldo tidak dapat dimodifikasi demi menjaga konsistensi pembukuan."*
- **Tombol Form**:
  - Tombol **Batal** dan Tombol **Simpan**.

---

#### 3. Modal Dialog Lookup Dimensi: `CoaLookupDialog`
- **Tujuan**: Memungkinkan user mencari dan memilih akun induk untuk `dimensi1` s/d `dimensi4` secara interaktif.
- **Fitur Modal**:
  - **Judul**: *"Pilih Akun Induk (Dimensi [X])"*.
  - **Search Input**: Text field pencarian dengan filter *real-time* berdasarkan kode akun maupun deskripsi akun.
  - **Pencegahan Self-Reference**: Akun yang sedang diedit otomatis dikecualikan (`exclude_account`) dari daftar pencarian agar akun tidak bisa memilih dirinya sendiri sebagai dimensi.
  - **Daftar Akun**: Menampilkan list akun aktif milik user lengkap dengan nomor akun, deskripsi, dan badge tipe.
  - **Aksi Pemilihan**: Mengklik item langsung memilih akun tersebut, menutup dialog, dan mengisi nilai dimensi pada form.
  - Tombol **Batal** atau **Kosongkan Pilihan**.

---

#### 4. Dialog Konfirmasi Soft Delete
- Saat user menekan ikon tempat sampah pada akun:
  - **Kondisi A (Akun sudah ada transaksi)**:
    - Munculkan AlertDialog peringatan (*Error / Forbidden*):
      > *"⛔ Akun Tidak Dapat Dihapus*\n\n*Akun [Kode - Nama] tidak dapat dinonaktifkan atau dihapus karena masih memiliki riwayat transaksi. Harap sesuaikan atau hapus transaksi terkait terlebih dahulu."*
    - Hanya ada tombol **Tutup**.
  - **Kondisi B (Akun belum ada transaksi)**:
    - Munculkan AlertDialog konfirmasi:
      > *"Apakah Anda yakin ingin menonaktifkan akun [Kode - Nama]? Akun ini akan berstatus nonaktif dan tidak dapat dipilih pada transaksi baru."*
    - Tombol: **Batal** dan **Nonaktifkan** (Warna Merah).
    - Saat dikonfirmasi, kirim request `DELETE /api/v1/coa/{id}` dan lakukan *refresh* data otomatis.

---

## 5. Pembaruan File Dokumentasi Wajib

Setelah seluruh pekerjaan kode selesai, developer/AI wajib memperbarui file-file dokumentasi berikut:
1. **`docs/table.md`**:
   - Perbarui skema tabel `mst_account` (tambahkan kolom `id`, `created_by`, penyesuaian tipe data dimensi, dan composite unique constraint `(created_by, account)`).
   - Perbarui diagram Mermaid ERD yang menggambarkan relasi `mst_account` dengan `users`, `payment_methods`, dan hierarki self-referencing.
2. **`docs/routes.md`**:
   - Tambahkan daftar seluruh endpoint `/api/v1/coa` (`GET`, `POST`, `PUT`, `DELETE`, `lookup`).
   - Tambahkan rute layar `CoaManagementScreen` pada bagian navigasi Flutter.
3. **`docs/features.md`**:
   - Perbarui baris fitur **General Ledger (COA Management)**:
     - Ubah status pengerjaan dari `🟡 Parsial` menjadi `🟢 Selesai`.
     - Ubah status test menjadi `⚠️ Manual Verified`.
     - Perbarui rincian deskripsi fitur pada bagian bawah dokumen.

---

## 6. Kriteria Penerimaan (Definition of Done / DoD)

### Backend:
- [ ] Model `MST_Account` memiliki kolom `id` (UUID PK), `account`, `description`, `type`, `dimensi1..4`, `active`, `created_at`, dan `created_by`.
- [ ] Terdapat `UniqueConstraint('created_by', 'account')` sehingga kode akun unik per pengguna.
- [ ] Query `GET /api/v1/coa` hanya mengembalikan akun milik user yang sedang login (`created_by == current_user.id`).
- [ ] Respon akun menyertakan flag `has_transactions: bool` yang akurat.
- [ ] Endpoint `POST /api/v1/coa` berhasil membuat akun baru, memvalidasi duplikasi kode (HTTP 409), dan mencegah dimensi merujuk ke kode akun itu sendiri.
- [ ] Endpoint `PUT /api/v1/coa/{id}` **MENOLAK** pengubahan `account` dan `type` dengan HTTP 400 jika akun sudah memiliki transaksi.
- [ ] Endpoint `DELETE /api/v1/coa/{id}` **MENOLAK** penghapusan dengan HTTP 400 jika akun sudah memiliki transaksi.
- [ ] Endpoint `DELETE /api/v1/coa/{id}` melakukan **soft delete** (`active = False`), tidak melakukan hard delete di database.
- [ ] Endpoint `GET /api/v1/coa/lookup` berhasil memfilter akun aktif milik user dan mendukung parameter pencarian `q` serta `exclude_account`.
- [ ] Registrasi user baru (`POST /api/v1/auth/register`) secara otomatis menduplikasi template COA default ke akun user baru tersebut.
- [ ] Database re-seed via `python init_db.py` dan `python reset_db.py` berjalan bersih tanpa error.

### Frontend:
- [ ] Layar `CoaManagementScreen` dapat diakses melalui Drawer Menu Navigasi di `DashboardScreen`.
- [ ] Menampilkan daftar akun secara rapi dengan badge warna Debit (biru) dan Credit (oranye), serta tag hierarki `dimensi1` s/d `dimensi4`.
- [ ] Form Tambah/Edit memiliki popup lookup modal interaktif (`CoaLookupDialog`) untuk memilih nilai `dimensi1` hingga `dimensi4`.
- [ ] Pengguna dapat mengosongkan nilai dimensi jika akun tidak memiliki induk.
- [ ] Form Edit mengunci (*read-only / disabled*) input `account` dan `type` jika akun sudah memiliki riwayat transaksi, disertai alert/banner penjelasan yang ramah.
- [ ] Field `created_at` dan `created_by` tampil sebagai informasi audit *read-only* yang tidak dapat diedit user.
- [ ] Aksi hapus menampilkan modal konfirmasi soft-delete jika belum ada transaksi, atau menampilkan modal peringatan larangan hapus jika akun sudah memiliki transaksi.
- [ ] Filter pencarian teks dan filter status aktif/nonaktif berfungsi responsif pada daftar akun.
- [ ] Analisis statis Flutter lulus bersih tanpa warning atau error (`flutter analyze`).
