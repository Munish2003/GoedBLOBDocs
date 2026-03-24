# Stage 1: Builder
FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y curl \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app
COPY requirements.txt .
RUN uv pip install --system --no-cache -r requirements.txt

# Stage 2: Runtime (smaller image)
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Only runtime dependencies (no curl, no uv)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic1 \
    poppler-utils \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

WORKDIR /app
COPY . .
RUN mkdir -p /app/temp

EXPOSE 8002
CMD ["python", "server.py"]

