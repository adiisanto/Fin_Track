# [FEATURE] Autentikasi & Manajemen Pengguna (Register & Login)

## 1. Deskripsi Fitur (Overview)
Fitur ini menyediakan mekanisme pendaftaran akun baru (*Register / Sign Up*) dan proses masuk (*Login / Sign In*) yang aman bagi pengguna aplikasi Financial Tracker di berbagai platform (Mobile, Tablet, Web). Mengingat aplikasi ini mengelola data finansial yang sensitif, sistem autentikasi harus menerapkan standar keamanan industri (JWT, hashing modern, rate limiting, dan penyimpanan kredensial aman di client).

---

## 2. User Stories
* **Sebagai pengguna baru**, saya ingin dapat membuat akun dengan email, nama lengkap, dan password yang kuat, serta memilih mata uang dasar (default: IDR) agar data transaksi saya tersimpan dengan aman dan terisolasi.
* **Sebagai pengguna terdaftar**, saya ingin dapat login menggunakan email dan password agar dapat mengakses riwayat transaksi dan dashboard keuangan saya.
* **Sebagai pengguna di mobile/tablet/web**, saya ingin sesi login saya tetap bertahan (via *refresh token*) tanpa harus mengetik ulang password setiap kali membuka aplikasi, namun tetap aman jika token kedaluwarsa.
* **Sebagai pengguna**, saya ingin dapat melakukan *logout* dari perangkat agar data keuangan saya tidak dapat diakses orang lain.

---

## 3. Ruang Lingkup & Kebutuhan Fungsional (Functional Requirements)

### A. Pendaftaran Pengguna Baru (Registration)
1. **Input Fields:**
   - Nama Lengkap (`full_name`): Wajib, minimal 2 karakter, maksimal 100 karakter.
   - Email (`email`): Wajib, format email valid, case-insensitive, unik di database.
   - Password (`password`): Wajib, minimal 8 karakter, mengandung minimal 1 huruf besar, 1 huruf kecil, dan 1 angka/simbol.
   - Mata Uang Utama (`base_currency`): Opsional, default `"IDR"`.
2. **Business Rules:**
   - Sistem menolak pendaftaran jika email sudah terdaftar (`409 Conflict`).
   - Password di-hash menggunakan algoritma **Argon2id** (atau bcrypt dengan work factor memadai). Password mentah tidak boleh disimpan atau dicatat di log aplikasi.
   - Otomatis membuat *default wallet* pertama (misal: "Dompet Tunai / Cash") dan kategori bawaan (Makanan, Transportasi, Gaji, dll.) setelah registrasi berhasil.
   - Respon berhasil mengembalikan data profil pengguna dan pasangan token (Access Token & Refresh Token).

### B. Masuk ke Akun (Login)
1. **Input Fields:**
   - Email (`email`): Format email valid.
   - Password (`password`): Plaintext dari client via HTTPS.
2. **Business Rules:**
   - Verifikasi kecocokan email dan hash password.
   - Jika kredensial salah, berikan pesan generik: *"Email atau password salah"* (`401 Unauthorized`) untuk mencegah user enumeration.
   - Mengembalikan **Access Token (JWT)** (masa berlaku singkat: 15–30 menit) dan **Refresh Token** (masa berlaku panjang: 7–30 hari).
   - Memperbarui field `last_login_at` di database.

### C. Token Refresh & Logout
1. **Refresh Token Flow:**
   - Endpoint khusus untuk menukar Refresh Token yang valid dengan Access Token baru tanpa meminta user login ulang.
2. **Logout:**
   - Menghapus token di sisi client (`flutter_secure_storage`).
   - Me-blacklist / mencabut Refresh Token di sisi server (disimpan di Redis dengan TTL sesuai masa aktif token).

---

## 4. Kebutuhan Non-Fungsional & Keamanan (Security & NFR)
* **Rate Limiting (Brute-Force Protection):** Batasi maksimal 5 percobaan login gagal per IP/Email dalam kurun waktu 1 menit menggunakan Redis.
* **Payload Validation:** Validasi ketat DTO request menggunakan Pydantic v2 (Backend) dan Form Validation regex (Flutter).
* **Audit Trail:** Mencatat log percobaan login gagal dan sukses secara terstruktur (tanpa mengekspos password).
* **Storage Keamanan Client:**
  - Android: `EncryptedSharedPreferences` / KeyStore via `flutter_secure_storage`.
  - iOS: `Keychain` via `flutter_secure_storage`.
  - Web: Web Cryptography API / HttpOnly cookie or secure storage.

---

## 5. Spesifikasi Kontrak API (FastAPI)

### 1. `POST /api/v1/auth/register`
* **Request Body:**
```json
{
  "full_name": "Budi Santoso",
  "email": "budi.santoso@example.com",
  "password": "PasswordSuperAman123!",
  "base_currency": "IDR"
}
```
* **Response (201 Created):**
```json
{
  "success": true,
  "message": "Registrasi berhasil.",
  "data": {
    "user": {
      "id": "c1f7a2b9-3e5f-4a61-9c88-123456789abc",
      "full_name": "Budi Santoso",
      "email": "budi.santoso@example.com",
      "base_currency": "IDR",
      "created_at": "2026-09-14T11:57:00Z"
    },
    "tokens": {
      "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "token_type": "bearer",
      "expires_in": 1800
    }
  }
}
```

### 2. `POST /api/v1/auth/login`
* **Request Body:**
```json
{
  "email": "budi.santoso@example.com",
  "password": "PasswordSuperAman123!"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Login berhasil.",
  "data": {
    "user": {
      "id": "c1f7a2b9-3e5f-4a61-9c88-123456789abc",
      "full_name": "Budi Santoso",
      "email": "budi.santoso@example.com",
      "base_currency": "IDR"
    },
    "tokens": {
      "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "token_type": "bearer",
      "expires_in": 1800
    }
  }
}
```

### 3. `POST /api/v1/auth/refresh`
* **Request Body:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer",
    "expires_in": 1800
  }
}
```

### 4. `GET /api/v1/auth/me` *(Protected Route)*
* **Headers:** `Authorization: Bearer <access_token>`
* **Response (200 OK):** Mengembalikan data profil user saat ini.

---

## 6. Desain Entitas Database (PostgreSQL / SQLAlchemy Model)

### Tabel `users`:
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `id` | `UUID` | Primary Key, default `gen_random_uuid()` |
| `email` | `VARCHAR(255)` | Unique, Indexed, Not Null |
| `password_hash` | `VARCHAR(255)` | Not Null (Argon2id) |
| `full_name` | `VARCHAR(100)` | Not Null |
| `base_currency` | `VARCHAR(3)` | Default `'IDR'`, Not Null |
| `is_active` | `BOOLEAN` | Default `true`, Not Null |
| `created_at` | `TIMESTAMPTZ` | Default `NOW()`, Not Null |
| `updated_at` | `TIMESTAMPTZ` | Default `NOW()`, Not Null |
| `last_login_at`| `TIMESTAMPTZ` | Nullable |

---

## 7. Desain Frontend Flutter

### A. Tampilan UI
1. **Screen: `RegisterScreen`**
   - Form Nama, Email, Password, Konfirmasi Password.
   - Pilihan Mata Uang Default (Dropdown/Searchable modal).
   - Validasi error inline (misal: "Password minimal 8 karakter").
   - Tombol toggle tampilkan/sembunyikan password (*eye icon*).
2. **Screen: `LoginScreen`**
   - Form Email & Password.
   - Checkbox "Ingat Saya" / auto-login.
   - Tombol navigasi ke Register & Lupa Password.
3. **Responsivitas Layout:**
   - **Mobile:** Tampilan full screen dengan scrollable view (mencegah overflow saat keyboard muncul).
   - **Tablet & Web:** Card dialog di tengah layar dengan background branding finansial yang elegan (maksimal lebar card: 450px).

### B. State Management (`AuthBloc`)
* **Events:**
  - `AuthCheckRequested`: Dipanggil saat aplikasi pertama kali dibuka (cek token tersimpan).
  - `AuthRegisterSubmitted(fullName, email, password, currency)`
  - `AuthLoginSubmitted(email, password)`
  - `AuthLogoutRequested`
* **States:**
  - `AuthInitial`: Kondisi awal saat startup.
  - `AuthLoading`: Saat proses HTTP request berlangsung (tampilkan spinner).
  - `Authenticated(User user)`: Login/Register berhasil, navigasi ke Dashboard.
  - `Unauthenticated`: Belum login atau sesi habis, arahkan ke LoginScreen.
  - `AuthFailure(String errorMessage)`: Tampilkan snackbar / banner error.

### C. Network Interceptor (`Dio`)
* Menambahkan `Authorization: Bearer <token>` di setiap request yang memerlukan autentikasi.
* **QueuedInterceptor:** Menangkap error HTTP `401 Unauthorized`. Jika terjadi, panggil endpoint `/refresh` secara otomatis dan ulangi request yang gagal tanpa membuat pengguna terlempar keluar.

---

## 8. Kriteria Penerimaan (Acceptance Criteria / Definition of Done)

- [ ] **Registrasi Akun Baru:**
  - [ ] Validasi gagal jika format email salah atau password kurang dari 8 karakter.
  - [ ] Registrasi gagal dengan status `409` jika email sudah digunakan.
  - [ ] Registrasi sukses menghasilkan record baru di tabel `users` dengan password yang ter-hash aman.
  - [ ] Registrasi sukses otomatis membuat dompet default dan kategori bawaan.
- [ ] **Login:**
  - [ ] Login gagal jika email tidak ditemukan atau password tidak cocok (status `401`).
  - [ ] Login sukses mengembalikan Access Token dan Refresh Token yang valid.
  - [ ] Rate limiting aktif jika salah password lebih dari 5 kali berturut-turut.
- [ ] **Flutter UI & Session:**
  - [ ] Form responsif dan bebas dari render overflow di semua ukuran layar (Mobile, Tablet, Web).
  - [ ] Token tersimpan di `flutter_secure_storage`.
  - [ ] Ketika aplikasi ditutup dan dibuka kembali, sesi pengguna tetap aktif (Auto-login via `AuthCheckRequested`).
  - [ ] Tombol Logout menghapus token lokal dan mengembalikan user ke halaman login.
- [ ] **Testing:**
  - [ ] Unit test backend untuk hashing & JWT generator lulus 100%.
  - [ ] Integration test untuk endpoint Register & Login lulus.
  - [ ] Widget test untuk form login & register di Flutter lulus.
