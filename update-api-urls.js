#!/usr/bin/env node

/**
 * Script to update API URLs in HTML files for production deployment
 * Usage: node update-api-urls.js <backend-url>
 * Example: node update-api-urls.js https://andylibrary-api.herokuapp.com
 */

const fs = require('fs');
const path = require('path');

const backendUrl = process.argv[2];

if (!backendUrl) {
    console.error('❌ Please provide the backend URL');
    console.error('Usage: node update-api-urls.js <backend-url>');
    console.error('Example: node update-api-urls.js https://andylibrary-api.herokuapp.com');
    process.exit(1);
}

console.log(`🔄 Updating API URLs to: ${backendUrl}`);

const htmlFiles = [
    'bowersworld.html',
    'auth.html', 
    'simple-register.html',
    'direct-register.html',
    'setup.html'
];

let updatedFiles = 0;

htmlFiles.forEach(filename => {
    const filepath = path.join(__dirname, filename);
    
    if (!fs.existsSync(filepath)) {
        console.log(`⏭️  Skipping ${filename} (not found)`);
        return;
    }
    
    let content = fs.readFileSync(filepath, 'utf8');
    
    // Replace local API URLs with production URLs
    const localUrls = [
        '/api/',
        'http://127.0.0.1:8081/api/',
        'http://localhost:8081/api/'
    ];
    
    let changed = false;
    localUrls.forEach(localUrl => {
        const regex = new RegExp(localUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g');
        if (content.match(regex)) {
            content = content.replace(regex, `${backendUrl}/api/`);
            changed = true;
        }
    });
    
    if (changed) {
        fs.writeFileSync(filepath, content);
        console.log(`✅ Updated ${filename}`);
        updatedFiles++;
    } else {
        console.log(`⏭️  No changes needed in ${filename}`);
    }
});

console.log(`\n🎉 Updated ${updatedFiles} files with backend URL: ${backendUrl}`);
console.log('📝 Don\'t forget to:');
console.log('   1. Deploy your backend to the specified URL');
console.log('   2. Set environment variables on your hosting platform');
console.log('   3. Test the complete user flow');