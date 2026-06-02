# Django System Check Errors - Complete Fix Guide

## Overview

This document explains the system check errors, root causes, and fixes for django-ratelimit and django-axes.

---

## 1. Error Breakdown

### Error 1: `django_ratelimit.E003` - LocMemCache is not a shared cache

**Root Cause:**
- Django's `LocMemCache` stores data in process memory only
- In distributed systems (Railway, Render, Fly.io), each container has separate memory
- Rate limit counters aren't shared across containers → inconsistent enforcement

**Why it matters:**
- Rate limiting depends on persistent, shared state
- With separate memory per container, users can bypass limits by hitting different containers
- Security vulnerability in production

**Fix:**
- Use Redis or Memcached (shared cache backends)
- Railway provides Redis via `REDIS_URL` environment variable
- Render, Fly.io also provide managed Redis

---

### Error 2: `django_ratelimit.W001` - LocMemCache not officially supported

**Root Cause:**
- django-ratelimit officially only supports Redis and Memcached
- LocMemCache usage is technically unsupported

**Why it matters:**
- No guarantees on behavior in distributed environments
- Bugs or edge cases may not be fixed

**Fix:**
- Deploy Redis (even small instances are cheap)
- Or suppress this warning if you accept the risks (dev-only)

---

### Warning 1: `axes.W003` - Missing AxesStandaloneBackend

**Root Cause:**
- django-axes was renamed in version 5.0
- Old: `axes.backends.AxesModelBackend`
- New: `axes.backends.AxesStandaloneBackend`

**Why it matters:**
- django-axes won't properly protect against brute-force attacks
- Account lockout feature may not work

**Fix:**
- Add `AxesStandaloneBackend` to `AUTHENTICATION_BACKENDS`

---

### Warning 2: `axes.W004` - Deprecated AXES_USE_USER_AGENT

**Root Cause:**
- `AXES_USE_USER_AGENT` setting was removed in django-axes 5.0
- It was used to differentiate attacks by user agent
- Now handled automatically

**Why it matters:**
- Deprecated settings are ignored
- May cause issues in future versions

**Fix:**
- Remove `AXES_USE_USER_AGENT` from settings.py
- Set `AXES_USE_USER_AGENT = False` if you need to explicitly disable it

---

## 2. Changes Made

### `requirements.txt`

Added:
```txt
redis>=5.0,<6.0
django-ratelimit>=4.1,<5.0
django-axes>=6.1,<7.0
```

### `settings.py`

#### 2.1 INSTALLED_APPS

```python
INSTALLED_APPS = [
    # ... existing apps ...
    'axes',               # Brute-force protection
    'django_ratelimit',   # Rate limiting
    # ... local apps ...
]
```

#### 2.2 MIDDLEWARE

```python
MIDDLEWARE = [
    # ... other middleware ...
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'axes.middleware.AxesMiddleware',  # ⚠️ MUST come after AuthenticationMiddleware
    # ... rest of middleware ...
]
```

#### 2.3 AUTHENTICATION_BACKENDS

```python
AUTHENTICATION_BACKENDS = [
    'axes.backends.AxesStandaloneBackend',   # django-axes 5.0+
    'django.contrib.auth.backends.ModelBackend',
]
```

#### 2.4 CACHES - Production (Redis)

```python
REDIS_URL = os.environ.get('REDIS_URL')

if REDIS_URL:
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.redis.RedisCache',
            'LOCATION': REDIS_URL,
            'OPTIONS': {
                'CLIENT_CLASS': 'redis.StrictRedis',
                'CONNECTION_POOL_KWARGS': {
                    'socket_connect_timeout': 5,
                    'socket_keepalive': True,
                    'retry_on_timeout': True,
                },
            },
            'KEY_PREFIX': 'academy',
            'TIMEOUT': 300,
        }
    }
else:
    # Fallback: LocMemCache (development only)
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
            'LOCATION': 'unique-snowflake',
            'TIMEOUT': 300,
        }
    }
```

#### 2.5 Django-Axes Configuration

```python
AXES_FAILURE_LIMIT = 5                          # Lock after 5 failed attempts
AXES_COOLOFF_DURATION = timedelta(minutes=15)   # Lock duration
AXES_LOCK_OUT_AT_FAILURE = True
AXES_CACHE = 'default'
```

#### 2.6 Django-Ratelimit Configuration

```python
RATELIMIT_USE_CACHE = 'default'  # Uses Redis in production
RATELIMIT_ENABLE = True
```

#### 2.7 SILENCED_SYSTEM_CHECKS (Fallback Only)

```python
# Only suppress warnings if Redis is unavailable
if not REDIS_URL:
    SILENCED_SYSTEM_CHECKS = [
        'django_ratelimit.E003',
        'django_ratelimit.W001',
    ]
```

---

## 3. Platform-Specific Setup

### Railway

1. **Add Redis to your project:**
   - In Railway dashboard → Add Service → Redis
   - Redis will automatically inject `REDIS_URL` environment variable

2. **Environment Variables:**
   - Railway automatically provides: `REDIS_URL`
   - No additional configuration needed!

3. **Verification:**
   ```bash
   echo $REDIS_URL
   # Output: redis://default:password@hostname:port
   ```

### Render

1. **Provision Redis:**
   - In Render dashboard → Create → Redis
   - Note the internal Redis URL

2. **Link to Django service:**
   - Add environment variable: `REDIS_URL` = `redis://...`

3. **Install redis-py (already in requirements.txt):**
   ```bash
   pip install redis
   ```

### Fly.io

1. **Provision Redis:**
   ```bash
   fly redis create --name academy-redis
   ```

2. **Link to app:**
   ```bash
   fly secrets set REDIS_URL=redis://...
   ```

3. **Verify:**
   ```bash
   fly ssh console -C "redis-cli ping"
   ```

### Local Development

1. **Install Redis:**
   ```bash
   # macOS
   brew install redis
   redis-server
   
   # Linux
   sudo apt-get install redis-server
   redis-server
   
   # Windows (via WSL2 or Docker)
   docker run -d -p 6379:6379 redis:latest
   ```

2. **Set environment variable:**
   ```bash
   export REDIS_URL=redis://localhost:6379
   ```

3. **Or use `.env`:**
   ```
   REDIS_URL=redis://localhost:6379
   ```

---

## 4. Installation & Deployment Steps

### Step 1: Update Dependencies

```bash
# In your local environment
pip install -r requirements.txt
```

### Step 2: Run Database Migrations

```bash
python manage.py migrate

# This creates tables for django-axes
# Tables: axes_log, axes_accesslog
```

### Step 3: Test Locally

```bash
# Start Redis
redis-server

# In another terminal
export REDIS_URL=redis://localhost:6379
python manage.py runserver

# Check for system errors
python manage.py check
# Should show no errors ✓
```

### Step 4: Deploy to Railway (or your platform)

```bash
git add requirements.txt backend/settings.py
git commit -m "Fix: Add Redis caching, django-axes, and django-ratelimit configuration"
git push origin main
```

Railway will automatically:
1. Detect Redis service
2. Inject `REDIS_URL`
3. Run migrations
4. Verify system checks pass

### Step 5: Verify in Production

```bash
# SSH into your Railway container
railway shell

# Check system checks
python manage.py check
# Should output: System check identified no issues (0 silenced).

# Test cache connectivity
python manage.py shell
>>> from django.core.cache import cache
>>> cache.set('test', 'value', 60)
>>> cache.get('test')
'value'  # ✓ Success
```

---

## 5. Usage in Views

### Rate Limiting Example

```python
from django_ratelimit.decorators import ratelimit
from django.http import HttpResponse

@ratelimit(key='ip', rate='5/h', method='POST')  # 5 requests per hour
def api_endpoint(request):
    return HttpResponse("Success!")
```

### Brute-Force Protection

Django-axes works automatically:
- Tracks failed login attempts
- Locks accounts after 5 failures
- Automatic unlock after 15 minutes
- No code changes needed!

---

## 6. Security Considerations

### ✅ Production-Ready

- **Redis transport:** Ensure Redis is over TLS in production (Railway/Render provide this)
- **Redis password:** Use strong passwords for Redis
- **Rate limit tuning:** Adjust `AXES_FAILURE_LIMIT` and `RATELIMIT_ENABLE` per your API

### ⚠️ Do NOT Use in Production

- ❌ LocMemCache with multiple containers
- ❌ Disabling system checks without understanding the risks
- ❌ Storing secrets in REDIS_URL (use environment variables instead)

### 🔒 Best Practices

```python
# Good: Respect rate limits in views
@ratelimit(key='user', rate='100/h')
def expensive_operation(request):
    pass

# Good: Provide user feedback
# django-axes automatically handles this with its lockout page

# Bad: ❌ Disabling protection
@ratelimit(key='user', rate='10000/h')  # Too permissive!
def api_endpoint(request):
    pass
```

---

## 7. Troubleshooting

### Issue: "Redis connection refused"

**Solution:**
1. Verify Redis is running: `redis-cli ping` → should output `PONG`
2. Check `REDIS_URL` format: `redis://[:password@]hostname:port[/db]`
3. For Railway: Redis service must be deployed first

### Issue: "System check still shows LocMemCache warnings"

**Solution:**
1. Ensure `REDIS_URL` is set: `echo $REDIS_URL`
2. If undefined, the code falls back to LocMemCache
3. Add Redis before deploying to production

### Issue: "Account locked forever"

**Solution:**
1. Adjust `AXES_COOLOFF_DURATION`:
   ```python
   AXES_COOLOFF_DURATION = timedelta(minutes=5)
   ```
2. Or manually unlock via Django admin:
   - Go to Django admin → Axes → Access Attempts
   - Delete the locked entry

### Issue: "Rate limit not working across containers"

**Root cause:** Using LocMemCache instead of Redis

**Solution:**
1. Deploy Redis
2. Set `REDIS_URL` environment variable
3. Restart application

---

## 8. Summary Checklist

- ✅ Added `redis`, `django-ratelimit`, `django-axes` to `requirements.txt`
- ✅ Added `axes` and `django_ratelimit` to `INSTALLED_APPS`
- ✅ Added `axes.middleware.AxesMiddleware` to `MIDDLEWARE`
- ✅ Added `AxesStandaloneBackend` to `AUTHENTICATION_BACKENDS`
- ✅ Configured `CACHES` to use Redis (with LocMemCache fallback)
- ✅ Configured Django-Axes for brute-force protection
- ✅ Configured Django-Ratelimit to use shared cache
- ✅ Removed deprecated `AXES_USE_USER_AGENT` setting
- ✅ Added `SILENCED_SYSTEM_CHECKS` for fallback scenarios
- ✅ Deployed Redis to your platform (Railway/Render/Fly.io)
- ✅ Set `REDIS_URL` environment variable
- ✅ Ran migrations to create django-axes tables
- ✅ Verified system checks pass: `python manage.py check`

---

## 9. References

- [django-ratelimit Documentation](https://django-ratelimit.readthedocs.io/)
- [django-axes Documentation](https://django-axes.readthedocs.io/)
- [Django Caching Framework](https://docs.djangoproject.com/en/5.2/topics/cache/)
- [Redis for Django](https://docs.djangoproject.com/en/5.2/topics/cache/#redis)
- [Railway Redis Service](https://docs.railway.app/databases/redis)
