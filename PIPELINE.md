# Document Upload & Knowledge Base Pipeline

## Complete End-to-End Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│  DATAVERSE (Browser)                                                    │
│  document_upload.html                                                   │
│                                                                         │
│  User picks file → Validates type & size → Clicks "Upload to Azure"    │
└─────────────────────┬───────────────────────────────────────────────────┘
                      │
        ══════════════╪═══════════════════════════════════════════════
         STEP 1       │   POST /blob/upload-sas
        ══════════════╪═══════════════════════════════════════════════
                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  FastAPI Server (server.py)                                             │
│                                                                         │
│  Receives: { college_id, document_id, file_name }                      │
│  Does:     Generates a time-limited SAS token (15 min, write-only)     │
│  Returns:  { upload_url, blob_path }                                   │
└─────────────────────┬───────────────────────────────────────────────────┘
                      │
        ══════════════╪═══════════════════════════════════════════════
         STEP 2       │   PUT raw file bytes to upload_url
        ══════════════╪═══════════════════════════════════════════════
                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Azure Blob Storage                                                     │
│  Container: college-documents                                           │
│                                                                         │
│  Blob path: {college_id}/{document_id}_{filename}                      │
│  Stored as: Raw binary bytes (not base64)                              │
│  Overwrite: Same path = same blob = auto-replaced                      │
└─────────────────────┬───────────────────────────────────────────────────┘
                      │
        ══════════════╪═══════════════════════════════════════════════
         STEP 3       │   POST /insert-from-blob
        ══════════════╪═══════════════════════════════════════════════
                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  FastAPI Server (server.py) — /insert-from-blob                        │
│                                                                         │
│  Receives: { document_id, blob_path, document_name,                    │
│              document_type, source }                                    │
│                                                                         │
│  Processing pipeline:                                                   │
│                                                                         │
│  1. DOWNLOAD    Server downloads blob using account key (no SAS)       │
│                 Raw bytes stay in memory                                │
│                                                                         │
│  2. VALIDATE    File size check (max 20 MB)                            │
│                 Magic bytes check (PDF=%PDF, DOCX/PPTX=PK)            │
│                                                                         │
│  3. EXTRACT     Write bytes to temp file                               │
│                 PyPDFLoader / Docx2txtLoader / PPTXLoader reads it     │
│                 Plain text extracted, temp file auto-deleted            │
│                                                                         │
│  4. CHUNK       RecursiveCharacterTextSplitter                         │
│                 chunk_size=500, chunk_overlap=75                        │
│                 Example: 10-page PDF → ~40 chunks                      │
│                                                                         │
│  5. EMBED       Azure OpenAI text-embedding-3-small                    │
│                 Each chunk → 1536-dim vector                           │
│                 Batched (100 at a time)                                 │
│                                                                         │
│  6. UPSERT      Inside a PostgreSQL TRANSACTION:                       │
│                 → Check if document_id exists in DB                    │
│                 → If YES: DELETE all old chunks first                  │
│                 → INSERT all new chunks                                │
│                 → If anything fails: ROLLBACK (old data preserved)     │
└─────────────────────┬───────────────────────────────────────────────────┘
                      │
        ══════════════╪═══════════════════════════════════════════════
         STEP 4       │   Save blob_path to Dataverse
        ══════════════╪═══════════════════════════════════════════════
                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Dataverse                                                              │
│                                                                         │
│  zx_url field = blob_path (for future reads/previews)                  │
│  Record saved                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## What's Stored Where

| Storage | What | Format | Purpose |
|---------|------|--------|---------|
| **Azure Blob** | Original file (PDF/DOCX/PPTX) | Raw binary bytes | Source of truth, preview/download |
| **PostgreSQL** | Text chunks + vector embeddings | Plain text + float arrays | AI search & retrieval |
| **Dataverse** | Blob path (zx_url) | String | Links record to its file in blob |

---

## API Routes

| Method | Route | Purpose |
|--------|-------|---------|
| GET | `/health` | Health check + DB connectivity |
| POST | `/blob/upload-sas` | Generate write-only SAS token for blob upload |
| POST | `/blob/read-sas` | Generate read-only SAS token for blob preview |
| POST | `/insert-from-blob` | Download blob → chunk → embed → upsert into Postgres |
| POST | `/retrieve` | Vector similarity search across knowledge base |
| DELETE | `/document/{id}` | Remove all chunks for a document |

---

## Upsert Logic (Document Update)

When the same document is re-uploaded:

```
Old file: 10 pages → 40 chunks in Postgres
New file: 15 pages → 60 chunks

What happens (inside one transaction):
1. DELETE all 40 old chunks
2. INSERT 60 new chunks
3. If step 2 fails → ROLLBACK → old 40 chunks stay safe
```

---

## Security

| Layer | Protection |
|-------|-----------|
| CORS | Restricted to Dataverse domain only |
| SAS tokens | Time-limited (15 min upload, 5 min read), scoped to specific blob |
| File validation | Client: type + size check. Server: magic bytes + size + loader validation |
| Blob download | Uses account key server-side (never exposed to client) |

---

## File Structure

```
vectordB_workflow/
├── server.py              ← FastAPI server (all routes)
├── document_upload.html   ← Dataverse web resource (upload UI)
├── .env                   ← Azure + Postgres credentials
├── requirements.txt       ← Python dependencies
├── README.md              ← General project README
├── SECURITY_AUDIT.md      ← Security & performance audit
├── Dockerfile             ← Container deployment
└── temp_docs/             ← Temp directory (auto-cleaned)
```
