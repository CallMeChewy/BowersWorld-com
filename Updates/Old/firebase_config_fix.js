// Firebase Configuration Fix - Replace in your HTML file
// Location: Inside the <script type="module"> section

// REPLACE THIS SECTION:
const firebaseConfig = {
    // OLD - REMOVE THESE PLACEHOLDER VALUES:
    // apiKey: "your-api-key-here",
    // authDomain: "your-project.firebaseapp.com",
    // projectId: "your-project-id",
    
    // NEW - ADD YOUR ACTUAL FIREBASE CONFIG:
    // Go to Firebase Console → Project Settings → General → Your apps
    // Copy the config object and paste here:
    
    apiKey: "AIzaSyC-your-actual-api-key-here",
    authDomain: "anderson-library-12345.firebaseapp.com", 
    projectId: "anderson-library-12345",
    storageBucket: "anderson-library-12345.appspot.com",
    messagingSenderId: "123456789012",
    appId: "1:123456789012:web:abcdef123456789"
};

// Steps to get your actual config:
// 1. Go to https://console.firebase.google.com
// 2. Select your project (or create new one)
// 3. Click gear icon → Project settings
// 4. Scroll down to "Your apps" section
// 5. If no web app exists, click "Add app" → Web
// 6. Copy the firebaseConfig object
// 7. Replace the placeholder values above