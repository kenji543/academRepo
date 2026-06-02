# Railway Deployment Guide

This guide ensures your Django + React/Vite application deploys successfully on Railway with proper security configurations.

## ✅ Configuration Status

All sensitive information has been moved to environment variables. No secrets are hardcoded in the repository.

### Files Verified

- **nixpacks.toml** ✅ - Correctly configured with Node + Python providers and proper build commands
- **Procfile** ✅ - Correctly specified for Gunicorn with dynamic PORT binding
- **backend/settings.py** ✅ - All environment variables properly configured
- **api/views.py** ✅ - Cloudinary credentials loaded from environment variables

## 📋 Required Environment Variables for Railway

Set these in your Railway project's **Variables** settings:

### Core Django Settings
```
SECRET_KEY=<yH?VJ8Rc9hZp.UV*>
ENVIRONMENT=production
DEBUG=False
ALLOWED_HOSTS=*.railway.app,yourdomain.com
```

### Database (Railway Postgres Plugin)
Railway will automatically inject:
- `DATABASE_URL` - Set this in Railway's Postgres plugin configuration

Alternatively, provide individual variables:
- `DB_HOST`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME`
- `DB_PORT` (default: 5432)

### Cloudinary (Optional, for file uploads)
```
CLOUDINARY_URL=cloudinary://api_key:api_secret@cloud_name
```

Or use individual keys:
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

## 🚀 Deployment Steps

1. **Connect Repository**: Link your GitHub repo to Railway
2. **Set Environment Variables**: Add all required variables above
3. **Add Postgres Plugin** (if using database):
   - Click "Add" in the Plugins section
   - Select "PostgreSQL"
   - Railway will auto-inject `DATABASE_URL`
4. **Deploy**:
   - Push to your main branch
   - Railway auto-builds and deploys using Nixpacks

## 🏗️ Build Process

The nixpacks.toml specifies:
1. **Build Phase**:
   - `npm run build` - Builds React/Vite frontend
   - `python manage.py collectstatic --noinput` - Collects Django static files
2. **Start Command**:
   - `gunicorn backend.wsgi:application --bind 0.0.0.0:$PORT`

## 🔒 Security Checklist

- [x] No hardcoded SECRET_KEY
- [x] No hardcoded database passwords
- [x] No hardcoded Cloudinary API keys
- [x] DEBUG defaults to False in production
- [x] ALLOWED_HOSTS uses environment variable
- [x] All sensitive data in environment variables

## ✨ First-Time Setup

After deployment completes:

1. **Run Migrations**:
   ```bash
   railway run python manage.py migrate
   ```

2. **Create Admin User**:
   ```bash
   railway run python manage.py createsuperuser
   ```

3. **Verify Static Files**:
   - Check that CSS/JS loads correctly at `/assets/`

## 🐛 Troubleshooting

### Build Fails: `UndefinedVar: $NIXPACKS_PATH`
- This error is resolved - ensure no `.nixpacks/` cached directories in your workspace

### Application crashes: `SECRET_KEY not set`
- Add `SECRET_KEY` environment variable to Railway

### Database connection fails
- Verify `DATABASE_URL` or individual `DB_*` variables are set
- Confirm Postgres plugin is added to the project

### Static files not loading
- Ensure `python manage.py collectstatic` runs successfully in build phase
- Check STATIC_URL and STATIC_ROOT paths in settings.py

## 📚 Additional Resources

- [Railway Django Deployment](https://railway.app/docs/guides/django)
- [Nixpacks Documentation](https://nixpacks.com/)
- [Django Deployment Checklist](https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/)
