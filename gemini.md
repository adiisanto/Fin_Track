# Fin_Track - Development & Agent Guidelines

## 1. Tech Stack
- **Backend**: Python 3.13, FastAPI, SQLAlchemy 2.0 (Async + asyncpg), Pydantic v2
- **Frontend**: Flutter (Web & Mobile), BLoC (`flutter_bloc`), Dio, Secure Storage
- **Database & Cache**: PostgreSQL 15, Redis 7 (via Docker Compose)
- **Environment**: Windows (PowerShell)

## 2. Run, Test & Quality Commands
### Backend
- Run Dev: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload`
- Init & Seed DB: `python init_db.py`
- Run Tests: `pytest`
- Lint & Check: `ruff check .`

### Frontend
- Run Web: `flutter run -d web-server --web-port 8080`
- Run Tests: `flutter test`
- Static Analysis: `flutter analyze`

## 3. Architecture & Reference Files (Golden Templates)
Selalu gunakan file referensi berikut sebagai standar penulisan kode baru:
- **Backend API**: `backend/app/api/v1/finance.py` (Pattern async DB session, DTO schema validation, dependency injection `deps.py`).
- **Frontend Feature**: `frontend/lib/features/finance/` (Struktur 3 lapis: `domain/`, `data/`, `presentation/bloc/`, `presentation/screens/`).

## 4. Business & Accounting Rules
- **General Ledger (`MST_Account`)**: Seluruh akun bertipe `Debit` / `Credit` dengan hierarki dimensi (`dimensi1..4`).
- **Payment Methods**: Wajib terikat FK ke akun GL (`from_account` -> `mst_account.account`).
- **Multi-Currency**: Setiap transaksi mencatat mata uang transaksi dan hasil konversi ke `users.base_currency` menggunakan rate saat transaksi.
- **Timeframe Dashboard**: Wajib mendukung filter `daily`, `weekly`, `monthly`, dan `lifetime`.

## 5. Off-Limits Zones (DILARANG diubah tanpa izin eksplisit)
- File konfigurasi rahasia: `.env` dan credential files.
- Modul inti keamanan & database: `backend/app/core/database.py` dan `backend/app/core/security.py`.
- Struktur tabel inti GL: Jangan mengubah skema `mst_account` tanpa instruksi eksplisit.
- Skema Database: Setiap perubahan skema tabel wajib diintegrasikan dengan pembaruan seed di `backend/init_db.py`.

## 6. Safety & AI Coding Rules
- **Plan First**: Sebelum menulis kode untuk fitur/refactor besar, buat dan tampilkan *Implementation Plan* terlebih dahulu.
- **No Silent Breaking Changes**:
  - DILARANG menghapus file yang sudah ada tanpa konfirmasi.
  - DILARANG mengubah nama/signature public API endpoint yang sedang berjalan.
  - DILARANG menambah dependency package baru tanpa meminta izin.
- **PowerShell Compatible**: Jangan gunakan sintaks Bash Unix (seperti `mkdir -p` atau `touch`). Gunakan perintah PowerShell yang valid di Windows.
- **Verify Output**: Selalu periksa kode dan pastikan `flutter analyze` atau server backend tidak error setelah perubahan.
