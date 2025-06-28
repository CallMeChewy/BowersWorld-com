# 🔥 Get Your Firebase Configuration

## Step 1: Navigate to Project Settings
From where you are now in Firebase Console:
1. Click the **gear icon** (⚙️) next to "Project Overview" in the left sidebar
2. Select **"Project settings"**

## Step 2: Get Your Web App Config
1. Scroll down to the **"Your apps"** section
2. If you see a web app already, click on it
3. If no web app exists, click **"Add app"** → **Web** (</>) → Name it "Anderson's Library"

## Step 3: Copy Configuration Object
You'll see a code block that looks like this:
```javascript
const firebaseConfig = {
  apiKey: "AIzaSyC_your_actual_key_here",
  authDomain: "bowersworld-digital-alexandria.firebaseapp.com",
  projectId: "bowersworld-digital-alexandria",
  storageBucket: "bowersworld-digital-alexandria.appspot.com",
  messagingSenderId: "123456789012",
  appId: "1:123456789012:web:abcdefghijklmnop"
};
```

## Step 4: Replace in Your Code
Take this config object and replace the placeholder in your HTML file:

**REPLACE THIS:**
```javascript
const firebaseConfig = {
    apiKey: "AIzaSyC-REPLACE-WITH-YOUR-ACTUAL-API-KEY",
    authDomain: "anderson-library-XXXXX.firebaseapp.com",
    // ... other placeholder values
};
```

**WITH YOUR ACTUAL VALUES**

## Step 5: Set Up Authorized Domains
1. In Firebase Console, go to **Authentication** → **Settings** → **Authorized domains**
2. Add these domains:
   - `localhost`
   - `127.0.0.1`
   - `bowersworld.com`
   - `www.bowersworld.com`
   - `yourusername.github.io` (replace with your GitHub username)

## Step 6: Test Locally
1. Start your local server:
   ```bash
   cd /home/herb/Desktop/BowersWorld-com
   python3 -m http.server 8080
   ```
2. Access: `http://localhost:8080/Updates/firebase_auth_system.html`
3. Check console for "🔥 Firebase initialized successfully"

## Troubleshooting
- **Can't find Project Settings?** Click the gear icon next to "Project Overview"
- **No web app?** Click "Add app" → Web → Follow the setup wizard
- **Still getting errors?** Make sure you're using `http://localhost:8080` not `file://`