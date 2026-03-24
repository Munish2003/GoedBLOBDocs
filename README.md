# Vector Database Workflow API

A modern FastAPI-based document processing and vector storage service that extracts text from various document formats, generates embeddings using Azure OpenAI, and stores them in PostgreSQL with pgvector for semantic search.

## Features

- **Multi-format Document Support**: PDF, DOCX, PPTX, PNG, JPG/JPEG
- **Website Scraping**: Extract and embed content from web URLs
- **Semantic Search**: Vector similarity search using pgvector
- **Async Processing**: Fully asynchronous with batch embedding support
- **LangChain Integration**: Uses LangChain loaders and text splitters

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────┐
│   Client    │────▶│   FastAPI    │────▶│  Azure OpenAI    │
│  (Base64/   │     │   Server     │     │  (Embeddings)    │
│   URL)      │     └──────────────┘     └──────────────────┘
└─────────────┘            │
                           ▼
                    ┌──────────────┐
                    │  PostgreSQL  │
                    │  (pgvector)  │
                    └──────────────┘
```

## API Endpoints

| Endpoint      | Method | Description                              |
|---------------|--------|------------------------------------------|
| `/health`     | GET    | Health check with database connectivity |
| `/insert`     | POST   | Insert document into vector database    |
| `/retrieve`   | POST   | Semantic search over stored documents   |

## Installation

1. **Clone and navigate to the directory**
   ```bash
   cd vectordB_workflow
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   venv\Scripts\activate  # Windows
   # source venv/bin/activate  # Linux/Mac
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables** - Create a `.env` file:
   ```env
   # Azure OpenAI Configuration
   AZURE_OPENAI_API_KEY=your_api_key
   AZURE_OPENAI_API_INSTANCE_NAME=https://your-instance.openai.azure.com/
   AZURE_OPENAI_EMBEDDING_DEPLOYMENT=your_embedding_deployment
   AZURE_OPENAI_API_VERSION=2024-12-01
   AZURE_OPENAI_EMBEDDING_MODEL=text-embedding-ada-002

   # PostgreSQL Configuration
   POSTGRES_USER=your_username
   POSTGRES_PASSWORD=your_password
   POSTGRES_HOST=your_host
   POSTGRES_PORT=5432
   POSTGRES_DATABASE=your_database

   # Optional Settings
   CHUNK_SIZE=1000
   CHUNK_OVERLAP=200
   MAX_FILE_SIZE_MB=50
   EMBEDDING_BATCH_SIZE=20
   ```

## Database Setup

Ensure your PostgreSQL database has the `pgvector` extension and the required table:

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TYPE document_type_enum AS ENUM ('pdf', 'docx', 'pptx', 'png', 'jpg', 'jpeg', 'website');

CREATE TABLE education_vector_documents (
    id UUID PRIMARY KEY,
    document_name VARCHAR(255),
    document_url VARCHAR(2000),
    embedding vector(1536),
    content TEXT,
    job_id UUID,
    document_type document_type_enum,
    chunk_index INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ON education_vector_documents USING ivfflat (embedding vector_cosine_ops);
```

## Usage

### Start the Server
```bash
python server.py
# Or with uvicorn directly:
uvicorn server:app --host 0.0.0.0 --port 8002 --reload
```

### Insert a Document (Base64)
```bash
curl -X POST "http://localhost:8002/insert" \
  -H "Content-Type: application/json" \
  -d '{
    "document_name": "sample.pdf",
    "source_type": "base64",
    "document_content": "<base64_encoded_file>",
    "document_type": "pdf"
  }'
```

### Insert a Website
```bash
curl -X POST "http://localhost:8002/insert" \
  -H "Content-Type: application/json" \
  -d '{
    "source_type": "website",
    "document_content": "https://example.com/page",
    "document_name": "Example Page"
  }'
```

### Retrieve Documents
```bash
curl -X POST "http://localhost:8002/retrieve" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What is machine learning?",
    "limit": 5
  }'
```

## Request/Response Examples

### Insert Response
```json
{
  "success": true,
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "total_chunks": 15,
  "document_type": "pdf",
  "message": "Successfully processed 15 chunks from sample.pdf"
}
```

### Retrieve Response
```json
{
  "success": true,
  "count": 5,
  "query": "What is machine learning?",
  "documents": [
    {
      "id": "...",
      "document_name": "sample.pdf",
      "document_type": "pdf",
      "content": "Machine learning is...",
      "similarity_score": 0.89,
      "chunk_index": 3
    }
  ]
}
```

## Configuration Options

| Variable                  | Default     | Description                          |
|---------------------------|-------------|--------------------------------------|
| `CHUNK_SIZE`              | 1000        | Characters per text chunk            |
| `CHUNK_OVERLAP`           | 200         | Overlap between chunks               |
| `MAX_FILE_SIZE_MB`        | 50          | Maximum upload file size             |
| `EMBEDDING_BATCH_SIZE`    | 20          | Chunks per embedding API call        |

## Dependencies

- **FastAPI** - Web framework
- **Uvicorn** - ASGI server
- **LangChain** - Document loaders, text splitters, embeddings
- **asyncpg** - Async PostgreSQL client
- **Azure OpenAI** - Embedding generation

## License

MIT License
