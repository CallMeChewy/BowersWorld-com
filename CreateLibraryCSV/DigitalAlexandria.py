#!/usr/bin/env python3
import sys
from pathlib import Path

def main():
    try:
        from fastapi import FastAPI
        from fastapi.responses import HTMLResponse
        import uvicorn
        
        app = FastAPI(title="BowersWorld-com")
        
        @app.get("/", response_class=HTMLResponse)
        def home():
            return """
            <html><body style="font-family: Arial; margin: 40px;">
            <h1>🏛️ BowersWorld-com Digital Alexandria</h1>
            <p>✅ System Online and Ready!</p>
            <h3>Features:</h3>
            <ul>
                <li>Digital Library Management</li>
                <li>Full-text Search</li>
                <li>API Integration</li>
                <li>Modern Web Interface</li>
            </ul>
            <p><strong>Status:</strong> Operational</p>
            </body></html>
            """
        
        print("🌐 Starting BowersWorld-com...")
        print("   Access: http://localhost:8080")
        uvicorn.run(app, host="localhost", port=8080)
        
    except ImportError:
        print("⚠️ FastAPI not available. Install with:")
        print("   pip install fastapi uvicorn")

if __name__ == "__main__":
    main()
s