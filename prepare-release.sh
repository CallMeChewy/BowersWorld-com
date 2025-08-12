#!/bin/bash
# File: prepare-release.sh
# Path: /home/herb/Desktop/BowersWorld-com/prepare-release.sh
# Standard: AIDEV-PascalCase-2.1
# Created: 2025-08-12
# Last Modified: 2025-08-12 02:27PM

# BowersWorld-com Release Preparation Script
#
# Converts development symlinks to production-ready placeholder structure
# This ensures clean deployments while maintaining user functionality

echo "📦 Preparing BowersWorld-com for Release"
echo "======================================="

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "🔗 Converting development symlinks to production placeholders..."

# Handle Data/Books - Critical for user library setup
if [ -L "Data/Books" ]; then
    echo "  📚 Converting Data/Books symlink to user library directory"
    rm "Data/Books"
    mkdir -p "Data/Books"
    
    cat > "Data/Books/README.md" << 'EOF'
# Your Personal Library

Welcome to OurLibrary! Place your book files in this directory to build your personal digital library.

## Quick Start
1. **Add Your Books**: Copy PDF, EPUB, or TXT files into this folder
2. **Organize**: Create subdirectories like `Fiction/`, `Technical/`, `Reference/`
3. **Restart App**: The application will automatically detect your books
4. **Enjoy**: Browse and read your personal library!

## Supported Formats
- 📄 **PDF Files**: Technical books, research papers, documents
- 📖 **EPUB Files**: E-books, novels, formatted publications  
- 📝 **TXT Files**: Plain text books, documentation

## Organization Ideas
```
Data/Books/
├── Fiction/
│   ├── SciFi/
│   └── Classics/
├── Technical/
│   ├── Programming/
│   └── Engineering/
├── Reference/
│   └── Manuals/
└── Personal/
    └── Research/
```

## Privacy & Copyright
- Your books remain **private** - never uploaded or shared
- Only add books you **own** or have **permission** to use
- This application respects copyright and user privacy

## Need Help?
Visit our documentation or contact support if you need assistance setting up your library.

---
**OurLibrary - Getting education into the hands of people who can least afford it**
EOF

    # Add a sample book structure file
    cat > "Data/Books/.library-structure" << 'EOF'
{
  "library_version": "1.0",
  "setup_date": null,
  "book_count": 0,
  "directories": [],
  "last_scan": null,
  "user_preferences": {
    "default_view": "grid",
    "sort_by": "title",
    "show_thumbnails": true
  }
}
EOF
    
    echo "    ✅ Created user library directory with setup instructions"
else
    echo "    ℹ️  Data/Books already exists as directory"
fi

# Handle Scripts/Common - Development shared scripts
if [ -L "Scripts/Common" ]; then
    echo "  🛠️  Converting Scripts/Common symlink to placeholder"
    rm "Scripts/Common"
    mkdir -p "Scripts/Common"
    echo "# Production placeholder - shared scripts not included in release" > "Scripts/Common/.gitkeep"
    echo "    ✅ Created Scripts/Common placeholder"
else
    echo "    ℹ️  Scripts/Common already exists as directory"
fi

# Handle Docs/Standards - Development documentation
if [ -L "Docs/Standards" ]; then
    echo "  📖 Converting Docs/Standards symlink to placeholder"
    rm "Docs/Standards"  
    mkdir -p "Docs/Standards"
    echo "# Production placeholder - development standards not included in release" > "Docs/Standards/.gitkeep"
    echo "    ✅ Created Docs/Standards placeholder"
else
    echo "    ℹ️  Docs/Standards already exists as directory"
fi

# Clean up any other broken symlinks
echo "🧹 Cleaning up any broken symlinks..."
broken_links=$(find . -type l ! -exec test -e {} \; -print | grep -v node_modules || true)
if [ -n "$broken_links" ]; then
    echo "$broken_links" | while read -r link; do
        echo "    🗑️  Removing broken symlink: $link"
        rm "$link"
    done
else
    echo "    ✅ No broken symlinks found"
fi

echo ""
echo "📋 Release Preparation Summary:"
echo "==============================="
echo "✅ Data/Books: Ready for user library setup"
echo "✅ Development symlinks: Converted to placeholders"  
echo "✅ Broken symlinks: Cleaned up"
echo "✅ Release: Ready for deployment/distribution"
echo ""
echo "🚀 Next Steps:"
echo "1. Test the application with empty library state"
echo "2. Commit changes for clean deployment"
echo "3. Build .exe or deploy to GitHub Pages"
echo "4. Users can now add their own books to Data/Books/"