# ChainDock

**Pramana Kosha** — a secure digital document management system for legal & investigation
documents, built for Smart India Hackathon 2026, PS **SIH26190** (Ministry of Home
Affairs, NCRB / Women Safety Division, Team ASPIRE).

Law enforcement and investigative bodies handle FIRs, charge sheets, witness
statements, and forensic reports largely on paper or fragmented digital storage —
with no reliable way to prove a record hasn't been tampered with. ChainDock's core
differentiator is **provable tamper-evidence**: a SHA-256 hash-chained audit log
(not blockchain) plus Ed25519 digital signatures on finalized documents.

> Full specs live in [`PRD.md`](./PRD.md), [`ARCHITECTURE.md`](./ARCHITECTURE.md),
> [`DESIGN.md`](./DESIGN.md), and [`PHASES.md`](./PHASES.md). Read those before
> touching scope — several decisions (3 fixed roles, no dynamic RBAC, no real
> blockchain, no OCR) are deliberate, not oversights.

---

## Stack

| Layer     | Tech                                                                            |
| --------- | ------------------------------------------------------------------------------- |
| Backend   | Rust · Axum · PostgreSQL (`sqlx`)                                               |
| Auth      | JWT (access + refresh), bcrypt passwords, SHA-256 hashed/rotated refresh tokens |
| Integrity | SHA-256 hash-chained audit log, Ed25519 digital signatures (`ed25519-dalek`)    |
| Frontend  | Plain HTML/CSS/JS, 5 screens max                                                |
| Deploy    | Railway (backend), Netlify or Railway (frontend)                                |

## What's built

- **Auth & access** — register/login/refresh (JWT + rotating refresh tokens),
  3 fixed roles (investigator / supervisor / admin), case-level access scoping
  via `case_assignments`
- **Cases & documents** — case CRUD, multipart document upload with synchronous
  SHA-256 hashing, Postgres full-text search over document metadata
- **Hash-chained audit log** — every mutating action (`CREATE_CASE`, `ASSIGN_USER`,
  `UPLOAD`) writes an append-only, cryptographically linked row in the same
  transaction as the write it's logging. `GET /audit/verify-chain` walks the
  whole chain and reports pass/fail plus the exact break point if tampered.

## What's next

- Ed25519 sign/verify on document finalize (`signatures.rs`)
- `scripts/seed_tamper.sql` — deliberately-broken audit row for the live demo
- Frontend against the API surface in `DESIGN.md`

## Running locally

```bash
cd backend
cp env.example .env   # fill in DATABASE_URL / JWT_SECRET
cargo run              # runs migrations on boot, serves on :3000 (or $PORT)
```

Requires a reachable Postgres instance matching `DATABASE_URL`.

## Repo layout

See the folder structure in [`DESIGN.md`](./DESIGN.md#4-folder-structure) for the
full target layout (backend handlers split by module, frontend screens, migrations,
seed scripts).

## Contributing

See [`RULES.md`](./RULES.md) — no direct pushes to `main`, no sub-branches, every
change goes through a PR (markdown-only changes excepted).
