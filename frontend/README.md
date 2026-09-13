# ChainDock — Secure Digital Document Management System

> **SIH Problem Statement: SIH26190**  
> *Secure Digital Document Management System for Legal and Investigation Documents*

ChainDock is a zero-trust, court-admissible forensic document and physical evidence management platform engineered for legal registries, cyber forensics laboratories, and investigation agencies.

Built with **React 18**, **Vite**, **TypeScript**, **Tailwind CSS**, and **Web Crypto API (SHA-256 + Ed25519)**, following the institutional Stitch design system (Project ID: `14765691373529962892`).

---

## Key Features

1. **Cryptographic Content-Addressing (SHA-256)**:
   - Every deposited document is fingerprinted client-side via the Web Crypto API prior to transmission.
   - Court-admissible certificates generated in compliance with **Section 65B of the Indian Evidence Act**.

2. **Ed25519 Asymmetric Digital Signatures**:
   - Edwards-curve Digital Signature Algorithm (RFC 8032) signing for non-repudiation by investigating officers.
   - Hardware Security Module (HSM) cluster trust anchors (FIPS 140-2 Level 3).

3. **Merkle Hash-Chain Audit Ledger**:
   - Sequential, tamper-evident block linkages. Any historical record alteration invalidates subsequent block hashes.
   - Live ledger verification and tamper detection telemetry.

4. **Biometric Dual-Authorization Chain-of-Custody**:
   - Complete tracking of physical and digital forensic items with transfer verification, witness countersignatures, and vault custody records.

5. **Role-Based Access Control (RBAC)**:
   - **`INVESTIGATOR`**: Ingest evidence, register case dockets, upload forensic files, initiate custody transfers.
   - **`SUPERVISOR`**: Review case integrity, approve chain handovers, issue Section 65B certificates.
   - **`ADMIN`**: Provision officers, inspect HSM cryptographic clusters, and manage identity keys.
   - **One-Click Evaluator Switcher**: Instantly switch between officer profiles directly in the navigation bar.

6. **Interactive Tamper Simulation Sandbox (Evaluator Highlight)**:
   - **Document Viewer**: Click *"Simulate Bit-Flip Tamper"* on any document to flip bytes and trigger real-time SHA-256 mismatch detection and red warning banners.
   - **Audit Explorer**: Click *"Inject Fault at Block #150"* to corrupt historical ledger blocks and observe Merkle chain fault isolation.

---

## Directory Structure

```
chaindock-frontend/
├── public/
│   ├── logo/
│   │   └── logo.svg                 # Institutional ChainDock shield emblem
│   └── favicon.ico
├── src/
│   ├── assets/                      # Icons, badges, and illustrations
│   ├── components/
│   │   ├── ui/                      # Button, Input, Card, Table, Modal, Badge
│   │   ├── layout/                  # Sidebar, Navbar (with RBAC Switcher), AppShell
│   │   ├── cases/                   # CaseCard, CaseList, CaseForm, CaseTimeline, CaseStatusBadge
│   │   ├── documents/               # DocumentViewer, DocumentList, DocumentUpload, DocumentMetadata, DocumentVersions
│   │   ├── evidence/                # EvidenceCard, EvidenceList, EvidenceUpload, ChainOfCustodyLog, ChainOfCustodyTimeline
│   │   ├── audit/                   # AuditLogViewer, AuditHistoryTable, AuditFilter, AuditVerificationBadge
│   │   └── security/                # HashVerificationCard, IntegrityStatus, DigitalSignatureStatus, CertificateViewer
│   ├── pages/
│   │   ├── auth/Login.tsx           # Institutional authentication & evaluator quick-sign-in
│   │   ├── Dashboard.tsx            # Executive Forensic Intelligence Hub
│   │   ├── Cases.tsx                # Investigation Dockets Registry (Grid/Table view)
│   │   ├── CaseDetails.tsx          # Case Master with Documents, Evidence & Timeline tabs
│   │   ├── Documents.tsx            # Sealed Document Catalog with filter & search
│   │   ├── DocumentDetails.tsx      # Document Viewer + Tamper Simulation Sandbox
│   │   ├── Evidence.tsx             # Chain-of-Custody Catalog & Handover Workflow
│   │   ├── AuditLog.tsx             # Merkle Block Verification & Malfeasance Injection
│   │   ├── Security.tsx             # HSM Cluster, Ed25519 Keys, FIPS 140-2 Compliance
│   │   └── Users.tsx                # Personnel Directory & Officer Provisioning
│   ├── services/
│   │   ├── api.ts                   # Backend fetch client with mock fallback
│   │   ├── auth.ts                  # Authentication & preset credentials
│   │   ├── cases.ts                 # Case docket CRUD & status transitions
│   │   ├── documents.ts             # SHA-256 computation, Ed25519 signing, tamper toggle
│   │   ├── evidence.ts              # Evidence catalog & dual-custody transfers
│   │   └── audit.ts                 # Merkle block chain & verification engine
│   ├── context/
│   │   └── AuthContext.tsx          # Global authentication & role state provider
│   ├── hooks/
│   │   ├── useAuth.ts               # Hook for accessing user, role, and permissions
│   │   └── useApi.ts                # Asynchronous data fetching utility
│   ├── routes/
│   │   ├── ProtectedRoute.tsx       # Route guard with session verification
│   │   └── AppRoutes.tsx            # Central application router
│   ├── types/
│   │   └── index.ts                 # Complete TypeScript domain interfaces
│   ├── utils/
│   │   ├── formatters.ts            # Hash truncator, date & size formatters
│   │   ├── validation.ts            # Client-side Web Crypto SHA-256 hasher
│   │   └── permissions.ts           # Fine-grained RBAC permission matrix
│   ├── App.tsx                      # Root provider tree
│   ├── main.tsx                     # React 18 DOM mount
│   └── index.css                    # Tailwind design system & institutional typography
├── tailwind.config.js               # Stitch color tokens (#0E2520, #C3E8D2, #FFF9ED)
├── vite.config.ts                   # Vite bundler configuration
└── package.json                     # Dependencies & scripts
```

---

## Quick Start Guide

### Prerequisites
- Node.js (v18 or higher)
- npm (v9 or higher)

### 1. Install Dependencies
```bash
cd chaindock-frontend
npm install
```

### 2. Configure Environment
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
Default configuration:
```ini
VITE_API_URL=http://127.0.0.1:3001
VITE_APP_NAME=ChainDock
VITE_ENABLE_MOCK_FALLBACK=true
```
*(When `VITE_ENABLE_MOCK_FALLBACK=true`, the entire application runs autonomously in-browser with full cryptographic validation even if the Axum backend service is offline).*

### 3. Start Development Server
```bash
npm run dev
```
Open [http://localhost:5173](http://localhost:5173) in your browser.

### 4. Build for Production
```bash
npm run build
```

---

## Hackathon Pitch & Evaluator Demo Script

### Step 1: Sign In & Role Clearance
- Go to `/login`. Click on **"Priya Sharma (Investigator)"** or **"Rajesh Kumar (Supervisor)"** to instantly initialize an authenticated session with appropriate judicial clearance.

### Step 2: Explore the Forensic Intelligence Hub
- Review active dockets, sealed evidence counts, and the live cryptographic audit telemetry bus on the **Dashboard** (`/dashboard`).

### Step 3: Zero-Trust Tamper Detection Demo
1. Navigate to **Documents** (`/documents`).
2. Select any document (e.g., *"CCTV Surveillance Capture - Sector 4"*).
3. Under the master actions, click **"Simulate Bit-Flip Tamper"**.
4. **Observe the immediate response**:
   - The file integrity status flips from <span style="color:green">VERIFIED</span> to <span style="color:red">TAMPERED</span>.
   - The red tamper banner triggers across the document preview.
   - The **Hash Verification Card** displays a live mismatch between the original SHA-256 seal and the recalculated hash.
5. Click **"Restore Original Bytes"** to return the file to a court-verified state.
6. Click **"Sec 65B Certificate"** to view the court-admissible Section 65B electronic record certificate.

### Step 4: Merkle Hash-Chain Audit Ledger & Fault Injection
1. Navigate to **Audit Log** (`/audit`).
2. Click **"Run Full Ledger Verification"** — observe all blocks verified intact.
3. Click **"Inject Fault at Block #150"** (simulates an unauthorized internal database byte change).
4. The Merkle verification engine immediately catches the breakage:
   - Identifies the exact block broken (`Block #150`).
   - Declares `ENTRY_HASH_MISMATCH`.
   - Quarantines the broken branch.
5. Click **"Restore Chain Integrity"** to reseal the Merkle chain.

### Step 5: Dual-Custody Physical Evidence Transfer
1. Navigate to **Evidence** (`/evidence`).
2. Click **"Initiate Handover"** on any item to open the dual-authorized custody transfer modal.
3. Select releasing custodian, receiving officer, reason for transfer, and submit to generate a cryptographic transaction hash.

---

## Statutory & Regulatory Admissibility
- **Section 65B, Indian Evidence Act (1872)** — Admissibility of Electronic Records.
- **NIST FIPS 180-4** — Secure Hash Standard (SHA-256).
- **RFC 8032** — Edwards-Curve Digital Signature Algorithm (Ed25519).
- **FIPS 140-2 Level 3** — Hardware Security Module (HSM) boundary protection.
- **CJIS Policy 5.9** — Criminal Justice Information Services auditability and access control.
