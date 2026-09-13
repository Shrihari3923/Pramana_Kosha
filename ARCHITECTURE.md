# Pramana Kosha — Architecture

**PS:** SIH26190 — Secure Digital Document Management System for Legal & Investigation Documents
**Stack:** Rust (Axum) · PostgreSQL · JWT auth · SHA-256 hash-chained audit log · Ed25519 digital signatures

> This doc describes shape and reasoning, not full implementations. Each module owner writes their own code against these contracts.

---

## 1. Guiding principle

Everything in this system exists to answer one question convincingly on demo day:
**"If someone tampered with a document or its record, could we prove it?"**

Every architectural choice below serves that, and nothing else. Resist scope creep toward AI/blockchain buzzwords — the spec explicitly frames those as optional tools, not requirements.

---

## 2. High-level components

```
┌─────────────┐      ┌──────────────────┐      ┌─────────────┐
│  Frontend    │─────▶│   Axum API        │─────▶│  Postgres    │
│  (1 dev)     │◀─────│   (2 backend devs)│◀─────│  + file blobs│
└─────────────┘      └──────────────────┘      └─────────────┘
                             │
                             ├── auth.rs        (JWT + roles)
                             ├── documents.rs   (upload/retrieve/search)
                             ├── audit.rs       (hash-chained log)
                             ├── signatures.rs  (Ed25519 sign/verify)
                             └── error.rs
```

Flat domain-organized modules — matches your `rust_isa_platform` conventions. No repository/service layer abstraction; handlers talk to Postgres via `sqlx` directly.

---

## 3. Backend split (2 devs, parallel-safe)

**Dev A — Identity & Access**

- `auth.rs`: JWT access+refresh, SHA-256 hashed refresh token storage (per your existing pattern), bcrypt passwords
- `AuthenticatedUser` extractor, `role` enum on `users` (investigator / supervisor / court-clerk / admin — pick 3-4 fixed roles, no dynamic RBAC join tables, per your Capacity Connect learning)
- Case-level access scoping (a user only sees documents in cases they're assigned to)

**Dev B — Documents & Integrity**

- `documents.rs`: upload (multipart), metadata, versioning, full-text search (Postgres `tsvector`, not a search engine)
- `audit.rs`: the hash-chain — every action (upload, view, download, edit-metadata) writes an append-only row
- `signatures.rs`: Ed25519 keypair per authorized signer; sign document hash on finalize; verify endpoint

These two surfaces only touch each other at the `AuthenticatedUser` extractor boundary — genuinely parallelizable from day one.

---

## 4. The hash-chain (the core differentiator)

A single-writer append-only log, same idea as a git commit chain.

```
audit_log
├── id
├── prev_hash      -- hash of the previous row's full content
├── entry_hash     -- sha256(prev_hash + actor_id + action + document_id + timestamp)
├── actor_id
├── action          -- UPLOAD | VIEW | DOWNLOAD | EDIT_METADATA | SIGN
├── document_id
├── timestamp
```

- On insert: compute `entry_hash` from the previous row's `entry_hash` + this row's own fields.
- Verification endpoint: walk the whole chain, recompute each hash, compare. Any mismatch after a given row = everything after that point is provably altered.
- This is ~40 lines of logic. Do not reach for a crate that calls itself "blockchain."

## 5. Digital signatures (secondary differentiator, do after audit chain works)

- On document finalize (e.g. charge sheet submitted to court), the submitting officer's keypair signs `sha256(file_bytes)`.
- Signature + public key stored alongside the document.
- Verify endpoint re-hashes the current file and checks the signature — proves the file hasn't changed since signing, and proves _who_ signed it.
- Use `ed25519-dalek`. Do not build your own crypto primitives.

## 6. Storage

- File blobs: local disk under `/data/documents/{uuid}` for MVP (swap for S3-compatible storage post-hackathon if needed — don't build this now).
- Metadata, users, audit log, signatures: Postgres.

## 7. Non-goals for this build

Explicitly **not** doing, to protect the 10-day timeline:

- No AI/ML document classification (mention as "future work" in the pitch only)
- No real blockchain / distributed ledger
- No OCR (unless a document already has extracted text on upload, skip it)
- No mobile app
- No multi-tenant / multi-agency federation (single agency context only)
