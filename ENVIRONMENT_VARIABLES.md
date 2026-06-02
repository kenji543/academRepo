# Environment Variables - Django Security Configuration

## Development Setup

```bash
# Copy to .env file in your project root
# Then load with: source .env  (macOS/Linux) or $env:VariableName (Windows)

# ========== Application =========
SECRET_KEY="your-super-secret-key-change-in-production"
DEBUG=True
ENVIRONMENT=development

# ========== Database ==========
# For local development (SQLite is default)
# DATABASE_URL not needed for SQLite
# For PostgreSQL:
DATABASE_URL="postgres://user:password@localhost:5432/academdb"

# ========== Caching & Security ==========
# If Redis is running locally
REDIS_URL="redis://localhost:6379"

# ========== Cloudinary (File Uploads) ==========
CLOUDINARY_URL="cloudinary://your_api_key:your_api_secret@your_cloud_name"

# ========== JWT Tokens ==========
JWT_SECRET="your-jwt-secret-key"

# ========== CORS ==========
ALLOWED_HOSTS="localhost,127.0.0.1,*.local"
```

---

## Railway Deployment

### Quick Setup

1. **Create a new Railway project**
2. **Add services:**
   - GitHub repo (auto-deploys on push)
   - PostgreSQL (for database)
   - Redis (for caching)

3. **Set environment variables in Railway Dashboard:**

```
SECRET_KEY=<generate-secure-key>
DEBUG=False
ENVIRONMENT=production
ALLOWED_HOSTS=*.railway.app,yourdomain.com
JWT_SECRET=<generate-secure-key>
CLOUDINARY_URL=cloudinary://key:secret@cloud

# Railway automatically injects these:
# - DATABASE_URL
# - REDIS_URL
# - PORT (8000)
```

### Generate Secure Keys

```bash
# Generate SECRET_KEY
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Generate JWT_SECRET
python -c "import secrets; print(secrets.token_hex(32))"
```

### Deploy Steps

```bash
# 1. Push to GitHub
git add requirements.txt backend/settings.py
git commit -m "Add Redis, django-axes, django-ratelimit configuration"
git push origin main

# 2. Railway automatically:
#    - Clones your repo
#    - Installs requirements.txt
#    - Runs migrations
#    - Starts the app
#    - Verifies system checks

# 3. Monitor logs
railway logs  # or use Railway dashboard
```

---

## Render Deployment

### Setup Steps

1. **Create Render Web Service:**
   - Connect GitHub repo
   - Build: `pip install -r requirements.txt`
   - Start: `gunicorn backend.wsgi:application`

2. **Create Render Redis:**
   - In Render Dashboard → Create → Redis
   - Copy the internal Redis URL

3. **Set Environment Variables:**

```
SECRET_KEY=<generate-secure-key>
DEBUG=False
ENVIRONMENT=production
DATABASE_URL=<from-attached-PostgreSQL>
REDIS_URL=<from-Redis-service>
ALLOWED_HOSTS=*.render.com,yourdomain.com
JWT_SECRET=<generate-secure-key>
CLOUDINARY_URL=cloudinary://key:secret@cloud
```

4. **Link services in render.yaml:**

```yaml
services:
  - type: web
    name: academy-api
    repo: https://github.com/youruser/academRepo
    envVars:
      - key: REDIS_URL
        fromService:
          type: redis
          name: academy-redis
          property: connectionString

  - type: redis
    name: academy-redis
```

---

## Fly.io Deployment

### Setup Steps

1. **Create app:**
   ```bash
   flyctl launch --dockerfile Dockerfile
   ```

2. **Provision Redis:**
   ```bash
   flyctl redis create --name academy-redis
   ```

3. **Attach Redis to app:**
   ```bash
   flyctl redis attach academy-redis
   ```

4. **Set secrets:**
   ```bash
   flyctl secrets set SECRET_KEY="$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')"
   flyctl secrets set JWT_SECRET="$(python -c 'import secrets; print(secrets.token_hex(32))')"
   flyctl secrets set ENVIRONMENT=production
   flyctl secrets set DEBUG=False
   flyctl secrets set ALLOWED_HOSTS="*.fly.dev,yourdomain.com"
   flyctl secrets set CLOUDINARY_URL="cloudinary://key:secret@cloud"
   ```

5. **Deploy:**
   ```bash
   flyctl deploy
   ```

---

## Vercel (Next.js/Static Frontend) + Separate API

If using Vercel for frontend + Railway/Render for Django API:

### Vercel .env.local

```
VITE_API_URL=https://academy-api.railway.app
VITE_ENVIRONMENT=production
```

### Django API (Railway/Render)

```
# Same as Railway/Render setup above
```

---

## Important Security Notes

### 🔒 DO

- ✅ Generate unique keys for each environment
- ✅ Store secrets in platform environment variables (not .env files)
- ✅ Rotate `SECRET_KEY` periodically
- ✅ Use strong `REDIS_URL` passwords
- ✅ Enable HTTPS (all platforms do this by default)
- ✅ Review `ALLOWED_HOSTS` - don't use `*` in production
- ✅ Keep Django and dependencies updated

### ❌ DON'T

- ❌ Commit `.env` files to Git
- ❌ Use same `SECRET_KEY` across environments
- ❌ Expose secrets in Docker builds
- ❌ Use `DEBUG=True` in production
- ❌ Set `CORS_ALLOW_ALL_ORIGINS=True` in production
- ❌ Use weak passwords
- ❌ Disable system checks

---

## Testing Environment Setup

```bash
# Create a test .env file
cat > .env.test << EOF
SECRET_KEY="test-key-not-for-production"
DEBUG=True
ENVIRONMENT=test
REDIS_URL="redis://localhost:6379/1"
DATABASE_URL="sqlite:///test.db"
EOF

# Run tests with test environment
export $(cat .env.test | xargs)
python manage.py test

# Verify system checks pass
python manage.py check
```

---

## Troubleshooting

### "REDIS_URL not set"

**On Railway:**
- Ensure Redis service is deployed
- Check: Infrastructure → Variables → Redis service should auto-inject `REDIS_URL`

**On Render:**
- Create Redis service
- Check: Environment → Internal Database URL

**On Fly.io:**
- Run: `flyctl redis attach academy-redis`

### "System checks still failing"

```bash
# Verify settings
python manage.py check

# Check REDIS_URL
echo $REDIS_URL

# Verify cache connectivity
python manage.py shell
>>> from django.core.cache import cache
>>> cache.set('test', '1', 60)
>>> cache.get('test')
```

### "Migrations not running"

**In Railway/Render/Fly.io:**
- Ensure your start command includes migration runner
- Example: `python manage.py migrate && gunicorn backend.wsgi:application`

Or add to Dockerfile:
```dockerfile
RUN python manage.py migrate
CMD ["gunicorn", "backend.wsgi:application", "--bind", "0.0.0.0:8000"]
```

---

## Platform-Specific References

- **Railway:** https://docs.railway.app/guides/django
- **Render:** https://docs.render.com/django
- **Fly.io:** https://fly.io/docs/languages-and-frameworks/django/
- **Vercel:** https://vercel.com/docs/concepts/get-started/deploy
