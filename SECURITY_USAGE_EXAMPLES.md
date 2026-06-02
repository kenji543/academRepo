# Django Security Features - Usage Examples

## Rate Limiting with django-ratelimit

### Example 1: IP-based Rate Limit on API Endpoint

```python
# api/views.py
from django.http import JsonResponse
from django_ratelimit.decorators import ratelimit
from rest_framework.decorators import api_view

@ratelimit(key='ip', rate='100/h', method='POST')
@api_view(['POST'])
def create_item(request):
    """
    Create an item.
    Limit: 100 requests per hour per IP
    """
    # Your code here
    return JsonResponse({'status': 'created'})
```

### Example 2: User-based Rate Limit

```python
@ratelimit(key='user', rate='50/h', method='POST')
@api_view(['POST'])
def submit_form(request):
    """
    Limit: 50 requests per hour per authenticated user
    """
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Authentication required'}, status=401)
    # Your code here
    return JsonResponse({'status': 'submitted'})
```

### Example 3: Programmatic Rate Limit Check

```python
from django_ratelimit.decorators import ratelimit
from django.http import JsonResponse

def get_rate_limit_key(request):
    """Custom rate limit key based on user + IP"""
    if request.user.is_authenticated:
        return f"user:{request.user.id}"
    return f"ip:{request.META['REMOTE_ADDR']}"

@api_view(['POST'])
def sensitive_operation(request):
    """Manual rate limit checking"""
    from django_ratelimit.core import is_ratelimited
    
    key = get_rate_limit_key(request)
    if is_ratelimited(request, key, '5/h', method='POST', rate=5):
        return JsonResponse(
            {'error': 'Too many requests. Try again later.'},
            status=429
        )
    
    # Your code here
    return JsonResponse({'status': 'success'})
```

### Example 4: Different Limits for Different Endpoints

```python
@ratelimit(key='ip', rate='1000/h')  # General endpoint
@api_view(['GET'])
def list_items(request):
    pass

@ratelimit(key='ip', rate='100/h')  # Expensive operation
@api_view(['POST'])
def bulk_import(request):
    pass

@ratelimit(key='ip', rate='10/h')  # Very expensive operation
@api_view(['POST'])
def generate_report(request):
    pass
```

---

## Brute-Force Protection with django-axes

### How django-axes Works (Automatic)

Django-axes automatically protects `/admin/login/` and any view using Django's authentication.

**Features:**
- Tracks failed login attempts
- Locks accounts after 5 failures (configurable)
- Auto-unlocks after 15 minutes (configurable)
- Logs all attempts to database
- Works transparently (no code changes needed!)

### Example 1: Default Admin Protection

```python
# urls.py
from django.contrib import admin

urlpatterns = [
    path('admin/', admin.site.urls),  # ✓ Automatically protected by django-axes
]
```

When a user fails to log in 5 times:
- `HttpResponse(403 Forbidden)` - Lockout page shown
- Attempt logged to `AxesStandaloneBackend`
- User locked for 15 minutes

### Example 2: Custom Authentication View

```python
# api/views.py
from django.contrib.auth import authenticate, login
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status

@api_view(['POST'])
def custom_login(request):
    """
    Custom login endpoint.
    django-axes middleware automatically tracks failed attempts.
    """
    username = request.data.get('username')
    password = request.data.get('password')
    
    user = authenticate(request, username=username, password=password)
    
    if user is not None:
        login(request, user)
        return Response({'message': 'Logged in successfully'})
    else:
        # ✓ django-axes automatically logs this failure
        # After 5 failures, user is locked
        return Response(
            {'error': 'Invalid credentials'},
            status=status.HTTP_401_UNAUTHORIZED
        )
```

### Example 3: Check If User Is Locked

```python
# api/views.py
from axes.models import AccessLog
from axes.lockouts import get_lockout_for_ip_address, get_lockout_for_username

def check_lockout_status(request):
    """Check if a user is currently locked out"""
    username = request.GET.get('username')
    ip_address = request.META['REMOTE_ADDR']
    
    # Check IP lockout
    ip_lockout = get_lockout_for_ip_address(ip_address)
    if ip_lockout:
        return Response({
            'locked': True,
            'ip_locked': True,
            'until': ip_lockout.get('expiration_time')
        })
    
    # Check username lockout
    user_lockout = get_lockout_for_username(username)
    if user_lockout:
        return Response({
            'locked': True,
            'user_locked': True,
            'until': user_lockout.get('expiration_time')
        })
    
    return Response({'locked': False})
```

### Example 4: Admin Interface for Access Logs

Access logs are automatically available in Django admin:

```python
# django/contrib/admin
# URL: /admin/axes/accesslog/

# View all failed attempts
# Filter by IP, username, attempt date
# Manually unlock by deleting entry
```

---

## Combined: Rate Limiting + Brute-Force Protection

### Example: Protected API Endpoint

```python
# api/views.py
from django_ratelimit.decorators import ratelimit
from django.contrib.auth.decorators import login_required
from rest_framework.decorators import api_view

@ratelimit(key='user', rate='100/h', method='POST')  # Rate limit by user
@login_required  # ← django-axes protects login automatically
@api_view(['POST'])
def create_item(request):
    """
    Flow:
    1. User tries to log in
       - django-axes tracks failed attempts
       - After 5 failures: account locked for 15 minutes
    
    2. User posts to /api/items/
       - django-ratelimit enforces 100 requests/hour per user
       - If exceeded: HTTP 429 Too Many Requests
    """
    # Your code here
    return Response({'id': 1, 'name': 'item'})
```

---

## Configuration Reference

### Django-Axes Settings

```python
# settings.py

# Failure limit before lockout
AXES_FAILURE_LIMIT = 5

# How long to lock the account
AXES_COOLOFF_DURATION = timedelta(minutes=15)

# Enable/disable the feature
AXES_LOCK_OUT_AT_FAILURE = True

# What info to track (IP, username, user agent, etc.)
AXES_LOCKOUT_TEMPLATE = None  # Use default; or set custom template path

# Cache backend for storing locks (must be shared in production)
AXES_CACHE = 'default'  # Must point to Redis, not LocMemCache

# Signal fired when user is locked
def handle_user_locked(sender, request, username, ip_address, **kwargs):
    print(f"User {username} locked from IP {ip_address}")

from axes.signals import user_locked_out
user_locked_out.connect(handle_user_locked)
```

### Django-Ratelimit Settings

```python
# settings.py

# Enable/disable rate limiting
RATELIMIT_ENABLE = True

# Cache backend to use (must be shared in production)
RATELIMIT_USE_CACHE = 'default'  # Must point to Redis, not LocMemCache

# Raise exception instead of returning 429
RATELIMIT_RAISE_EXCEPTION = False
```

---

## Testing Rate Limits & Locks Locally

### Test Rate Limiting

```bash
# Terminal 1: Start server
python manage.py runserver

# Terminal 2: Simulate requests
for i in {1..150}; do
    curl -X POST http://localhost:8000/api/test/ \
         -H "Content-Type: application/json" \
         -d '{"data": "test"}'
    echo "Request $i"
done

# After 100 requests in 1 hour, subsequent requests return 429
```

### Test Brute-Force Lock

```bash
# Test login lockout
for i in {1..10}; do
    curl -X POST http://localhost:8000/api/login/ \
         -H "Content-Type: application/json" \
         -d '{"username": "admin", "password": "wrong"}'
    echo "Attempt $i"
done

# After 5 failed attempts, returns 403 Forbidden
```

### Check Cache & Locks

```python
# Python shell
python manage.py shell

>>> from django.core.cache import cache
>>> cache.get('axes:*')  # View all locks

>>> from axes.models import AccessLog
>>> AccessLog.objects.filter(username='admin').order_by('-attempt_time')[:5]
# View recent login attempts
```

---

## Best Practices

1. **Always use Redis in production** - LocMemCache breaks across containers
2. **Tune rate limits for your API** - Too strict = bad UX; too loose = security risk
3. **Monitor failed attempts** - Check Django admin → Axes → Access Attempts regularly
4. **Notify users** - Show lockout messages: "Too many attempts. Try again in 15 minutes"
5. **Test before deploying** - Verify locks work in staging before production
6. **Use strong passwords** - Rate limits + strong passwords = defense in depth

---

## Monitoring & Alerts

### View Failed Attempts

```python
# Get recent failed attempts
from axes.models import AccessLog

recent_attempts = AccessLog.objects.filter(
    attempt_time__gte=now() - timedelta(hours=1)
).order_by('-attempt_time')

for attempt in recent_attempts:
    print(f"{attempt.username} from {attempt.ip_address} - {attempt.attempt_time}")
```

### Alert on Multiple Failures

```python
from axes.signals import user_locked_out
from django.core.mail import send_mail

def alert_on_lockout(sender, request, username, ip_address, **kwargs):
    """Send email when user is locked out"""
    send_mail(
        'Account Locked',
        f'Multiple failed login attempts for {username} from {ip_address}',
        'security@example.com',
        ['admin@example.com'],
    )

user_locked_out.connect(alert_on_lockout)
```

---

## Security Checklist

- ✅ Redis deployed in production
- ✅ `REDIS_URL` environment variable set
- ✅ `AXES_FAILURE_LIMIT` tuned appropriately
- ✅ `AXES_COOLOFF_DURATION` reasonable (15-30 min)
- ✅ Rate limits applied to sensitive endpoints
- ✅ Failed attempts logged and monitored
- ✅ Strong passwords enforced
- ✅ HTTPS enabled in production
- ✅ System checks pass: `python manage.py check`
