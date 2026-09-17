# Issue: Global Floating Dialog Input Transaction (Pencatatan Transaksi Keuangan)

## 1. Ringkasan Fitur & Latar Belakang
Fitur **Input Transaction** adalah fitur pencatatan transaksi keuangan pengguna ke dalam tabel `transactions`. 

Untuk memberikan fleksibilitas maksimal, antarmuka input transaksi tidak dibuat sebagai halaman penuh (*full screen*) yang terisolasi, melainkan berbentuk **Floating Dialog / Floating Card** ringkas yang dapat dipanggil dan diakses dari **halaman manapun (omnipresent / global access)** di dalam aplikasi.

### Karakteristik & Kebutuhan Utama:
1. **Global Access (Omnipresent)**: 
   - Pengguna dapat memunculkan form input transaksi kapan saja dari halaman manapun (Dashboard, Halaman Kelola Akun, Pengaturan, dsb.) tanpa kehilangan konteks halaman yang sedang dibuka.
   - Dipicu melalui sebuah tombol melayang (*Floating Action Button / FAB*) atau tombol trigger global yang intuitif.
2. **Bentuk Floating Card Ringkas & Auto-Hide**:
   - Dialog berbentuk kartu (*Card*) berukuran kecil (*compact modal*) dengan penataan rapi agar cepat diisi.
   - Bersifat **auto-hide**: dialog otomatis tertutup ketika pengguna menyentuh/mengklik area luar kartu (*barrier dismissible*), menekan tombol batal/tutup, atau ketika transaksi berhasil disimpan.
3. **Inputan & Aturan Data Transaksi**:
   - **`type` (Tipe Transaksi)**: TextField referensi ke Master Type. Karena modul master type saat ini belum dibuat, field ini bersifat **opsional / dapat bernilai `NULL`**. Pengguna dapat mengisinya dengan teks bebas atau mengosongkannya.
   - **`currency_code` (Mata Uang Transaksi)**: Referensi ke tabel `currencies`, **wajib diisi (Not Null)**. Nilai bawaan (*default value*) otomatis mengambil `base_currency` milik pengguna yang sedang login (dari tabel `users`).
   - **`amount` (Nominal Transaksi)**: Input angka desimal positif (`> 0`) dalam mata uang `currency_code` yang dipilih. Wajib diisi.
   - **`amount_in_base_currency` (Nominal dalam Base Currency)**: **Read-only (tidak dapat diedit secara manual)**. Merupakan hasil kalkulasi otomatis sistem:
     $$\text{amount\_in\_base\_currency} = \text{amount} \times \text{currency\_rate}$$
     Nilai kurs diambil dari tabel `currency_rates` untuk pasangan mata uang yang dipilih terhadap `base_currency` user. Jika mata uang yang dipilih sama dengan `base_currency`, maka kurs adalah `1.0`.
   - **`payment_method_id` (Metode Pembayaran)**: Referensi ke tabel `payment_methods` (hanya metode aktif milik user yang bersangkutan). Dilengkapi **popup lookup value** interaktif dengan filter pencarian kode maupun nama metode pembayaran.
   - **`notes` (Catatan Transaksi)**: Input teks berupa kotak besar / multiline (*text area*), bersifat opsional (*nullable*).
   - **`transaction_date` (Tanggal & Waktu Transaksi)**: Input `DATETIME` (Tanggal & Jam). Bersifat opsional, dengan nilai bawaan adalah timestamp waktu saat ini (*current timestamp*). **Aturan Validasi Ketat**: **Hanya bisa backdate** (tanggal/waktu lampau hingga saat ini). **DILARANG memilih tanggal/jam di masa depan (*future date*)**.
   - **Tombol Submit**: Memvalidasi seluruh masukan, menyimpan transaksi ke backend, memberikan notifikasi keberhasilan, me-refresh data ringkasan jika relevan, lalu menutup floating dialog.

---

## 2. Perubahan Skema Database (Database & Models)

### A. Model `Transaction` (`backend/app/models/finance.py`)
Tabel `transactions` saat ini mewajibkan `type` (`nullable=False`). Karena modul Master Type belum diimplementasikan dan spesifikasi mensyaratkan `type` dapat bernilai `NULL`, kolom `type` harus disesuaikan menjadi **nullable**:

```python
class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    
    # PERUBAHAN: Ubah nullable menjadi True untuk mendukung type opsional / NULL
    type = Column(String(50), nullable=True) 
    
    currency_code = Column(String(3), ForeignKey("currencies.code"), nullable=False)
    amount = Column(Numeric(15, 2), nullable=False)
    exchange_rate = Column(Numeric(18, 6), nullable=False)
    amount_in_base_currency = Column(Numeric(15, 2), nullable=False)
    
    payment_method_id = Column(UUID(as_uuid=True), ForeignKey("payment_methods.id"), nullable=False)
    notes = Column(Text, nullable=True)
    
    transaction_date = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
```

> **Catatan Sinkronisasi DB**: Jalankan `python init_db.py` (atau `reset_db.py` kemudian `init_db.py` sesuai instruksi proyek) untuk menerapkan modifikasi kolom `type` menjadi nullable.

---

## 3. Desain Backend API (FastAPI)

### A. Pydantic Schemas (`backend/app/schemas/finance.py`)

Perbarui skema `TransactionCreate` dan `TransactionResponse`:

```python
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, field_validator

class TransactionCreate(BaseModel):
    type: Optional[str] = Field(None, max_length=50, description="Tipe transaksi (referensi master type mendatang, dapat NULL)")
    currency_code: str = Field(..., min_length=3, max_length=3, description="Kode mata uang transaksi")
    amount: Decimal = Field(..., gt=0, description="Nominal transaksi (> 0)")
    payment_method_id: UUID = Field(..., description="ID metode pembayaran")
    notes: Optional[str] = Field(None, description="Catatan transaksi opsional")
    transaction_date: Optional[datetime] = Field(None, description="Tanggal transaksi (hanya backdate / <= now)")

    @field_validator("transaction_date")
    @classmethod
    def validate_backdate_only(cls, v: Optional[datetime]) -> Optional[datetime]:
        if v is not None:
            now_utc = datetime.now(timezone.utc)
            target_dt = v if v.tzinfo is not None else v.replace(tzinfo=timezone.utc)
            if target_dt > now_utc:
                raise ValueError("Tanggal transaksi tidak boleh di masa depan (hanya backdate yang diizinkan).")
        return v

class TransactionResponse(BaseModel):
    id: UUID
    type: Optional[str] = None
    currency_code: str
    amount: Decimal
    exchange_rate: Decimal
    amount_in_base_currency: Decimal
    payment_method_id: UUID
    payment_method_code: Optional[str] = None
    payment_method_name: Optional[str] = None
    notes: Optional[str] = None
    transaction_date: datetime
    created_at: datetime

    class Config:
        from_attributes = True
```

### B. Endpoint Transaksi (`backend/app/api/v1/finance.py`)

Perbarui endpoint `POST /api/v1/transactions`:
- **Path**: `POST /api/v1/transactions`
- **Autentikasi**: Wajib (`current_user: User = Depends(get_current_user)`).
- **Logika Eksekusi**:
  1. **Validasi Mata Uang**: Pastikan `currency_code` terdaftar dan aktif di tabel `currencies`. Jika tidak valid, lempar `HTTP 400 Bad Request`.
  2. **Validasi Metode Pembayaran**:
     - Cari `PaymentMethod` dengan `id == trans_in.payment_method_id`.
     - Harus milik `current_user.id` (atau template publik sistem jika diizinkan) dan berstatus `is_active == True`.
     - Jika tidak ditemukan atau nonaktif, lempar `HTTP 400 Bad Request ("Metode pembayaran tidak valid atau tidak aktif.")`.
  3. **Validasi Tanggal Transaksi (Backdate Check)**:
     - Jika `trans_in.transaction_date` kosong, gunakan `datetime.now(timezone.utc)`.
     - Jika diisi, pastikan `transaction_date <= datetime.now(timezone.utc)`. Jika di masa depan, lempar `HTTP 400 Bad Request`.
  4. **Kalkulasi Kurs & Base Currency**:
     - Jika `currency_code == current_user.base_currency`:
       - `exchange_rate = Decimal("1.0")`
     - Jika berbeda:
       - Query kurs aktif terbaru dari tabel `currency_rates`:
         ```sql
         SELECT rate FROM currency_rates 
         WHERE from_currency = :currency_code 
           AND to_currency = :user_base_currency 
           AND valid_to IS NULL 
         ORDER BY valid_from DESC LIMIT 1;
         ```
       - Jika tidak ditemukan kurs aktif, lempar `HTTP 400 Bad Request ("Kurs aktif tidak ditemukan untuk mata uang terpilih.")`.
     - Hitung:
       $$\text{amount\_in\_base} = \text{trans\_in.amount} \times \text{exchange\_rate}$$
  5. **Simpan Data Transaksi**:
     - Insert record baru ke model `Transaction`.
     - Simpan `type = trans_in.type.strip() if trans_in.type else None`.
     - Commit dan refresh data.
  6. **Return Response**:
     - Format JSON standar Fin_Track:
       ```json
       {
         "success": true,
         "message": "Transaksi berhasil dicatat.",
         "data": {
           "id": "uuid...",
           "type": "Makan Siang",
           "currency_code": "USD",
           "amount": 15.50,
           "exchange_rate": 15800.0,
           "amount_in_base_currency": 244900.0,
           "payment_method_id": "uuid...",
           "notes": "Traktir teman kantor",
           "transaction_date": "2026-09-17T12:30:00Z"
         }
       }
       ```

---

## 4. Desain Frontend (Flutter)

### A. Arsitektur Komponen & UI Placement
Agar floating dialog dapat dipanggil dari halaman manapun:
1. **Global Floating Action Button (FAB) / Trigger**:
   - Dapat disematkan pada shell utama navigasi (`DashboardScreen`, App Bar action, atau wrapper layout).
   - Memiliki ikon transaksi (misal: `Icons.add` atau `Icons.receipt_long`) yang selalu terlihat jelas (*floating*).
2. **Dialog Form Ringkas (`QuickTransactionDialog`)**:
   - Dipanggil menggunakan `showDialog(context: context, barrierDismissible: true, builder: ...)` sehingga memiliki sifat **auto-hide** saat tap di luar dialog.
   - Berbentuk `Card` / `Dialog` berukuran kecil-menengah (lebar proporsional max 480px di desktop/tablet, padding 16px, `clipBehavior: Clip.antiAlias`).
   - Menyediakan tombol "X" (close) di kanan atas serta tombol Batal dan Simpan.

### B. Komponen Form Input Transaksi (`QuickTransactionDialog`)
Form di dalam dialog berisi elemen-elemen berikut secara berurutan:
1. **Header Dialog**:
   - Judul ringkas: `"Catat Transaksi"`.
   - Tombol icon tutup (`IconButton(Icons.close)`).
2. **Field `type`**:
   - `TextFormField` bertuliskan `"Tipe Transaksi (Opsional)"`.
   - Hint: `"Contoh: Operasional, Pribadi, dll."`.
   - Boleh kosong (*nullable*).
3. **Baris Mata Uang & Kalkulasi Kurs**:
   - **`currency_code`**: `DropdownButtonFormField<String>` memuat daftar mata uang aktif (`FinanceRepository.getCurrencies`).
     - Nilai *initial / default*: `currentUser.baseCurrency` (misal: `IDR`).
   - **Kalkulator Kurs Realtime**:
     - Setiap kali mata uang dipilih atau nominal diubah, ambil kurs terbaru melalui `getLatestCurrencyRate(selectedCurrency, baseCurrency)`.
     - Tampilkan indikator kurs kecil di bawah dropdown, misal: `1 USD = Rp 15.800`.
4. **Field `amount`**:
   - `TextFormField` dengan tipe keyboard angka/desimal (`TextInputType.numberWithOptions(decimal: true)`).
   - Label: `"Nominal Transaksi"`.
   - Validasi: Wajib diisi, harus bernilai angka > 0.
5. **Field `amount_in_base_currency` (Read-only)**:
   - `TextFormField` dengan properti:
     - `readOnly: true`
     - `enabled: false` (atau background sedikit abu-abu).
   - Label: `"Total dalam Mata Uang Utama ({base_currency})"`.
   - Nilai terformat otomatis sesuai kalkulasi `amount * rate`.
6. **Field `payment_method` dengan Popup Lookup**:
   - Inputfield readonly yang menampilkan `"Nama Metode Pembayaran (Kode)"`.
   - Tombol icon cari (`Icons.search`) yang saat diklik akan memunculkan **`PaymentMethodLookupDialog`**.
   - Validasi: Wajib dipilih.
7. **Popup Lookup Modal (`PaymentMethodLookupDialog`)**:
   - Menampilkan daftar metode pembayaran aktif (`FinanceRepository.getPaymentMethods(includeInactive: false)`).
   - Menyediakan kolom pencarian (*search field*) *real-time* untuk memfilter berdasarkan kode atau nama metode.
   - Saat salah satu item diklik, modal lookup tertutup dan mengembalikan data `PaymentMethod` terpilih.
8. **Field `transaction_date` (Date & Time Picker Backdate)**:
   - Field tap-able yang menampilkan format tanggal & jam: `yyyy-MM-dd HH:mm`.
   - Default: Tanggal dan jam saat form dibuka (`DateTime.now()`).
   - Saat diklik:
     - Buka `showDatePicker` dengan batas:
       - `firstDate: DateTime(2000)`
       - `lastDate: DateTime.now()` (Mencegah tanggal masa depan).
     - Setelah tanggal dipilih, buka `showTimePicker`.
     - Jika tanggal yang dipilih adalah **hari ini**, validasi jam & menit tidak boleh melebihi jam & menit saat ini. Jika melebihi, setel otomatis ke waktu sekarang dan tampilkan peringatan bahwa masa depan tidak diperkenankan.
9. **Field `notes`**:
   - `TextFormField` multiline (`maxLines: 3`, `minLines: 2`).
   - Label: `"Catatan (Opsional)"`.
10. **Aksi Tombol (Footer)**:
    - Tombol `Batal` (TextButton).
    - Tombol `Simpan Transaksi` (ElevatedButton) dengan *loading indicator* saat proses submit berlangsung.

### C. State Management (BLoC / Repository Integration)
1. **Repository (`FinanceRepository`)**:
   - Memastikan method `createTransaction` menerima parameter:
     ```dart
     Future<void> createTransaction({
       String? type,
       required String currencyCode,
       required double amount,
       required String paymentMethodId,
       String? notes,
       DateTime? transactionDate,
     });
     ```
2. **BLoC (`TransactionBloc`)**:
   - Event: `TransactionCreateSubmitted(data)`.
   - State: `TransactionCreateInProgress`, `TransactionCreateSuccess`, `TransactionCreateFailure(error)`.
   - Pada saat `TransactionCreateSuccess`:
     - Tampilkan SnackBar sukses: `"Transaksi berhasil dicatat."`.
     - Tutup dialog (`Navigator.of(context).pop(true)`).
     - Picu refresh pada widget atau listener halaman aktif (misal `DashboardBloc.add(DashboardFetchRequested())`).

---

## 5. Validasi & Aturan Bisnis (Business Rules)

| No | Aturan | Mekanisme Penanganan |
| :---: | :--- | :--- |
| 1 | **Tipe Transaksi Opsional** | Field `type` boleh kosong. Jika kosong, kirim `null` ke API dan simpan sebagai `NULL` di DB. |
| 2 | **Default Currency** | Nilai awal mata uang wajib membaca `base_currency` pengguna login dari session/user model. |
| 3 | **Nominal Wajib Positif** | Nilai `amount` harus `> 0`. Tolak input 0, angka negatif, atau format non-numerik. |
| 4 | **Kalkulasi Kurs Otomatis** | `amount_in_base_currency` dihitung secara dinamis. Nilai tidak dapat diinput/diubah manual oleh pengguna. |
| 5 | **Lookup Payment Method** | Pengguna hanya dapat memilih metode pembayaran yang berstatus aktif (`is_active = True`) milik user tersebut. |
| 6 | **Strict Backdate Only** | Tanggal dan waktu transaksi `transaction_date` **tidak boleh berada di masa depan**. Sistem frontend membatasi picker dan backend menolak dengan pesan error jika `transaction_date > now()`. |
| 7 | **Auto-Hide Behavior** | Dialog wajib bisa ditutup hanya dengan mengklik area gelap di luar kartu (*dismiss on barrier touch*) untuk kenyamanan navigasi pengguna. |

---

## 6. Panduan Langkah Pengerjaan (Step-by-Step Implementation Guide)

Untuk pengembang junior atau AI model pelaksana, ikuti langkah-langkah terstruktur berikut:

### Langkah 1: Backend Database & Schema
1. Buka `backend/app/models/finance.py`:
   - Ubah kolom `type` pada class `Transaction` agar `nullable=True`.
2. Buka `backend/app/schemas/finance.py`:
   - Perbarui `TransactionCreate` agar `type` menjadi `Optional[str] = None` dan tambahkan validator `validate_backdate_only`.
3. Buka `backend/app/api/v1/finance.py`:
   - Di endpoint `create_transaction`, tambahkan validasi `transaction_date <= datetime.now(timezone.utc)`.
   - Tangani penyimpanan `type` yang dapat berupa `None`.
4. Jalankan script inisialisasi DB untuk memastikan skema terupdate:
   ```powershell
   .\backend\venv\Scripts\python backend/reset_db.py
   .\backend\venv\Scripts\python backend/init_db.py
   ```

### Langkah 2: Frontend Data Layer
1. Buka `frontend/lib/features/finance/data/finance_repository.dart`:
   - Perbarui signature method `createTransaction` agar menerima parameter `String? type` dan `DateTime? transactionDate`.
   - Sertakan `type` dan `transaction_date` (format ISO 8601 UTC) pada payload request POST `/api/v1/transactions`.

### Langkah 3: Frontend UI Components
1. Buat widget dialog lookup pembayaran di file terpisah atau di dalam folder widgets:
   - `frontend/lib/features/finance/presentation/widgets/payment_method_lookup_dialog.dart`.
2. Buat widget dialog transaksi utama:
   - `frontend/lib/features/finance/presentation/widgets/quick_transaction_dialog.dart`.
   - Terapkan controller dan logic perubahan kurs realtime (`_onCurrencyOrAmountChanged`).
   - Terapkan date & time picker dengan validasi `lastDate: DateTime.now()`.
3. Buat helper function untuk menampilkan dialog ini dari mana saja:
   ```dart
   Future<bool?> showQuickTransactionDialog(BuildContext context) {
     return showDialog<bool>(
       context: context,
       barrierDismissible: true,
       builder: (ctx) => const QuickTransactionDialog(),
     );
   }
   ```
4. Tambahkan tombol Floating Action Button (FAB) atau tombol pemanggil di `DashboardScreen` (dan global shell/app bar jika ada) yang memanggil `showQuickTransactionDialog(context)`.
5. Jika hasil dialog mengembalikan `true`, trigger refresh dashboard summary:
   ```dart
   final result = await showQuickTransactionDialog(context);
   if (result == true) {
     context.read<DashboardBloc>().add(DashboardFetchRequested(_selectedTimeframe));
   }
   ```

### Langkah 4: Pembaruan Dokumentasi
Perbarui dokumen proyek berikut:
1. `docs/table.md`: Perbarui keterangan kolom `transactions.type` menjadi `Nullable`.
2. `docs/routes.md`: Catat bahwa `POST /api/v1/transactions` kini mendukung `type: Optional[str]` dan validasi backdate.
3. `docs/features.md`: Tambahkan entri fitur "Global Floating Dialog Input Transaction" dengan status pengerjaan yang sesuai.

---

## 7. Kriteria Penerimaan (Definition of Done)

- [ ] **Omnipresent Access**: Floating dialog dapat dimunculkan dari tombol trigger/FAB di antarmuka aplikasi.
- [ ] **Auto-Hide**: Dialog otomatis tertutup jika pengguna mengetuk backdrop di luar kartu dialog atau menekan batal.
- [ ] **Tipe Transaksi Opsional**: Inputan `type` dapat dikosongkan (tersimpan sebagai `NULL` di DB) atau diisi teks deskriptif bebas tanpa error validasi.
- [ ] **Default Currency Otomatis**: Dropdown mata uang otomatis terisi dengan `base_currency` user yang sedang login.
- [ ] **Kalkulasi Kurs Otomatis**: Kolom `amount_in_base_currency` bersifat read-only dan otomatis mengkalkulasi nominal dikalikan kurs saat amount atau currency berubah.
- [ ] **Lookup Payment Method**: Pengguna dapat mencari dan memilih metode pembayaran aktif lewat modal popup lookup.
- [ ] **Strict Backdate Only**: Date & Time picker tidak dapat memilih waktu di masa depan. Request dengan tanggal masa depan ditolak oleh backend.
- [ ] **Penyimpanan Berhasil**: Data transaksi tersimpan di database dengan relasi user, mata uang, dan payment method yang tepat.
- [ ] **Refleksi Dashboard**: Saldo atau rekapitulasi pada dashboard ter-update secara otomatis setelah transaksi baru selesai dicatat.
- [ ] **Quality Checks**:
  - Backend lolos validasi tanpa error.
  - Frontend lolos static analysis (`flutter analyze`) tanpa issue baru.
