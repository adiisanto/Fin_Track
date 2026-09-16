# Routing & Navigation Guide - Fin_Track

Dokumen ini berisi daftar seluruh *routing* yang digunakan pada proyek **Fin_Track**, mencakup **Backend API Endpoints** dan **Frontend Navigation/Screens**. Dokumen ini **wajib diperbarui** setiap kali ada penambahan atau perubahan rute/layar.

---

## 1. Backend API Routes

- **Base URL Dev**: `http://localhost:8000`
- **Global API Prefix**: `/api/v1`

### A. Feature: System & Core
| Method | Endpoint | Access | Deskripsi |
| :--- | :--- | :--- | :--- |
| `GET` | `/` | Public | Root health check / welcome message |
| `GET` | `/api/v1/openapi.json` | Public | Dokumentasi OpenAPI / Swagger schema |

---

### B. Feature: Auth (`/api/v1/auth`)
| Method | Endpoint | Access | Deskripsi |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/auth/register` | Public | Mendaftarkan pengguna baru & *generate* token |
| `POST` | `/api/v1/auth/login` | Public | Autentikasi user & mengembalikan access & refresh token |
| `POST` | `/api/v1/auth/refresh` | Public | Memperbarui access token menggunakan refresh token |
| `GET` | `/api/v1/auth/me` | Protected (Bearer Token) | Mengambil data profil user yang sedang login |

> ℹ️ **Catatan Lintas Feature (`GET /api/v1/auth/me`)**:  
> Endpoint ini dikelompokkan di fitur **Auth**, namun juga digunakan oleh fitur **Finance (Dashboard)** untuk mendeteksi `base_currency` dan nama user aktif.

---

### C. Feature: Finance (`/api/v1`)

#### 1. Dashboard Summary
| Method | Endpoint | Access | Deskripsi |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/dashboard/summary` | Protected (Bearer Token) | Mengambil rekapitulasi pemasukan, pengeluaran, net profit/loss, dan total transaksi |
- **Query Params**:
  - `timeframe`: `daily` | `weekly` | `monthly` | `lifetime` (default: `monthly`)
  - `reference_date`: Datetime acuan filter (default: waktu sekarang / UTC)

#### 2. Transactions
| Method | Endpoint | Access | Deskripsi |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/transactions` | Protected (Bearer Token) | Membuat pencatatan transaksi baru (Income / Expense) beserta konversi otomatis ke base currency |

> ℹ️ **Catatan Lintas Feature (`POST /api/v1/transactions`)**:  
> Saat ini digunakan oleh formulir pencatatan pengeluaran (**Add Expense**), dan akan digunakan juga untuk pencatatan pemasukan (**Add Income**).

#### 3. Master Data (Currencies, Rates, Payment Methods)
| Method | Endpoint | Access | Deskripsi |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/currencies` | Public | Mengambil daftar mata uang yang didukung sistem (opsional: `include_inactive`) |
| `GET` | `/api/v1/currency-rates/latest` | Public | Mengambil kurs/nilai tukar terbaru antara dua mata uang |
| `GET` | `/api/v1/payment-methods` | Public | Mengambil daftar metode pembayaran aktif yang terikat ke akun GL |
| `POST` | `/api/v1/admin/currencies` | Protected (Superadmin) | Menambah data mata uang baru |
| `DELETE`| `/api/v1/admin/currencies/{code}` | Protected (Superadmin) | Menghapus mata uang (jika belum dipakai transaksi) |

> ℹ️ **Catatan Lintas Feature (Master Data)**:
> - `GET /api/v1/currencies`: Dikelompokkan di **Finance**, tetapi juga digunakan pada form registrasi di fitur **Auth** untuk memilih `base_currency` awal pengguna.
> - `GET /api/v1/currency-rates/latest` & `GET /api/v1/payment-methods`: Digunakan oleh form transaksi (**Add Expense**) untuk kalkulasi realtime nilai tukar dan pemilihan rekening/metode pembayaran.

---

## 2. Frontend Navigation & Screens

Navigasi Frontend menggunakan kombinasi **State-Driven Routing** (`AppNavigator` berbasis `AuthBloc`) dan **Imperative Push/Pop** (`MaterialPageRoute`).

### A. Feature: Auth

| Screen / Destination | File Path | Mekanisme Akses / Navigasi | Deskripsi |
| :--- | :--- | :--- | :--- |
| **Auth Gate / Root** | `lib/main.dart` (`AppNavigator`) | State-driven (`BlocBuilder<AuthBloc, AuthState>`) | Gerbang utama aplikasi. Menampilkan `CircularProgressIndicator` saat loading, `DashboardScreen` jika terautentikasi, atau `LoginScreen` jika belum |
| **Login Screen** | `lib/features/auth/presentation/screens/login_screen.dart` | Default fallback saat unauthenticated | Form login user |
| **Register Screen** | `lib/features/auth/presentation/screens/register_screen.dart` | `Navigator.push(MaterialPageRoute(...))` dari Login Screen | Form pendaftaran akun baru. Pop kembali ke Login Screen setelah berhasil |

---

### B. Feature: Finance

| Screen / Destination | File Path | Mekanisme Akses / Navigasi | Deskripsi |
| :--- | :--- | :--- | :--- |
| **Dashboard Screen** | `lib/features/finance/presentation/screens/dashboard_screen.dart` | Ditampilkan otomatis oleh `AppNavigator` saat `state is Authenticated` | Halaman utama yang menampilkan ringkasan keuangan, filter timeframe, dan tombol catat transaksi |
| **Add Expense Screen** | `lib/features/finance/presentation/screens/add_expense_screen.dart` | `Navigator.push(MaterialPageRoute(...))` dari FloatingActionButton Dashboard | Form input transaksi pengeluaran. Menghasilkan *pop(true)* saat berhasil disimpan untuk memicu *refresh* otomatis di Dashboard |
| **Currency Management Screen** | `lib/features/finance/presentation/screens/currency_management_screen.dart` | `Navigator.push(MaterialPageRoute(...))` dari Drawer khusus Superadmin di Dashboard | Halaman khusus superadmin untuk menambah dan menghapus mata uang |

> ℹ️ **Catatan Lintas Feature (Navigasi)**:
> - **Logout**: Tombol logout di `DashboardScreen` mendispatch `AuthLogoutRequested` ke `AuthBloc` (fitur **Auth**), yang secara reaktif mengubah tampilan kembali ke `LoginScreen`.
