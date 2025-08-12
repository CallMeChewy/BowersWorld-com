#!/bin/bash
# File: setup-dev-symlinks.sh
# Path: /home/herb/Desktop/BowersWorld-com/setup-dev-symlinks.sh
# Standard: AIDEV-PascalCase-2.1
# Created: 2025-08-12
# Last Modified: 2025-08-12 02:18PM

# BowersWorld-com Development Symlink Setup Script
# 
# This script restores the development environment symlinks that are intentionally 
# excluded from Git to prevent GitHub Pages deployment issues.
#
# BACKGROUND:
# - Development systems use symlinks to share resources (Standards, Common scripts, external data)
# - These symlinks point to local paths that don't exist on GitHub Actions runners
# - Committing them causes: tar: ./path/to/link: File removed before we read it
# - Solution: Keep symlinks local via .gitignore, restore via this script

echo "🔗 BowersWorld-com Development Symlink Setup"
echo "============================================="

# Base paths for shared resources (adjust these to your system)
SHARED_BASE="$HOME/Desktop"
STANDARDS_PATH="$SHARED_BASE/D E S K T O P Miscellaneous/Session Startup Kit"
COMMON_SCRIPTS_PATH="$SHARED_BASE/BashScripts/Scripts/Common"

# Project-specific symlinks
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📁 Creating essential development symlinks..."

# Data/Books - Link to Anderson's Library Collection  
if [ ! -L "$PROJECT_ROOT/Data/Books" ] && [ ! -d "$PROJECT_ROOT/Data/Books" ]; then
    BOOKS_PATH="$HOME/Desktop/Not Backed Up/Anderson's Library/Andy/Anderson eBooks"
    if [ -d "$BOOKS_PATH" ]; then
        ln -s "$BOOKS_PATH" "$PROJECT_ROOT/Data/Books"
        echo "✅ Created: Data/Books -> Anderson eBooks"
    else
        echo "⚠️  Warning: Books path not found: $BOOKS_PATH"
    fi
else
    echo "ℹ️  Already exists: Data/Books"
fi

# Scripts/Common - Link to shared common scripts (if they exist)
if [ ! -L "$PROJECT_ROOT/Scripts/Common" ] && [ ! -d "$PROJECT_ROOT/Scripts/Common" ]; then
    if [ -d "$COMMON_SCRIPTS_PATH" ]; then
        ln -s "$COMMON_SCRIPTS_PATH" "$PROJECT_ROOT/Scripts/Common"
        echo "✅ Created: Scripts/Common -> shared scripts"
    else
        echo "ℹ️  Optional: Scripts/Common path not found (skipping)"
    fi
else
    echo "ℹ️  Already exists: Scripts/Common"
fi

# Docs/Standards - Link to shared standards (if they exist)  
if [ ! -L "$PROJECT_ROOT/Docs/Standards/Shared" ] && [ ! -d "$PROJECT_ROOT/Docs/Standards/Shared" ]; then
    if [ -d "$STANDARDS_PATH" ]; then
        ln -s "$STANDARDS_PATH" "$PROJECT_ROOT/Docs/Standards/Shared"
        echo "✅ Created: Docs/Standards/Shared -> shared standards"
    else
        echo "ℹ️  Optional: Standards path not found (skipping)"
    fi
else
    echo "ℹ️  Already exists: Docs/Standards/Shared"
fi

echo ""
echo "🔍 Current symlink status:"
echo "------------------------"
find "$PROJECT_ROOT" -type l -exec ls -la {} \; 2>/dev/null | grep -v node_modules || echo "No symlinks found"

echo ""
echo "✅ Development environment setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Verify your application can access books via Data/Books/"
echo "2. Test any shared scripts via Scripts/Common/"  
echo "3. Check that GitHub Pages deployment still works"
echo ""
echo "🚨 Remember: These symlinks are ignored by Git (.gitignore)"
echo "   They will NOT be committed or deployed to GitHub Pages"