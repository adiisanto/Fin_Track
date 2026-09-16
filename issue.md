# Issue: Payment Method Management & Custom Templates (User-Scoped & Soft Delete)

## 1. Ringkasan Fitur
Fitur **Payment Method Management** memungkinkan setiap pengguna (*authenticated user*) untuk mengelola daftar metode pembayaran mereka sendiri secara independen (melihat, menambah, mengedit, dan menonaktifkan/soft delete). Setiap perubahan data yang dilakukan oleh suatu user bersifat *isolated* (multi-tenant per user) dan **tidak akan berefek pada data user lain**.

Fitur ini juga mencakup:
1. **Lookup Modal MST_Account**: Integrasi dengan Buku Besar (*General Ledger / MST_Account*) melalui popup pencarian interaktif (berdasarkan kode atau nama akun), bersifat opsional (*dapat dikosongkan*), dan hanya dapat memilih 1 akun per metode pembayaran.
2. **Soft Delete**: Data metode pembayaran tidak pernah dihapus secara permanen dari database (*hard delete* dilarang), melainkan di-soft delete dengan mengubah status `is_active` menjadi `FALSE` agar tidak merusak data historis transaksi.
3. **Timestamp UTC**: Setiap perubahan mencatat waktu perubahan terakhir pada field `updated_at` dalam format UTC secara otomatis.
4. **Isolasi Privasi Template (User Isolation)**: Pengguna dapat membuat template metode pembayaran untuk dirinya sendiri. **User TIDAK DAPAT melihat template payment method milik user lain**, kecuali jika pembuat template secara sengaja menandainya sebagai template publik (`is_public = TRUE`). Template privat milik user lain dilarang keras bocor di API maupun UI.
5. **Preview Sebelum Copy Template**: Saat pengguna ingin menyalin (*copy*) template publik, sistem wajib menyediakan tampilan **Preview Isi Template** terlebih dahulu. Pengguna dapat meninjau rincian kode, nama, akun GL, dan indikator deteksi konflik kode sebelum memutuskan untuk mengonfirmasi penyalinan.

---

## 2. Perubahan Skema Database (Database & Models)

### A. Model `PaymentMethod` (`backend/app/models/finance.py`)
Tabel `payment_methods` harus diperbarui dari yang sebelumnya bersifat global menjadi *user-scoped*, mendukung soft delete, dan mendukung template.

#### Kolom & Tipe Data:
| Kolom | Tipe Data | Nullable | Default | Keterangan |
| :--- | :--- | :---: | :---: | :--- |
| `id` | `UUID` | No | `uuid.uuid4` | Primary Key |
| `user_id` | `UUID` | **Yes** | `None` | FK ke `users.id` (ON DELETE CASCADE). `NULL` hanya untuk template bawaan sistem (*system default*) |
| `code` | `VARCHAR(30)` | No | - | Kode metode (misal: `CASH`, `BCA`, `GOPAY`) |
| `name` | `VARCHAR(100)`| No | - | Deskripsi / nama lengkap metode pembayaran |
| `from_account` | `VARCHAR(10)` | **Yes** | `None` | FK ke `mst_account.account`. **Dapat dikosongkan (nullable)** |
| `is_active` | `BOOLEAN` | No | `True` | Status aktif. Jika `FALSE`, tidak muncul pada opsi transaksi (soft delete) |
| `is_template` | `BOOLEAN` | No | `False` | Menandakan apakah baris data ini merupakan template konfigurasi |
| `is_public` | `BOOLEAN` | No | `False` | Jika `is_template = True` dan `is_public = True`, dapat dilihat & di-copy oleh user lain |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | No | `func.now()` | Waktu pembuatan (UTC) |
| `updated_at` | `TIMESTAMP WITH TIME ZONE` | No | `func.now()` | Waktu pembaruan terakhir (UTC, `onupdate=func.now()`) |

#### Aturan Constraint Database:
1. **Hapus Unique Global pada `code`**: Hapus `unique=True` pada kolom `code` karena user A dan user B dapat menggunakan kode yang sama (misal sama-sama punya `CASH`).
2. **Composite Unique Index**:
   Gunakan partial unique index atau composite constraint agar kode tidak duplikat dalam satu user untuk tipe yang sama:
   - Satu user tidak boleh memiliki dua metode aktif dengan `code` yang sama jika `is_template = False`.
   - Di SQLAlchemy:
     ```python
     __table_args__ = (
         UniqueConstraint('user_id', 'code', 'is_template', name='uq_user_payment_method_code'),
     )
     ```
3. **Foreign Key `from_account`**:
   Harus diubah menjadi `nullable=True` (karena akun GL bersifat opsional/dapat dikosongkan).

### B. Pembaruan Seed Data (`backend/init_db.py`)
Pada fungsi `seed_data()` di `init_db.py`:
- Buat metode pembayaran default sistem dengan `user_id = None`, `is_template = True`, dan `is_public = True` agar dapat di-copy oleh user baru sebagai template dasar.
- Atau kaitkan metode pembayaran default ke akun `admin_user.id` yang sudah di-seed.

---

## 3. Spesifikasi Backend API (FastAPI)

Semua endpoint berikut dilindungi oleh autentikasi (`Depends(get_current_user)`).

### A. DTO / Schema Pydantic (`backend/app/schemas/finance.py`)

```python
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from uuid import UUID

# Schema Lookup MST_Account
class AccountLookupResponse(BaseModel):
    account: str
    description: str
    type: str
    active: bool

    class Config:
        from_attributes = True

# Schema Payment Method
class PaymentMethodCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=30)
    name: str = Field(..., min_length=2, max_length=100)  # Deskripsi
    from_account: Optional[str] = Field(None, max_length=10)
    is_active: bool = True
    is_template: bool = False
    is_public: bool = False

class PaymentMethodUpdate(BaseModel):
    code: Optional[str] = Field(None, min_length=2, max_length=30)
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    from_account: Optional[str] = Field(None, max_length=10)
    is_active: Optional[bool] = None
    is_template: Optional[bool] = None
    is_public: Optional[bool] = None

class PaymentMethodResponse(BaseModel):
    id: UUID
    user_id: Optional[UUID] = None
    code: str
    name: str
    from_account: Optional[str] = None
    account_description: Optional[str] = None
    is_active: bool
    is_template: bool
    is_public: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
```

---

### B. Endpoints CRUD Payment Method (`backend/app/api/v1/finance.py`)

#### 1. List Payment Methods Pengguna
- **Method**: `GET`
- **Endpoint**: `/api/v1/payment-methods`
- **Query Params**:
  - `include_inactive: bool = False` (Jika `false`, hanya ambil yang `is_active == True` untuk dropdown transaksi. Jika `true`, ambil semua untuk halaman manajemen).
  - `is_template: bool = False` (Default `false` untuk mengambil metode pembayaran operasional milik user).
- **Logika Query**:
  - Filter `PaymentMethod.user_id == current_user.id` dan `PaymentMethod.is_template == is_template`.
  - Gunakan `outerjoin` ke `MST_Account` pada `PaymentMethod.from_account == MST_Account.account` (karena `from_account` nullable).
  - Jika `include_inactive == False`, tambahkan filter `PaymentMethod.is_active == True`.
- **Response (200 OK)**:
```json
{
  "success": true,
  "data": [
    {
      "id": "c0414523-6f56-4031-af46-474bcdb24b16",
      "user_id": "79482327-cf22-442a-9ca7-5e34f09d10fd",
      "code": "BCA",
      "name": "Bank Central Asia",
      "from_account": "1002",
      "account_description": "Bank Operasional",
      "is_active": true,
      "is_template": false,
      "is_public": false,
      "created_at": "2026-09-16T12:00:00Z",
      "updated_at": "2026-09-16T12:00:00Z"
    }
  ]
}
```

#### 2. Tambah Payment Method Baru
- **Method**: `POST`
- **Endpoint**: `/api/v1/payment-methods`
- **Request Body**: `PaymentMethodCreate`
- **Aturan Validasi**:
  1. Uppercase untuk `code` (`code.strip().upper()`).
  2. Cek apakah user sudah memiliki `code` yang sama dengan nilai `is_template` yang sama (`where(user_id == current_user.id, code == code_upper, is_template == body.is_template)`). Jika ada, kembalikan `HTTP 409 Conflict` ("Kode metode pembayaran sudah digunakan.").
  3. Jika `from_account` diisi, validasi apakah akun tersebut ada di tabel `mst_account`. Jika tidak ditemukan, kembalikan `HTTP 400 Bad Request` ("Akun GL tidak valid.").
  4. Simpan dengan `user_id = current_user.id`, `created_at = datetime.now(timezone.utc)`, dan `updated_at = datetime.now(timezone.utc)`.
- **Response (201 Created)**: Mengembalikan `PaymentMethodResponse`.

#### 3. Edit Payment Method
- **Method**: `PUT`
- **Endpoint**: `/api/v1/payment-methods/{id}`
- **Path Parameter**: `id` (UUID)
- **Request Body**: `PaymentMethodUpdate`
- **Aturan Validasi**:
  1. Cari record `PaymentMethod` berdasarkan `id` dan `user_id == current_user.id`. Jika tidak ditemukan, kembalikan `HTTP 404 Not Found` ("Metode pembayaran tidak ditemukan atau Anda tidak memiliki hak akses.").
  2. Jika mengubah `code`, pastikan tidak duplikat dengan record lain milik user yang sama.
  3. Jika `from_account` diubah (dan tidak null), validasi keberadaannya di `mst_account`.
  4. Perbarui nilai field yang disertakan, dan otomatis set `updated_at = datetime.now(timezone.utc)`.
  5. `db.commit()` dan `db.refresh()`.
- **Response (200 OK)**: Mengembalikan data terbaru `PaymentMethodResponse`.

#### 4. Soft Delete Payment Method
- **Method**: `DELETE`
- **Endpoint**: `/api/v1/payment-methods/{id}`
- **Path Parameter**: `id` (UUID)
- **Aturan Bisnis (Wajib Soft Delete)**:
  1. **Dilarang melakukan `db.delete(item)`!**
  2. Cari item berdasarkan `id` dan `user_id == current_user.id`. Jika tidak ada, `HTTP 404 Not Found`.
  3. Ubah status:
     - `item.is_active = False`
     - `item.updated_at = datetime.now(timezone.utc)`
  4. Lakukan `await db.commit()`.
- **Response (200 OK)**:
```json
{
  "success": true,
  "message": "Metode pembayaran berhasil dinonaktifkan (soft deleted)."
}
```

---

### C. Endpoints Fitur Template & Copy Template

> 🔒 **Aturan Ketat Privasi Template (Strict Privacy Rule)**:
> - **User TIDAK DAPAT melihat template payment method milik user lain** kecuali jika template tersebut ditandai publik (`is_public == True`).
> - Query template pribadi user (`GET /api/v1/payment-methods?is_template=true`) **WAJIB** memfilter `user_id == current_user.id`. User tidak boleh melihat template privat pengguna lain.
> - Akses langsung via ID ke template privat user lain harus menghasilkan `HTTP 404 Not Found` atau `HTTP 403 Forbidden`.

#### 1. List Template Publik
- **Method**: `GET`
- **Endpoint**: `/api/v1/payment-methods/templates/public`
- **Akses**: Authenticated User
- **Logika Query**:
  - Ambil record di mana `PaymentMethod.is_template == True` dan `PaymentMethod.is_public == True` (termasuk template default sistem `user_id == None`).
  - Template milik user lain yang berstatus `is_public == False` **DILARANG KERAS** muncul di sini.
  - Lakukan outerjoin ke `MST_Account` untuk mendapatkan keterangan akun.
- **Response (200 OK)**: Daftar template publik yang tersedia untuk disalin.

#### 2. Preview Template Sebelum Copy
- **Method**: `GET`
- **Endpoint**: `/api/v1/payment-methods/templates/{template_id}/preview`
- **Akses**: Authenticated User
- **Path Parameter**: `template_id` (UUID)
- **Tujuan**: Memungkinkan user melihat pratinjau isi template secara lengkap dan memeriksa apakah ada potensi konflik kode sebelum menyalin data.
- **Aturan Validasi**:
  1. Cari template dengan `id == template_id`, `is_template == True`, dan (`is_public == True` ATAU `user_id == current_user.id`).
  2. Jika template adalah privat milik user lain, kembalikan `HTTP 404 Not Found` / `403 Forbidden` ("Template tidak ditemukan atau bersifat privat.").
  3. Cek apakah pemohon sudah memiliki metode pembayaran operasional (`is_template == False`) dengan kode yang sama:
     - `existing = select(PaymentMethod).where(user_id == current_user.id, code == template.code, is_template == False)`
     - `is_code_conflict = True` jika ditemukan, selain itu `False`.
- **Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "id": "c0414523-6f56-4031-af46-474bcdb24b16",
    "code": "BCA",
    "name": "Bank Central Asia",
    "from_account": "1002",
    "account_description": "Bank Operasional",
    "is_active": true,
    "is_public": true,
    "is_code_conflict": true,
    "conflict_message": "Kode 'BCA' sudah terdaftar pada metode pembayaran Anda. Menyalin template ini akan memberi akhiran _COPY pada kode."
  }
}
```

#### 3. Copy Template Publik
- **Method**: `POST`
- **Endpoint**: `/api/v1/payment-methods/templates/{template_id}/copy`
- **Akses**: Authenticated User
- **Path Parameter**: `template_id` (UUID)
- **Aturan Bisnis**:
  1. Cari template berdasarkan `id == template_id`, `is_template == True`, dan (`is_public == True` ATAU `user_id == current_user.id`). Jika privat milik user lain, kembalikan `HTTP 404 Not Found` / `403 Forbidden`.
  2. Periksa apakah user pemohon sudah memiliki metode operasional (`is_template == False`) dengan `code` yang sama.
     - Jika ada konflik: Buat kode baru dengan menambahkan akhiran (misal `BCA_COPY`) atau berikan error `HTTP 409 Conflict` sesuai konfirmasi di preview.
  3. Buat record baru di `payment_methods`:
     - `user_id = current_user.id`
     - `code = new_code`
     - `name = template.name`
     - `from_account = template.from_account`
     - `is_active = True`
     - `is_template = False`
     - `is_public = False`
     - `created_at = datetime.now(timezone.utc)`
     - `updated_at = datetime.now(timezone.utc)`
  4. `db.add(new_item)` dan `await db.commit()`.
- **Response (201 Created)**: Mengembalikan objek hasil copy.

---

### D. Endpoint Lookup Akun GL (`backend/app/api/v1/finance.py`)

- **Method**: `GET`
- **Endpoint**: `/api/v1/accounts/lookup`
- **Akses**: Authenticated User
- **Query Params**:
  - `q: Optional[str] = None` (Filter pencarian berdasarkan `account` atau `description`)
- **Logika Query**:
  - `select(MST_Account).where(MST_Account.active == True)`
  - Jika `q` diisi: filter `or_(MST_Account.account.ilike(f"%{q}%"), MST_Account.description.ilike(f"%{q}%"))`.
- **Response (200 OK)**:
```json
{
  "success": true,
  "data": [
    {
      "account": "1001",
      "description": "Kas Utama",
      "type": "Debit",
      "active": true
    },
    {
      "account": "1002",
      "description": "Bank Operasional",
      "type": "Debit",
      "active": true
    }
  ]
}
```

---

## 4. Spesifikasi Frontend (Flutter & BLoC)

### A. Model & Data Layer
1. **Model `PaymentMethod` (`frontend/lib/features/finance/domain/models.dart`)**:
   - Perbarui class `PaymentMethod`:
     ```dart
     class PaymentMethod {
       final String id;
       final String? userId;
       final String code;
       final String name; // Deskripsi
       final String? fromAccount;
       final String? accountDescription;
       final bool isActive;
       final bool isTemplate;
       final bool isPublic;
       final DateTime? createdAt;
       final DateTime? updatedAt;
       // fromJson & copyWith
     }
     ```
2. **Model `MSTAccount`**:
   - Model untuk menampung data lookup akun: `account`, `description`, `type`, `active`.
3. **Repository `FinanceRepository` (`frontend/lib/features/finance/data/finance_repository.dart`)**:
   - `Future<List<PaymentMethod>> getPaymentMethods({bool includeInactive = false, bool isTemplate = false})`
   - `Future<List<PaymentMethod>> getPublicTemplates()`
   - `Future<PaymentMethod> createPaymentMethod({...})`
   - `Future<PaymentMethod> updatePaymentMethod({required String id, ...})`
   - `Future<void> softDeletePaymentMethod(String id)`
   - `Future<Map<String, dynamic>> previewTemplate(String templateId)`
   - `Future<PaymentMethod> copyTemplate(String templateId)`
   - `Future<List<MSTAccount>> lookupAccounts({String? query})`

---

### B. State Management (`PaymentMethodBloc`)
- **Lokasi**: `frontend/lib/features/finance/presentation/bloc/payment_method_bloc.dart`
- **Events**:
  - `PaymentMethodFetchRequested({bool includeInactive = true})`
  - `PaymentMethodCreateRequested(...)`
  - `PaymentMethodUpdateRequested(...)`
  - `PaymentMethodSoftDeleteRequested(String id)`
  - `PaymentMethodCopyTemplateRequested(String templateId)`
  - `PaymentMethodTemplatesFetchRequested()`
- **States**:
  - `PaymentMethodInitial`
  - `PaymentMethodLoading`
  - `PaymentMethodLoaded({required List<PaymentMethod> methods, List<PaymentMethod> templates})`
  - `PaymentMethodOperationSuccess(String message)`
  - `PaymentMethodError(String errorMessage)`

---

### C. Antarmuka Pengguna (UI Screens & Widgets)

#### 1. Halaman Utama: `PaymentMethodManagementScreen`
- **File**: `frontend/lib/features/finance/presentation/screens/payment_method_management_screen.dart`
- **Struktur Tampilan**:
  - **TabBar** dengan 2 Tab:
    1. **Tab "Metode Pembayaran Saya"**:
       - Filter Switch: "Tampilkan yang Nonaktif / Terhapus".
       - Daftar card / DataTable berisi:
         - **Kode** (misal: `BCA`, `CASH`)
         - **Deskripsi** (nama metode)
         - **Akun GL Terhubung** (`1001 - Kas Utama` atau badge abu-abu `- Kosong -` jika null)
         - **Status Aktif**: Switch / Chip (`Aktif` hijau, `Nonaktif` merah)
         - **Terakhir Diperbarui**: Tanggal & jam UTC (`YYYY-MM-DD HH:mm UTC`)
         - **Aksi**: Tombol Edit (icon pensil) & Tombol Nonaktifkan/Soft Delete (icon tempat sampah).
       - Floating Action Button (FAB): *"+ Tambah Metode"*.
    2. **Tab "Template Publik"**:
       - **Aturan Privasi**: Hanya menampilkan template yang berstatus publik (`is_public == True`). User **TIDAK BISA** melihat template privat milik user lain.
       - Daftar kartu template publik yang tersedia.
       - Menampilkan nama template, kode, akun GL default, dan badge publik.
       - Tombol **"Lihat & Salin" / "Copy Template"** pada masing-masing kartu yang memicu **Modal Pratinjau Template** terlebih dahulu.

#### 2. Dialog Form Input / Edit Payment Method:
- Form fields:
  - **Kode**: TextFormField (TextCapitalization characters, max 30 karakter).
  - **Deskripsi / Nama**: TextFormField (Wajib diisi).
  - **Akun GL (From Account)**:
    - Input readonly yang menampilkan nilai terpilih (`1001 - Kas Utama`) atau keterangan `Belum dipilih (Opsional)`.
    - Tombol aksi:
      - Icon Search: Membuka **Popup Lookup MST_Account**.
      - Icon Clear/Hapus (jika sudah ada yang dipilih): Mengosongkan pilihan menjadi `null`.
  - **Checkbox / Switch `is_active`**:
    - Label: "Status Aktif (Dapat digunakan dalam transaksi)".
  - **Opsi Template**:
    - Checkbox: *"Simpan sebagai Template"* (`is_template`).
    - Checkbox: *"Jadikan Template Publik (Dapat disalin user lain)"* (Hanya aktif jika opsi template dicentang).
  - Tombol **Batal** dan **Simpan**.

#### 3. Modal / Dialog Lookup MST_Account (`MSTAccountLookupDialog`):
- **Tampilan**:
  - Title: *"Pilih Akun Buku Besar (MST_Account)"*.
  - Subtitle: *"Opsional - Hanya dapat memilih 1 akun"*.
  - Search Bar dengan `debounce` pencarian teks.
  - List item akun menampilkan:
    - Nomor Akun (`account`) tebal.
    - Nama Akun (`description`).
    - Badge Tipe (`Debit` / `Credit`).
  - Aksi Klik: Mengklik salah satu baris langsung memilih akun tersebut, menutup dialog, dan mengisi form utama.
  - Tombol *"Batal"* atau *"Tanpa Akun (Kosongkan)"*.

#### 4. Konfirmasi Soft Delete:
- Menampilkan Dialog peringatan ramah:
  > *"Apakah Anda yakin ingin menonaktifkan metode pembayaran [KODE]? Metode ini tidak akan bisa dipilih lagi pada formulir transaksi baru, namun data transaksi lama tetap aman."*
- Tombol: **Batal** dan **Nonaktifkan**.
- Saat dikonfirmasi, kirim event `PaymentMethodSoftDeleteRequested` yang memanggil `DELETE /api/v1/payment-methods/{id}`.

#### 5. Modal Pratinjau Template Sebelum Copy (`TemplateCopyPreviewDialog`):
- **Tujuan**: Memastikan user dapat mem-preview isi template sebelum disalin ke daftar metode pembayaran aktif miliknya.
- **Tampilan Dialog**:
  - Judul: *"Pratinjau Template Metode Pembayaran"*.
  - Isi Pratinjau:
    - **Kode**: Menampilkan kode template (misal: `BCA`).
    - **Deskripsi / Nama**: Menampilkan nama lengkap (misal: `Bank Central Asia`).
    - **Akun GL Terhubung**: Menampilkan kode & deskripsi akun GL (misal: `1002 - Bank Operasional`) atau chip abu-abu *"Tanpa Akun GL"*.
    - **Status Target**: Otomatis diset menjadi *"Aktif"* setelah disalin.
  - **Pengecekan / Deteksi Konflik Kode**:
    - Jika user pemohon sudah memiliki metode pembayaran dengan kode yang sama, tampilkan Alert Box / Banner kuning:
      > *"⚠️ Perhatian: Kode '[KODE]' sudah ada pada daftar metode pembayaran Anda. Setelah disalin, kode akan otomatis disesuaikan menjadi '[KODE]_COPY'."*
  - Tombol Aksi:
    - **Batal**: Menutup modal tanpa menyalin.
    - **Salin Sekarang / Konfirmasi**: Memanggil API copy template dan menambahkan data ke daftar metode pembayaran user.

---

## 5. Pembaruan File Dokumentasi Wajib

Setelah pengerjaan selesai, developer/AI wajib memperbarui file dokumentasi proyek:
1. **`docs/table.md`**:
   - Perbarui deskripsi tabel `payment_methods`:
     - Tambahkan kolom `user_id`, `is_template`, `is_public`, `created_at`, dan `updated_at`.
     - Ubah keterangan kolom `from_account` menjadi `Nullable`.
     - Perbarui aturan relasi pada diagram Mermaid.
2. **`docs/routes.md`**:
   - Tambahkan seluruh endpoint CRUD dan template `/api/v1/payment-methods`.
   - Tambahkan rute endpoint preview `/api/v1/payment-methods/templates/{template_id}/preview`.
   - Tambahkan rute endpoint lookup `/api/v1/accounts/lookup`.
   - Tambahkan navigasi `PaymentMethodManagementScreen` pada daftar rute Flutter.
3. **`docs/features.md`**:
   - Ubah status fitur **Payment Methods & GL Mapping** dari `🟡 Parsial` menjadi `🟢 Selesai`.
   - Perbarui catatan rincian fitur di bagian bawah.

---

## 6. Kriteria Penerimaan (Definition of Done / DoD)

### Backend:
- [ ] Kolom `user_id`, `is_template`, `is_public`, `created_at`, dan `updated_at` terpasang di model `PaymentMethod`.
- [ ] Kolom `from_account` bersifat `nullable=True`.
- [ ] Query daftar metode pembayaran memfilter data berdasarkan user yang sedang login (`current_user.id`), kecuali untuk template publik.
- [ ] **Isolasi Privasi**: User **TIDAK BISA** melihat template privat milik user lain (hanya melihat template miliknya sendiri atau template berstatus `is_public == True`).
- [ ] Validasi kode duplikat bersifat per-user (bukan lagi global unique).
- [ ] `DELETE /api/v1/payment-methods/{id}` melakukan **soft delete** (mengubah `is_active = False` dan memperbarui `updated_at` dalam UTC), tidak menghapus baris data di database.
- [ ] Endpoint `/api/v1/payment-methods/templates/{template_id}/preview` menyajikan pratinjau isi template dan mendeteksi potensi konflik kode.
- [ ] Endpoint `/api/v1/payment-methods/templates/public` hanya mengembalikan template yang berstatus `is_public == True`.
- [ ] Endpoint Copy Template menduplikasi data template menjadi metode pembayaran operasional milik pemohon (`is_template = False`, `user_id = current_user.id`).
- [ ] Endpoint `/api/v1/accounts/lookup` berfungsi untuk mencari akun GL berdasarkan kode maupun deskripsi.
- [ ] Dropdown transaksi di `/api/v1/payment-methods?include_inactive=false` hanya menampilkan metode aktif (`is_active == True`).
- [ ] Database re-seed via `python init_db.py` berjalan tanpa error.

### Frontend:
- [ ] Tersedia halaman `PaymentMethodManagementScreen` dengan navigasi dari Dashboard / Menu Pengaturan.
- [ ] Terdapat Tab untuk metode pembayaran user dan Tab untuk template publik.
- [ ] Di Tab template publik, hanya template publik yang terlihat. Template privat user lain tidak dapat dilihat sama sekali.
- [ ] Form Tambah/Edit memiliki popup lookup akun GL (`MST_Account`) yang mendukung pencarian kode dan deskripsi akun.
- [ ] Akun GL dapat dikosongkan (opsional) pada form.
- [ ] **Preview Sebelum Copy**: Menekan tombol salin template pada Tab Template Publik menampilkan dialog pratinjau (`TemplateCopyPreviewDialog`) yang memperlihatkan isi template dan peringatan jika terjadi konflik kode.
- [ ] Aksi hapus menampilkan dialog konfirmasi penonaktifan (soft delete).
- [ ] Nilai `updated_at` ditampilkan dalam format waktu lokal atau UTC yang informatif.
- [ ] Form input transaksi (Add Expense) tidak lagi menampilkan metode pembayaran yang berstatus nonaktif (`is_active == False`).
- [ ] Lulus validasi statis Flutter (`flutter analyze` tanpa warning/error).
