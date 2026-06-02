# Docker Build Security Fixes

## Issues Resolved

### 1. ✅ Fixed: Tailwind CSS Native Binding Error
- **Problem**: `@tailwindcss/oxide` couldn't find native binding due to npm optional dependency bug
- **Solution**: Clean install (`npm ci`) rebuilds the optional dependencies correctly
- **Result**: Build now succeeds locally and in Docker

### 2. ✅ Fixed: Secrets Exposed in Build
- **Problem**: Sensitive data (CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET, DB_PASSWORD, SECRET_KEY) were being passed as ARG/ENV in Dockerfile
- **Violation**: Docker security best practice - secrets should never be in image layers (they persist)
- **Solution**: 
  - Created custom Dockerfile that does NOT expose secrets as build args
  - Secrets are now provided at runtime via environment variables only
  - Configure secrets in Railway dashboard under "Variables" section

### 3. ✅ Fixed: Undefined NIXPACKS_PATH Variable
- **Problem**: `$NIXPACKS_PATH` was undefined in generated Dockerfile
- **Solution**: Switched from Nixpacks builder to custom Dockerfile in `railway.json`
- **Benefit**: More control over build process and security

## How to Configure Secrets in Railway

1. Go to your Railway project dashboard
2. Click on your service
3. Go to "Variables" section
4. Add the following environment variables:
   - `CLOUDINARY_API_KEY`
   - `CLOUDINARY_API_SECRET`
   - `DB_PASSWORD`
   - `SECRET_KEY`
   - `JWT_SECRET`
   - `GEMINI_API_KEY` (if using AI features)

**Important**: These should be configured as railway environment variables, NOT hardcoded in the Dockerfile.

## What Changed

### Files Modified:
- **Dockerfile** (NEW): Custom multi-stage build that properly handles secrets
- **railway.json**: Changed builder from NIXPACKS to DOCKERFILE
- **nixpacks.toml**: Added documentation about secret handling

### Build Process:
The Dockerfile now:
1. Builds frontend (React/Vite) in Node.js container
2. Sets up Python environment with Django dependencies
3. Copies built frontend to backend
4. Collects static files
5. Starts Gunicorn server on port 8000

All secrets are injected at runtime by Railway, not during build.

## Testing Locally

```bash
# Build the Docker image locally
docker build -t academy:latest .

# Run with environment variables
docker run -e SECRET_KEY="test" \
           -e DB_PASSWORD="test" \
           -p 8000:8000 \
           academy:latest
```

## Next Steps

1. Push these changes to your repository
2. Update Railway environment variables in the dashboard
3. Trigger a new deployment
4. Verify the build succeeds without security warnings
