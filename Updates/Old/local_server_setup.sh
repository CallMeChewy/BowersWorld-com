# Local Development Server Setup
# Choose ONE of these methods to serve your files:

# METHOD 1: Python HTTP Server (Recommended)
cd /home/herb/Desktop/BowersWorld-com
python3 -m http.server 8080
# Then access: http://localhost:8080/Updates/firebase_auth_system.html

# METHOD 2: Node.js HTTP Server
# First install: npm install -g http-server
cd /home/herb/Desktop/BowersWorld-com
http-server -p 8080 -c-1
# Then access: http://localhost:8080/Updates/firebase_auth_system.html

# METHOD 3: PHP Server (if PHP installed)
cd /home/herb/Desktop/BowersWorld-com
php -S localhost:8080
# Then access: http://localhost:8080/Updates/firebase_auth_system.html

# METHOD 4: VS Code Live Server Extension
# 1. Install "Live Server" extension in VS Code
# 2. Right-click your HTML file → "Open with Live Server"

# WHY THIS IS NEEDED:
# - Google APIs require HTTP/HTTPS protocol
# - Firebase Auth needs proper origin headers
# - CORS policies block file:// protocol
# - Local server simulates production environment