# Issue: Transaction History & Deleted Transactions Audit Log

## 1. Ringkasan Fitur & Latar Belakang
Fitur **Transaction History** adalah halaman yang memuat daftar lengkap riwayat transaksi keuangan yang telah diinput oleh pengguna (melalui fitur Input Transaksi). Selain melihat riwayat transaksi aktif, pengguna juga dapat melakukan penyaringan (*filtering*), pengubahan (*edit*), dan penghapusan (*delete*) transaksi.

Untuk kebutuhan audit dan keamanan data finansial, setiap transaksi yang dihapus tidak langsung hilang permanen begitu saja, melainkan dipindahkan/disimpan ke dalam tabel log khusus yaitu **`deleted_transactions`**. Pengguna dapat melihat daftar transaksi yang pernah mereka hapus melalui halaman **View Deleted Transactions**.

Selain itu, setiap transaksi memiliki status **`processed`** (tipe data Boolean dengan nilai default `FALSE`). Kolom ini bersifat **read-only bagi user (tidak dapat diedit)** dan wajib ditampilkan pada halaman riwayat transaksi dalam bentuk **checkbox**.

### 🔑 Aturan Utama & Hak Akses (Multi-Tenancy Isolation):
1. **Autentikasi Wajib**: Halaman ini hanya dapat diakses oleh user yang telah login (`get_current_user`).
2. **Isolasi Data Antar Pengguna**: User A **TIDAK BISA** melihat, mengedit, menghapus, atau mengakses riwayat transaksi maupun log transaksi terhapus milik User B (`user_id == current_user.id`).
3. **Kolom `processed`**:
   - Kolom berjenis `Boolean` dengan nilai bawaan `FALSE`.
   - Bersifat **sistemik / read-only bagi user** (pengguna dilarang mengubah status ini secara manual melalui form/modal edit).
   - Ditampilkan pada tabel / list transaksi dalam bentuk **Checkbox** (non-interactive / read-only).
4. **Validasi Hapus (Delete Guard)**:
   - Transaksi dengan status **`processed = TRUE` TIDAK DAPAT DIHAPUS** oleh user.
   - Usaha penghapusan transaksi terproses wajib digagalkan oleh backend dengan pesan error penolakan.
5. **Audit Trail Log**: 
   - Setiap operasi edit transaksi wajib memperbarui kolom `updated_at` dengan timestamp terkini (UTC).
   - Setiap operasi hapus transaksi (yang berstatus `processed = FALSE`) wajib menyalin data transaksi ke tabel `deleted_transactions` beserta informasi waktu penghapusan (`deleted_at`) dan identitas user yang menghapus (`deleted_by`), sebelum data transaksi dihapus dari tabel `transactions`.

---

## 2. Kebutuhan Fungsional & Logika Bisnis

### A. Fitur Filter pada Halaman Transaction History
Halaman riwayat transaksi wajib menyediakan filter dinamis dengan tombol *Reset Filter* dan *Apply Filter*:
1. **Filter by `transaction_date` (Rentang Tanggal)**:
   - Disediakan dalam bentuk **Date Picker** (atau *Date Range Picker*: `start_date` dan `end_date`).
   - Menyaring transaksi berdasarkan rentang tanggal terjadinya transaksi.
2. **Filter by `type` (Tipe Transaksi)**:
   - Input/Dropdown pemilih tipe transaksi dengan opsi lookup ke master/daftar tipe yang pernah digunakan atau enum (misal: `EXPENSE`, `INCOME`, atau custom type). Menyediakan opsi "Semua Tipe".
3. **Filter by `notes` (Catatan)**:
   - Input teks pencarian (*search field*) yang melakukan pencarian substring (case-insensitive) pada catatan transaksi.
4. **Filter by `payment_method` (Metode Pembayaran)**:
   - Tombol/Input lookup value yang membuka popup modal daftar metode pembayaran aktif milik user (`PaymentMethodLookupDialog`), memungkinkan user memilih metode pembayaran spesifik untuk memfilter transaksi.

### B. Tampilan Tabel & Kolom `processed`
- Setiap baris transaksi di halaman Transaction History menampilkan kolom:
  - **Processed**: Komponen **`Checkbox`** (bersifat read-only / `onChanged: null`) yang merefleksikan nilai `processed` (centang jika `True`, tidak tercentang jika `False`).
  - **Tanggal Transaksi (`transaction_date`)**
  - **Tipe Transaksi (`type`)**
  - **Nominal & Mata Uang (`amount` & `currency_code`)**
  - **Nominal Base Currency (`amount_in_base_currency`)**
  - **Metode Pembayaran (`payment_method`)**
  - **Catatan (`notes`)**
  - **Aksi**: Tombol Edit & Hapus (tombol Hapus di-disable jika `processed == True`).

### C. Fitur Aksi Transaksi (Edit & Hapus)
1. **Edit Transaksi**:
   - Tombol aksi di setiap baris/kartu transaksi untuk memunculkan dialog/modal edit (`EditTransactionDialog`).
   - Field yang dapat diubah: `type`, `amount`, `currency_code`, `payment_method_id`, `notes`, dan `transaction_date`.
   - **PROTEKSI FIELD**: Kolom `processed` **TIDAK BOLEH** dapat diedit oleh user pada form ini.
   - **Kalkulasi Kurs Otomatis**: Jika `amount` atau `currency_code` diubah, `amount_in_base_currency` wajib dikalkulasi ulang secara realtime menggunakan exchange rate terkini.
   - **Validasi Backdate**: `transaction_date` tetap tunduk pada aturan validasi ketat: **hanya boleh backdate** (tidak boleh tanggal masa depan / *future date*).
   - **Pembaruan Timestamp**: Kolom `updated_at` otomatis terupdate ke timestamp saat perubahan disimpan.
2. **Hapus Transaksi (dengan Validasi `processed = TRUE`)**:
   - **PENTING - Delete Guard**:
     - Sistem wajib mengecek nilai `processed` sebelum memproses penghapusan.
     - Jika transaksi bernilai **`processed = TRUE`**, sistem **DILARANG MENGHAPUS** transaksi dan wajib mengembalikan pesan kesalahan (*HTTP 400 Bad Request*): `"Transaksi yang sudah diproses tidak dapat dihapus."`.
   - Jika `processed = FALSE`:
     - Tampilkan konfirmasi pop-up (*Confirmation Dialog*): "Apakah Anda yakin ingin menghapus transaksi ini? Data yang dihapus akan dipindahkan ke riwayat transaksi terhapus."
     - Saat dikonfirmasi:
       - Sistem membuat *record* baru di tabel `deleted_transactions` yang menampung seluruh *snapshot* data transaksi terkait (termasuk status `processed = FALSE`), `deleted_at = now(utc)`, dan `deleted_by = current_user.id`.
       - Sistem menghapus *record* transaksi tersebut dari tabel `transactions`.
       - Menampilkan notifikasi sukses dan memperbarui tabel riwayat transaksi secara otomatis.

### D. Halaman View Deleted Transactions
- Halaman/layar khusus (atau sub-view/modal) yang dapat diakses melalui tombol navigasi di halaman Transaction History (misal: tombol "Riwayat Terhapus" / "Trash Log").
- Menampilkan daftar transaksi yang telah dihapus milik pengguna saat ini.
- Bersifat **Read-Only** (hanya untuk melihat informasi historis transaksi yang pernah dihapus).
- Menampilkan kolom: ID transaksi asli, Status Processed (Checkbox/Label), Tipe, Nominal, Mata Uang, Nilai dalam Base Currency, Metode Pembayaran, Catatan, Tanggal Transaksi, dan Waktu Dihapus (`deleted_at`).

---

## 3. Perubahan Skema Database (Database & Models)

### A. Perbarui Model `Transaction` (`backend/app/models/finance.py`)
Tambahkan kolom `processed` pada model `Transaction`:
```python
class Transaction(Base):
    __tablename__ = "transactions"

    # ... kolom eksisting ...
    processed = Column(Boolean, default=False, nullable=False)
```

### B. Tambah Model `DeletedTransaction` (`backend/app/models/finance.py`)
Tambahkan model tabel `deleted_transactions` ke dalam `backend/app/models/finance.py`:

```python
class DeletedTransaction(Base):
    __tablename__ = "deleted_transactions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    original_transaction_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    
    type = Column(String(50), nullable=True)
    currency_code = Column(String(3), ForeignKey("currencies.code"), nullable=False)
    amount = Column(Numeric(15, 2), nullable=False)
    exchange_rate = Column(Numeric(18, 6), nullable=False)
    amount_in_base_currency = Column(Numeric(15, 2), nullable=False)
    payment_method_id = Column(UUID(as_uuid=True), nullable=True) # Dapat nullable jika metode pembayaran aslinya terhapus
    payment_method_name = Column(String(100), nullable=True) # Snapshot nama metode pembayaran
    notes = Column(Text, nullable=True)
    processed = Column(Boolean, default=False, nullable=False) # Snapshot status processed saat dihapus
    
    transaction_date = Column(DateTime(timezone=True), nullable=False)
    original_created_at = Column(DateTime(timezone=True), nullable=False)
    original_updated_at = Column(DateTime(timezone=True), nullable=False)
    
    deleted_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    deleted_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
```

### C. Sinkronisasi Skrip Database
- Pastikan model `DeletedTransaction` terdaftar di `backend/init_db.py` dan `reset_db.py` sehingga tabel terbuat saat sinkronisasi ulang database (`python reset_db.py ; python init_db.py`).

---

## 4. Desain Backend API (FastAPI)

### A. Pydantic Schemas (`backend/app/schemas/finance.py`)

Tambahkan/perbarui skema untuk Update, Response, dan Filter:

```python
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, Field, field_validator

class TransactionCreate(BaseModel):
    type: Optional[str] = Field(None, max_length=50)
    currency_code: str = Field(..., min_length=3, max_length=3)
    amount: Decimal = Field(..., gt=0)
    payment_method_id: UUID
    notes: Optional[str] = None
    transaction_date: Optional[datetime] = None
    # Catatan: 'processed' TIDAK dimasukkan ke TransactionCreate, default server adalah False

class TransactionUpdate(BaseModel):
    type: Optional[str] = Field(None, max_length=50)
    currency_code: Optional[str] = Field(None, min_length=3, max_length=3)
    amount: Optional[Decimal] = Field(None, gt=0)
    payment_method_id: Optional[UUID] = None
    notes: Optional[str] = None
    transaction_date: Optional[datetime] = None
    # PENTING: 'processed' TIDAK boleh dimasukkan ke TransactionUpdate karena tidak dapat diedit oleh user

    @field_validator("transaction_date")
    @classmethod
    def validate_backdate_only(cls, v: Optional[datetime]) -> Optional[datetime]:
        if v is not None:
            now_utc = datetime.now(timezone.utc)
            target_dt = v if v.tzinfo is not None else v.replace(tzinfo=timezone.utc)
            if target_dt > (now_utc + timedelta(minutes=5)):
                raise ValueError("Tanggal transaksi tidak boleh di masa depan (hanya backdate yang diizinkan).")
        return v

class TransactionResponse(BaseModel):
    id: UUID
    type: Optional[str] = None
    currency_code: str
    amount: Decimal
    exchange_rate: Decimal
    amount_in_base_currency: Decimal
    payment_method: PaymentMethodResponse
    notes: Optional[str]
    processed: bool = False # Field status processed
    transaction_date: datetime
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class DeletedTransactionResponse(BaseModel):
    id: UUID
    original_transaction_id: UUID
    user_id: UUID
    type: Optional[str]
    currency_code: str
    amount: Decimal
    exchange_rate: Decimal
    amount_in_base_currency: Decimal
    payment_method_id: Optional[UUID]
    payment_method_name: Optional[str]
    notes: Optional[str]
    processed: bool = False
    transaction_date: datetime
    original_created_at: datetime
    original_updated_at: datetime
    deleted_at: datetime

    class Config:
        from_attributes = True
```

### B. REST API Endpoints (`backend/app/api/v1/finance.py`)

Implementasikan endpoint-endpoint berikut dengan proteksi `current_user: User = Depends(get_current_user)`:

#### 1. `GET /api/v1/transactions`
- **Tujuan**: Mengambil daftar transaksi aktif milik pengguna yang sedang login dengan dukungan filtering.
- **Query Parameters**:
  - `start_date` (Optional[datetime]): Filter tanggal awal transaksi (`transaction_date >= start_date`).
  - `end_date` (Optional[datetime]): Filter tanggal akhir transaksi (`transaction_date <= end_date`).
  - `type` (Optional[str]): Filter exact/case-insensitive match tipe transaksi.
  - `notes` (Optional[str]): Filter substring pencarian pada `notes` (`notes ILIKE '%notes%'`).
  - `payment_method_id` (Optional[UUID]): Filter berdasarkan ID metode pembayaran.
  - `skip` (int = 0, ge=0) dan `limit` (int = 50, le=100) untuk pagination.
- **Query Constraints**: Wajib menyertakan filter `Transaction.user_id == current_user.id`, diurutkan berdasarkan `Transaction.transaction_date.desc()`.
- **Response**: List of `TransactionResponse` (atau dictionary berisikan data transaksi lengkap dengan field `processed`).

#### 2. `GET /api/v1/transactions/{id}`
- **Tujuan**: Mengambil detail satu transaksi aktif.
- **Validasi**: Pastikan `transaction.user_id == current_user.id`, jika tidak ditemukan kembalikan HTTP 404.

#### 3. `PUT /api/v1/transactions/{id}`
- **Tujuan**: Memperbarui transaksi yang ada.
- **Body**: `TransactionUpdate`
- **Logika**:
  - Cek keberadaan transaksi dan pastikan `transaction.user_id == current_user.id`.
  - Jika `currency_code` atau `amount` berubah, lakukan validasi currency dan hitung ulang `exchange_rate` serta `amount_in_base_currency`.
  - Jika `payment_method_id` berubah, validasi metode pembayaran milik user.
  - Jika `transaction_date` diubah, jalankan validasi backdate.
  - Kolom `processed` **TIDAK DIUBAH** (tetap mempertahankan nilai yang ada).
  - Update `updated_at = datetime.now(timezone.utc)`.
  - Commit ke database dan kembalikan transaksi yang telah diperbarui.

#### 4. `DELETE /api/v1/transactions/{id}`
- **Tujuan**: Menghapus transaksi dan memindahkannya ke tabel `deleted_transactions`.
- **Logika**:
  - Cek transaksi dan pastikan `transaction.user_id == current_user.id` (jika tidak ditemukan return 404).
  - **VALIDASI DELETE GUARD**:
    - Periksa apakah `transaction.processed == True`.
    - Jika `transaction.processed == True`: Batalkan operasi dan lempar `HTTPException(status_code=400, detail="Transaksi yang sudah diproses tidak dapat dihapus.")`.
  - Jika `transaction.processed == False`:
    - Ambil data nama payment method (jika ada) untuk snapshot.
    - Buat objek `DeletedTransaction`:
      - Salin seluruh field dari `Transaction` (termasuk `processed = False`).
      - `original_transaction_id = transaction.id`
      - `original_created_at = transaction.created_at`
      - `original_updated_at = transaction.updated_at`
      - `deleted_at = datetime.now(timezone.utc)`
      - `deleted_by = current_user.id`
    - `db.add(deleted_tx)`
    - `await db.delete(transaction)`
    - `await db.commit()`
    - Kembalikan pesan sukses: `{"success": True, "message": "Transaksi berhasil dihapus dan dicatat di log."}`.

#### 5. `GET /api/v1/transactions/deleted`
- **Tujuan**: Mengambil daftar riwayat transaksi yang dihapus milik user yang sedang login.
- **Query Constraints**: `DeletedTransaction.user_id == current_user.id`, diurutkan `deleted_at.desc()`.
- **Response**: List of `DeletedTransactionResponse`.

---

## 5. Desain Frontend Flutter

### A. Model (`frontend/lib/features/finance/domain/models.dart`)
- Perbarui model `Transaction`:
  - Tambahkan field `final bool processed;` (default `false`).
  - Tambahkan field `final DateTime? updatedAt;`.
  - Update method `fromJson` dan `toJson`.
- Tambahkan model `DeletedTransaction` (termasuk `final bool processed;`) dengan parser `fromJson` dan `toJson`.

### B. Repository (`frontend/lib/features/finance/data/finance_repository.dart`)
Tambahkan method API berikut:
- `Future<List<Transaction>> getTransactions({DateTime? startDate, DateTime? endDate, String? type, String? notes, String? paymentMethodId})`
- `Future<Transaction> updateTransaction(String id, {String? type, String? currencyCode, double? amount, String? paymentMethodId, String? notes, DateTime? transactionDate})`
- `Future<void> deleteTransaction(String id)`
- `Future<List<DeletedTransaction>> getDeletedTransactions()`

### C. State Management BLoC (`frontend/lib/features/finance/presentation/bloc/`)
Buat `TransactionHistoryBloc`:
- **Events**:
  - `TransactionHistoryFetchRequested({filters...})`
  - `TransactionHistoryDeleteRequested(String id)`
  - `TransactionHistoryUpdateRequested(...)`
  - `DeletedTransactionsFetchRequested()`
- **States**:
  - `TransactionHistoryLoading`
  - `TransactionHistoryLoaded(List<Transaction> transactions, ActiveFilters filters)`
  - `DeletedTransactionsLoaded(List<DeletedTransaction> deletedTransactions)`
  - `TransactionHistoryOperationSuccess(String message)`
  - `TransactionHistoryError(String message)`

### D. Screens & UI Components
1. **`TransactionHistoryScreen` (`screens/transaction_history_screen.dart`)**:
   - **Header & Action Bar**:
     - Judul "Riwayat Transaksi".
     - Tombol "Lihat Transaksi Terhapus" (ikon `Icons.delete_outline` / `Icons.history`).
   - **Filter Panel / Bar**:
     - Input Date Range Picker (Tombol pilih tanggal mulai & selesai).
     - Dropdown / Text pemilih `type`.
     - TextField pencarian `notes`.
     - Tombol lookup pemilih `Payment Method` (memanggil `PaymentMethodLookupDialog`).
     - Tombol "Terapkan Filter" dan "Reset".
   - **Tabel / Daftar Kartu Transaksi**:
     - Kolom tabel:
       - **Processed**: `Checkbox(value: tx.processed, onChanged: null)` (read-only checkbox).
       - **Tanggal**: Format `yyyy-MM-dd HH:mm`.
       - **Tipe**: Label teks / badge.
       - **Catatan**: Substring / multiline singkat.
       - **Metode Pembayaran**: Nama metode pembayaran.
       - **Nominal**: Format currency beserta konversi base currency.
       - **Aksi**: Tombol Edit (pensil) dan Tombol Hapus (tempat sampah, *disabled* / diberi tooltip jika `tx.processed == true`).
2. **`EditTransactionDialog` (`widgets/edit_transaction_dialog.dart`)**:
   - Dialog form yang terisi (*pre-filled*) dengan data transaksi terpilih.
   - Kolom `processed` **TIDAK BISA** diedit (bisa ditampilkan sebagai badge info "Status: Processed / Unprocessed" yang read-only).
   - Menggunakan kalkulasi kurs *realtime* dan pemilih tanggal (*backdate only*) serupa dengan `QuickTransactionDialog`.
   - Tombol Simpan Perubahan yang men-trigger `TransactionHistoryUpdateRequested`.
3. **`DeletedTransactionsScreen` (`screens/deleted_transactions_screen.dart`)**:
   - Halaman daftar sederhana menampilkan log data yang dihapus (Waktu dihapus, Processed status, Nominal, Metode pembayaran, Catatan).
   - Tampilan bersih dan jelas berlabel Read-Only.
4. **Navigasi Dashboard**:
   - Tambahkan menu/tombol pintasan menuju `TransactionHistoryScreen` dari `DashboardScreen` (misal di AppBar action atau drawer).

---

## 6. Panduan Langkah Pengerjaan (Step-by-Step Guide)

1. **Step 1: Backend Database Model**:
   - Buka `backend/app/models/finance.py`.
   - Tambahkan kolom `processed = Column(Boolean, default=False, nullable=False)` pada `Transaction`.
   - Definisikan model `DeletedTransaction` (termasuk kolom `processed`).
   - Update `backend/init_db.py` dan jalankan sinkronisasi database (`python reset_db.py ; python init_db.py`).
2. **Step 2: Backend Schemas & Endpoints**:
   - Buka `backend/app/schemas/finance.py`, tambahkan `TransactionUpdate`, update `TransactionResponse`, dan buat `DeletedTransactionResponse` (pastikan `processed` tidak ada di `TransactionUpdate`).
   - Buka `backend/app/api/v1/finance.py`, implementasikan endpoint `GET /transactions`, `PUT /transactions/{id}`, `DELETE /transactions/{id}`, dan `GET /transactions/deleted`.
3. **Step 3: Frontend Data & Domain Layer**:
   - Update model `Transaction` dan tambahkan `DeletedTransaction` di `domain/models.dart`.
   - Tambahkan method terkait transaksi di `data/finance_repository.dart`.
4. **Step 4: Frontend BLoC Layer**:
   - Buat `TransactionHistoryBloc`, `event`, dan `state`.
5. **Step 5: Frontend UI Layer**:
   - Buat `EditTransactionDialog`.
   - Buat `DeletedTransactionsScreen`.
   - Buat `TransactionHistoryScreen` dengan filter bar lengkap dan kolom `processed` berupa read-only Checkbox.
   - Tambahkan navigasi menuju riwayat transaksi di `DashboardScreen`.
6. **Step 6: Static Analysis & Testing**:
   - Jalankan `flutter analyze` untuk memastikan kode frontend bebas error dan warning.
   - Verifikasi endpoint dengan pengujian manual / curl.

---

## 7. Kriteria Penerimaan & Verifikasi (Acceptance Criteria)

- [ ] **Kolom `processed`**:
  - Kolom `processed` bertipe boolean dengan default `False`.
  - Kolom `processed` **TIDAK BISA** diedit oleh user melalui UI maupun API `PUT /transactions/{id}`.
  - Tampil di halaman Transaction History dalam bentuk **Checkbox** (read-only / disabled).
- [ ] **Data Isolation**: User A tidak dapat melihat riwayat transaksi aktif maupun data transaksi terhapus milik User B.
- [ ] **Filter Bekerja**:
  - Filter rentang tanggal (Date Picker) menyaring transaksi sesuai tanggal yang dipilih.
  - Filter catatan menyaring transaksi berdasarkan substring teks.
  - Filter tipe menyaring transaksi berdasarkan tipe yang dipilih.
  - Filter metode pembayaran hanya menampilkan transaksi dengan metode pembayaran terpilih.
- [ ] **Edit Transaksi**:
  - Transaksi berhasil diedit, nominal base currency dihitung ulang jika kurs/nominal berganti.
  - `updated_at` terupdate ke timestamp saat edit dilakukan.
  - Validasi backdate menolak tanggal di masa depan.
  - Kolom `processed` tidak berubah saat transaksi diedit.
- [ ] **Validasi Hapus (Delete Guard)**:
  - Transaksi dengan `processed = TRUE` **DITOLAK** saat akan dihapus (backend merespons `HTTP 400 Bad Request` dengan pesan yang sesuai).
  - Pada antarmuka pengguna (UI), tombol hapus pada baris transaksi yang bernilai `processed = TRUE` berada dalam kondisi dinonaktifkan (*disabled*).
- [ ] **Hapus & Audit Log (untuk `processed = FALSE`)**:
  - Menghapus transaksi memindahkannya ke tabel `deleted_transactions` beserta waktu hapus, user penghapus, dan status `processed = FALSE`.
  - Transaksi hilang dari daftar `transactions` aktif.
  - Halaman "View Deleted Transactions" menampilkan transaksi yang baru saja dihapus secara akurat.
- [ ] **Kualitas Kode**:
  - `flutter analyze` bersih (0 error).
  - Tidak ada perubahan pada zona terlarang (`core/database.py`, `core/security.py`, `.env`).
