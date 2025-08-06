# File: PRODUCTION_DEPLOYMENT_STEPS.md
# Path: /home/herb/Desktop/AndyLibrary/BowersWorld-com/PRODUCTION_DEPLOYMENT_STEPS.md
# Standard: AIDEV-PascalCase-2.1
# Created: 2025-08-05
# Last Modified: 2025-08-05 05:47PM

# 🚀 AndyLibrary Production Deployment - Complete Guide

## Current Status
✅ **Frontend deployed** to: https://callmechewy.github.io/BowersWorld-com/
✅ **Registration/Login system** tested and working
✅ **Social OAuth infrastructure** ready (Google/Facebook/GitHub)
✅ **Email verification** configured for HimalayaProject1@gmail.com

## 🎯 Next Steps (Choose Your Backend)

### Option 1: Render.com (Recommended - No CLI needed)

1. **Go to**: https://render.com
2. **Connect Repository**: Link `CallMeChewy/BowersWorld-com`
3. **Service Type**: Web Service
4. **Build Command**: `pip install -r requirements.txt`
5. **Start Command**: `python -m uvicorn Source.API.MainAPI:app --host 0.0.0.0 --port $PORT`
6. **Environment Variables**:
   ```
   BASE_URL=https://bowersworld.com
   SMTP_USERNAME=HimalayaProject1@gmail.com
   SMTP_PASSWORD=svah cggw kvcp pdck
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=465
   SMTP_USE_SSL=true
   ```

### Option 2: Railway.app (Modern, Fast)

1. **Go to**: https://railway.app
2. **Connect GitHub**: Link `CallMeChewy/BowersWorld-com`
3. **Deploy**: Automatic detection of Python app
4. **Set Environment Variables** (same as above)

### Option 3: Heroku (Traditional)

**Manual Web Interface**:
1. **Go to**: https://dashboard.heroku.com
2. **Create New App**: `andylibrary-api`
3. **Connect GitHub**: Link repository
4. **Enable Automatic Deploys**
5. **Set Config Vars** (same environment variables)

## 🔄 After Backend Deployment

### Step 1: Update Frontend API URLs

Once you have your backend URL (e.g., `https://andylibrary-api.onrender.com`):

```bash
cd /home/herb/Desktop/AndyLibrary/BowersWorld-com
./deploy.sh https://your-backend-url.com
git add .
git commit -m "Update API URLs for production backend"
git push origin main
```

### Step 2: Test Complete Workflow

1. **Visit**: https://callmechewy.github.io/BowersWorld-com/auth.html
2. **Register** with real email address
3. **Check email** from HimalayaProject1@gmail.com
4. **Click verification link**
5. **Login** to access setup page
6. **Test Google OAuth** social login

## 🔧 Frontend Status

**Current Frontend Features**:
- ✅ Fixed viewport layout (content in white container)
- ✅ Registration form with validation
- ✅ Login form with session management
- ✅ Social OAuth buttons (Google/Facebook/GitHub)
- ✅ Progressive Web App features
- ✅ Email verification workflow
- ✅ Setup page for database installation

**Live URL**: https://callmechewy.github.io/BowersWorld-com/auth.html

## 🎭 Social Login Configuration

**Already Configured**:
- **Google OAuth**: Ready with PKCE security
- **GitHub OAuth**: Configured but disabled
- **Facebook OAuth**: Configured but disabled

**To Enable** (after backend deployment):
1. Create OAuth apps with each provider
2. Update environment variables with client IDs/secrets
3. Test social login flow

## 📧 Email System

**Gmail Integration Ready**:
- **Email**: HimalayaProject1@gmail.com
- **App Password**: svah cggw kvcp pdck
- **SMTP**: Fully configured
- **Templates**: Verification, welcome, admin notifications

## 🎯 Success Criteria

Your system is production-ready when:
- [ ] User registers on live site
- [ ] Verification email received from HimalayaProject1@gmail.com
- [ ] User can login after verification
- [ ] Setup page loads and database downloads
- [ ] Social logins work (Google/Facebook/GitHub)
- [ ] Admin notifications sent to HimalayaProject1@gmail.com

## 💡 Recommendation

**Start with Render.com** - it's the easiest for non-CLI deployment:
1. Takes 5 minutes to set up
2. No command line required
3. Free tier available
4. Automatic HTTPS
5. Easy environment variable management

Once deployed, the **complete AndyLibrary system will be live** on BowersWorld.com!