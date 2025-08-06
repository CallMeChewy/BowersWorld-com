#!/bin/bash

# AndyLibrary - Quick Deployment Script for BowersWorld.com

echo "🚀 AndyLibrary Deployment Script"
echo "=================================="

# Check if backend URL is provided
if [ -z "$1" ]; then
    echo "❌ Please provide your backend URL"
    echo "Usage: ./deploy.sh <backend-url>"
    echo "Example: ./deploy.sh https://andylibrary-api.herokuapp.com"
    exit 1
fi

BACKEND_URL=$1
echo "📡 Backend URL: $BACKEND_URL"

# Update API URLs in HTML files
echo "🔄 Updating API URLs..."
node update-api-urls.js "$BACKEND_URL"

# Create CNAME file for custom domain
echo "🌐 Creating CNAME for bowersworld.com..."
echo "bowersworld.com" > CNAME

# Create git deployment commands
echo ""
echo "📋 Next Steps:"
echo "=============="
echo "1. Copy all files to your BowersWorld-com repository"
echo "2. Run these git commands:"
echo ""
echo "   git add ."
echo "   git commit -m 'Deploy AndyLibrary to BowersWorld.com'"
echo "   git push origin main"
echo ""
echo "3. Set environment variables on your backend hosting:"
echo "   BASE_URL=https://bowersworld.com"
echo "   SMTP_USERNAME=HimalayaProject1@gmail.com"  
echo "   SMTP_PASSWORD=svah cggw kvcp pdck"
echo ""
echo "4. Test the complete user flow:"
echo "   - Visit https://bowersworld.com"
echo "   - Register with real email"
echo "   - Check email verification"
echo "   - Confirm admin notification"
echo ""
echo "✅ Deployment package ready!"

# Make the script executable
chmod +x deploy.sh