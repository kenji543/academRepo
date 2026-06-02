# Multi-stage build for production
FROM node:22-alpine AS node-builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY src ./src
COPY vite.config.ts ./

# Build frontend
RUN npm run build

# Python backend stage
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt ./

# Create virtual environment and install Python dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir -r requirements.txt

# Copy Django project
COPY manage.py ./
COPY backend ./backend
COPY api ./api

# Copy frontend build from node-builder
COPY --from=node-builder /app/dist ./dist

# Collect static files
RUN python manage.py collectstatic --noinput || true

# Set environment variables (do NOT include secrets here)
ENV PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import os; import urllib.request; urllib.request.urlopen('http://localhost:' + os.environ.get('PORT', '8000')).read()" || exit 1

# Expose port
EXPOSE 8000

# Start application
# Secrets MUST be provided via environment variables at runtime
CMD ["gunicorn", "backend.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
