#!/bin/bash
# File: SetupEnhancedExtractor.sh
# Path: BowersWorld-com/Scripts/Enhanced/SetupEnhancedExtractor.sh
# Standard: AIDEV-PascalCase-1.8
# Created: 2025-07-01
# Author: Herb Bowers - Project Himalaya
# Description: Setup script for Enhanced PDF Extractor with OCR capabilities

echo "🚀 ENHANCED PDF EXTRACTOR SETUP"
echo "=================================="
echo "Setting up maximum text extraction with OCR capabilities..."
echo

# Detect operating system
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    echo "🐧 Detected: Linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    echo "🍎 Detected: macOS"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
    echo "🪟 Detected: Windows"
else
    echo "❌ Unsupported operating system: $OSTYPE"
    exit 1
fi

echo

# Install system dependencies
echo "📦 Installing system dependencies..."

if [[ "$OS" == "linux" ]]; then
    echo "Installing Tesseract OCR and Poppler utils for Linux..."
    sudo apt-get update
    sudo apt-get install -y tesseract-ocr tesseract-ocr-eng
    sudo apt-get install -y poppler-utils
    sudo apt-get install -y libopencv-dev python3-opencv
    
elif [[ "$OS" == "macos" ]]; then
    echo "Installing Tesseract OCR and Poppler utils for macOS..."
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Please install Homebrew first:"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    brew install tesseract
    brew install poppler
    
elif [[ "$OS" == "windows" ]]; then
    echo "⚠️ Windows detected. Please install manually:"
    echo "1. Install Tesseract OCR from: https://github.com/UB-Mannheim/tesseract/wiki"
    echo "2. Install Poppler from: https://github.com/oschwartz10612/poppler-windows/releases/"
    echo "3. Add both to your PATH environment variable"
    echo "4. Then run this script again to install Python packages"
    
    read -p "Have you installed Tesseract and Poppler? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please install system dependencies first, then run this script again."
        exit 1
    fi
fi

echo "✅ System dependencies installed"
echo

# Install Python packages
echo "🐍 Installing Python packages..."

# Create requirements file
cat > enhanced_requirements.txt << EOF
# Enhanced PDF Extractor Requirements
# Core PDF processing
PyPDF2>=3.0.0
PyMuPDF>=1.23.0
pdfplumber>=0.9.0

# OCR and image processing
pytesseract>=0.3.10
pdf2image>=1.16.0
Pillow>=10.0.0
opencv-python>=4.8.0
numpy>=1.24.0

# Data processing
pandas>=2.0.0
pathlib2>=2.3.7

# Additional utilities
python-dateutil>=2.8.2
tqdm>=4.65.0
EOF

echo "📋 Installing Python packages from requirements..."
pip install -r enhanced_requirements.txt

echo "✅ Python packages installed"
echo

# Test installation
echo "🧪 Testing installation..."

# Test Tesseract
echo "Testing Tesseract OCR..."
if command -v tesseract &> /dev/null; then
    TESSERACT_VERSION=$(tesseract --version | head -n1)
    echo "✅ Tesseract found: $TESSERACT_VERSION"
else
    echo "❌ Tesseract not found in PATH"
    echo "Please ensure Tesseract is properly installed and added to PATH"
fi

# Test Python imports
echo "Testing Python imports..."
python3 -c "
import sys
packages = [
    'pytesseract',
    'pdf2image', 
    'pdfplumber',
    'cv2',
    'PIL',
    'numpy',
    'pandas',
    'PyPDF2',
    'fitz'
]

failed = []
for package in packages:
    try:
        if package == 'cv2':
            import cv2
        elif package == 'PIL':
            from PIL import Image
        elif package == 'fitz':
            import fitz
        else:
            exec(f'import {package}')
        print(f'✅ {package}')
    except ImportError as e:
        print(f'❌ {package}: {e}')
        failed.append(package)

if failed:
    print(f'\\n❌ Failed to import: {failed}')
    sys.exit(1)
else:
    print('\\n✅ All Python packages imported successfully!')
"

if [ $? -eq 0 ]; then
    echo "✅ All dependencies installed and working!"
else
    echo "❌ Some dependencies failed to import"
    echo "Please check the error messages above"
    exit 1
fi

echo
echo "🎉 SETUP COMPLETE!"
echo "=================="
echo "Your enhanced PDF extractor is ready to use with:"
echo "  🔍 Tesseract OCR for scanned documents"
echo "  📄 Multiple PDF parsing methods"
echo "  🖼️ Image enhancement for better OCR"
echo "  📊 Extended text capture (15,000+ chars per field)"
echo "  ⚡ Enhanced table and structure extraction"
echo
echo "To run the enhanced extractor:"
echo "  python3 EnhancedPDFExtractor.py"
echo
echo "Configuration files created:"
echo "  📋 enhanced_requirements.txt - Python dependencies"
echo
echo "Ready for maximum text extraction! 🚀"