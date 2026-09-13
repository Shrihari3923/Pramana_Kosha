# Pramana Kosha — Product Requirements Document

**PS:** SIH26190 · **Sponsor:** Ministry of Home Affairs (NCRB, Women Safety Division) Team ASPIRE

---

## 1. Problem (as given by the PS)

Law enforcement, courts, and investigative bodies handle FIRs, investigation records, witness statements, charge sheets, court filings, evidence records, and forensic reports — largely on paper or fragmented digital storage. This causes:

- Slow document retrieval
- Unauthorized access to confidential case material
- Tampering risk with no way to prove it
- No version control
- Poor cross-department collaboration
- Weak auditability for legal/compliance purposes

_(Note: the official spec's "Expected Solution" field is a copy-paste artifact referencing an unrelated police-asset-tracking PS. We build to the "Description" section, which is internally consistent — flag this to your SPOC/mentor.)_

## 2. Goal for internal round

Convince judges we understand the real problem (evidentiary integrity, not just file storage) and can build it. MVP must **demo a tamper attempt and prove it was caught** — that single moment is the pitch's centerpiece.

## 3. Users / roles (keep to 3, no more)

| Role             | Can do                                                                                                 |
| ---------------- | ------------------------------------------------------------------------------------------------------ |
| **Investigator** | Upload documents to their assigned case, view/search within their case                                 |
| **Supervisor**   | Everything an investigator can, plus view audit trail, approve/finalize documents (triggers signature) |
| **Admin**        | User management, view all cases, run chain-verification                                                |

## 4. Core features (MVP scope)

1. **Auth** — login, JWT session, role-based routing
2. **Case & document upload** — create a case, upload documents against it with metadata (type, date, description)
3. **Access control** — a user only sees documents in cases they're assigned to
4. **Search** — full-text search across document metadata/description within accessible cases
5. **Audit trail** — every action logged in the hash chain; supervisor/admin can view a case's full trail
6. **Tamper detection demo** — a "Verify Integrity" button that walks the chain and reports pass/fail, plus a deliberately-broken seed record to demonstrate detection live
7. **Digital signature on finalize** — supervisor "finalizes" a document, which signs it; a "Verify Signature" check confirms authenticity

## 5. Explicitly out of scope for MVP

- AI-based document classification or OCR
- Real blockchain / multi-node consensus
- Mobile app
- Multi-agency federation / interoperability with external systems
- Notification system (email/SMS)

(These go in the "Future Scope" slide of the pitch — mentioning them shows awareness without inflating your build risk.)

## 6. Success criteria for internal round

- Live demo: upload a document → view audit trail → attempt a simulated tamper → verification catches it
- Clear articulation of _why_ this isn't "just blockchain" or "just AI" — the pitch should show you understand the actual security primitives at work
- Working RBAC demoed with at least 2 different role logins

## 7. Success criteria for MVP (10-day, if selected)

- All 7 core features functional end-to-end
- Deployed (Railway backend, Netlify or Railway static frontend)
- Public repo, README with screenshots, small descriptive commits per milestone (per your usual workflow)
