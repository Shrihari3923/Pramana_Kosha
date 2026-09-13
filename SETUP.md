# pramāṇa-kośa — Setup Guide

Complete setup instructions to get all three services running locally.

---

## Prerequisites

Install these before you start:

| Tool | Version | Install |
|------|---------|---------|
| **Git** | any | https://git-scm.com |
| **Node.js** | 18+ | https://nodejs.org |
| **Rust + Cargo** | stable | https://rustup.rs |
| **Python** | 3.10+ | https://python.org |

---

## 1. Clone the Repository

```bash
git clone https://github.com/Aneeshkn07/Pram-na-Kosha.git
cd Pram-na-Kosha
```

---

## 2. Backend Setup

### 2a. Create the environment file

```bash
cd backend
cp env.example .env
```

Open `backend/.env` and fill in the values:

```env
DATABASE_URL=postgres://avnadmin:YOUR_PASSWORD@YOUR_HOST:PORT/defaultdb?sslmode=require
JWT_SECRET=your-long-random-secret-at-least-32-chars
PORT=3000
KEY_ENCRYPTION_SECRET=another-long-random-secret-32-chars
ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
OCR_SERVICE_URL=http://127.0.0.1:8000/ocr
```

> Ask Adithya for the actual `DATABASE_URL`, `JWT_SECRET`, and `KEY_ENCRYPTION_SECRET` values.

### 2b. Run the backend

```bash
cd backend
cargo run
```

First run will take a few minutes to compile. When you see:

```
INFO backend: ChainDock backend running on http://127.0.0.1:3000
```

the backend is ready.

---

## 3. OCR Service Setup

### 3a. Create a Python virtual environment

```bash
cd ocr-service
python3 -m venv .venv
```

### 3b. Activate it

**Linux / macOS:**
```bash
source .venv/bin/activate
```

**Windows:**
```bash
.venv\Scripts\activate
```

### 3c. Install dependencies

```bash
pip install -r requirements.txt
```

> Note: `paddleocr` and `paddlepaddle` are large packages (~1–2 GB). This will take a while on first install.

### 3d. Start the OCR service

```bash
uvicorn worker:app --host 0.0.0.0 --port 8000
```

When you see:

```
INFO:     Uvicorn running on http://0.0.0.0:8000
```

the OCR service is ready.

---

## 4. Frontend Setup

### 4a. Install dependencies

```bash
cd frontend
npm install
```

### 4b. Create the environment file

```bash
cd frontend
```

Create a file called `.env` with this content:

```env
VITE_API_URL=/api
VITE_EMAILJS_SERVICE_ID=service_of96zk5
VITE_EMAILJS_TEMPLATE_ID=template_rkfhfqe
VITE_EMAILJS_PUBLIC_KEY=IY7me3rxNhT_2pvkU
VITE_OTP_RECIPIENT=bkadikuppur@gmail.com
```

### 4c. Start the frontend

```bash
npm run dev
```

When you see:

```
VITE ready in ... ms
➜  Local:   http://localhost:5173/
```

the frontend is ready.

---

## 5. Running All Three Services

Open **three separate terminal windows** and run one command in each:

**Terminal 1 — Backend:**
```bash
cd Pram-na-Kosha/backend
cargo run
```

**Terminal 2 — OCR Service:**
```bash
cd Pram-na-Kosha/ocr-service
source .venv/bin/activate
uvicorn worker:app --host 0.0.0.0 --port 8000
```

**Terminal 3 — Frontend:**
```bash
cd Pram-na-Kosha/frontend
npm run dev
```

---

## 6. Access the App

Open your browser and go to:

```
http://localhost:5173
```

### Login Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | `admin@pramanakosha.in` | `Admin@12345!` |
| Investigator | *(ask Adithya)* | *(ask Adithya)* |

> **Two-Factor Authentication:** After entering credentials, a 6-digit OTP will be sent to `bkadikuppur@gmail.com`. Enter it to complete login.

---

## 7. Verify Everything is Working

Open a browser tab and check:

- **Frontend:** http://localhost:5173 — should show the login page
- **Backend health:** http://localhost:5173/api/health — should return `{"status":"ok"}`
- **OCR health:** http://localhost:8000/health — should return `{"status":"ok"}`

---

## Troubleshooting

**Backend won't start — migration error:**
The database is hosted on Aiven (cloud). Make sure `DATABASE_URL` in `backend/.env` is correct and you have internet access.

**`cargo run` fails — missing dependencies:**
```bash
rustup update stable
```

**OCR install fails on Windows:**
Try installing CPU-only paddle:
```bash
pip install paddlepaddle -i https://pypi.tuna.tsinghua.edu.cn/simple
pip install paddleocr
```

**Frontend shows "Failed to fetch":**
Make sure the backend is running on port 3000 before starting the frontend.

**OTP email not arriving:**
Check spam folder. The email comes from the EmailJS account connected to `service_of96zk5`.
