# Fin_Track - Command Cheatsheet & Workflow

Dokumen ini berisi daftar perintah utama yang sering digunakan selama masa pengembangan proyek Fin_Track.

## 1. Infrastruktur (Docker)

Pastikan Docker Desktop sudah berjalan sebelum menjalankan perintah ini.

- **Menjalankan Database (PostgreSQL) & Redis**:
  ```powershell
  docker-compose up -d
  ```
- **Menghentikan Infrastruktur**:
  ```powershell
  docker-compose down
  ```

## 2. Backend (Python FastAPI)

Pastikan Anda berada di direktori `backend/` dan *virtual environment* sudah aktif.

- **Mengaktifkan Virtual Environment (Windows PowerShell)**:
  ```powershell
  cd backend
  .\venv\Scripts\activate
  ```
- **Menjalankan Server Mode Development**:
  ```powershell
  uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
  ```
- **Inisialisasi Tabel & Seed Data** (Jalankan sekali saja atau jika ada reset schema):
  ```powershell
  python init_db.py
  ```
- **Menjalankan Linter / Format Checker**:
  ```powershell
  ruff check .
  ```
- **Menjalankan Automated Tests** (Pastikan sudah menginstall `pytest`):
  ```powershell
  pytest
  ```

## 3. Frontend (Flutter)

Pastikan Anda berada di direktori `frontend/`.

- **Berpindah ke direktori Frontend**:
  ```powershell
  cd frontend
  ```
- **Mengambil Dependencies**:
  ```powershell
  flutter pub get
  ```
- **Menjalankan Aplikasi (Mode Web Server)**:
  *Sangat direkomendasikan saat debugging / menggunakan AI agar browser tidak berjalan di latar belakang (hidden).*
  ```powershell
  flutter run -d web-server --web-port 8080
  ```
  *(Akses melalui `http://localhost:8080` di browser).*
- **Menjalankan Static Analysis / Linter**:
  ```powershell
  flutter analyze
  ```
- **Menjalankan Unit/Widget Tests**:
  ```powershell
  flutter test
  ```

## 4. Git Workflow

- **Membuat Branch Fitur Baru**:
  ```powershell
  git checkout -b features/nama-fitur
  ```
- **Commit & Push**:
  ```powershell
  git add .
  git commit -m "feat: Deskripsi fitur"
  git push -u origin features/nama-fitur
  ```
