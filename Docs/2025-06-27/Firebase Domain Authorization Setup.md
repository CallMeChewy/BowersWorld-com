# Firebase Domain Authorization Setup

## Step 1: Add Authorized Domains
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Authentication** → **Settings** → **Authorized domains**
4. Add these domains:
   ```
   localhost
   127.0.0.1
   bowersworld.com
   www.bowersworld.com
   yourusername.github.io  (replace with your GitHub username)
   ```

## Step 2: Enable Authentication Methods
1. Go to **Authentication** → **Sign-in method**
2. Enable **Email/Password**
3. Enable **Google** (optional but recommended)
   - Add your email as test user
   - Set support email

## Step 3: Check API Restrictions (if applicable)
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **APIs & Services** → **Credentials**
3. Find your API key → Click edit
4. Under "Application restrictions":
   - Select "HTTP referrers"
   - Add: `localhost:*`, `127.0.0.1:*`, `bowersworld.com/*`

## Step 4: Test Configuration
After making these changes:
1. Start local server: `python3 -m http.server 8080`
2. Access: `http://localhost:8080/Updates/firebase_auth_system.html`
3. Open browser console to check for errors
4. Try registering a test account

## Common Error Solutions

### "API key not valid"
- Double-check your Firebase config values
- Ensure API key is copied correctly (no extra spaces)
- Verify project ID matches exactly

### "auth/unauthorized-domain"
- Add your domain to authorized domains list
- Wait 5-10 minutes for changes to propagate
- Clear browser cache and try again

### "Failed to load resource: 400"
- Check if Firebase project is active
- Verify authentication is enabled
- Ensure billing is set up (if required)

### CORS errors
- Must use HTTP server, not file:// protocol
- Add proper domain authorization
- Check for mixed content (HTTP/HTTPS) issues