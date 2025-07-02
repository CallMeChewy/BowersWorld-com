# File: enhanced_extractor_config.py
# Path: BowersWorld-com/Scripts/Enhanced/EnhancedExtractorConfig.py
# Standard: AIDEV-PascalCase-1.8
# Created: 2025-07-01
# Author: Herb Bowers - Project Himalaya
# Description: Configuration file for Enhanced PDF Extractor

import os
from pathlib import Path

class EnhancedExtractorConfig:
    """Configuration settings for Enhanced PDF Extractor"""
    
    # ===== PATHS CONFIGURATION =====
    # Update these paths to match your setup
    
    # PDF source directory
    PDF_DIRECTORY = "Data/Books"
    
    # Existing database (for category/subject mapping)
    DATABASE_PATH = "Data/Databases/my_library.db"
    
    # Output CSV file for extracted metadata
    OUTPUT_CSV = "Data/Spreadsheets/AndersonLibraryEnhancedMetadata.csv"
    
    # ===== EXTRACTION LIMITS =====
    # Text extraction limits (characters)
    MAX_TEXT_LENGTH = 15000  # Increased from 1000 to 15,000 characters per field
    MAX_FULL_TEXT_LENGTH = 50000  # Full text sample limit
    
    # Page processing limits
    MAX_PAGES_TO_PROCESS = 10  # Number of pages to process for content
    MAX_PAGES_FOR_SEARCH = 15  # Pages to search for copyright, TOC, etc.
    
    # ===== OCR CONFIGURATION =====
    # OCR settings for scanned documents
    OCR_DPI = 300  # Resolution for PDF to image conversion
    OCR_ENABLED = True  # Enable/disable OCR processing
    
    # Tesseract OCR configuration
    # --oem 3: Use default OCR Engine Mode
    # --psm 6: Uniform block of text
    TESSERACT_CONFIG = '--oem 3 --psm 6'
    
    # OCR threshold - trigger OCR if extracted text is below this length
    OCR_TRIGGER_THRESHOLD = 100
    
    # ===== IMAGE PROCESSING =====
    # Image enhancement settings for better OCR
    IMAGE_ENHANCEMENT = True
    NOISE_REDUCTION = True
    CONTRAST_ENHANCEMENT = True
    
    # ===== PERFORMANCE SETTINGS =====
    # Progress reporting
    PROGRESS_INTERVAL = 10  # Show progress every N files
    BATCH_COMMIT_SIZE = 50  # Commit CSV writes every N records
    
    # Memory management
    MAX_MEMORY_PER_PDF = 500 * 1024 * 1024  # 500MB per PDF processing
    
    # ===== EXTRACTION METHODS =====
    # Enable/disable different extraction methods
    USE_PYMUPDF = True      # Primary method - fastest and most reliable
    USE_PYPDF2 = True       # Fallback method
    USE_PDFPLUMBER = True   # Enhanced structure and table extraction
    USE_OCR = True          # OCR for image-based PDFs
    
    # ===== TEXT PATTERN MATCHING =====
    # Regular expressions for metadata extraction
    PATTERNS = {
        'ISBN': r'ISBN[:\-\s]*([0-9\-X]{10,17})',
        'YEAR': r'(19|20)\d{2}',
        'PUBLISHER': r'Published by[:\s]*([^.\n\r]{5,50})',
        'COPYRIGHT': r'Copyright[:\s]*©?\s*(\d{4})',
        'EDITION': r'(\d+)(st|nd|rd|th)\s+edition',
        'DOI': r'DOI[:\s]*([0-9a-zA-Z./\-]{10,50})',
        'ISSN': r'ISSN[:\s]*([0-9\-]{8,9})',
        'VOLUME': r'Volume[:\s]*(\d+)',
        'CHAPTER': r'Chapter[:\s]*(\d+)',
    }
    
    # ===== QUALITY SCORING =====
    # Weights for extraction quality calculation
    QUALITY_WEIGHTS = {
        'pdf_title': 10,
        'pdf_author': 10,
        'extracted_isbn': 15,
        'extracted_year': 10,
        'first_page_text': 20,
        'title_page_text': 15,
        'copyright_page_text': 10,
        'full_text_sample': 10,
        'text_length_bonus': 0.01,  # Bonus per character extracted
    }
    
    # ===== ERROR HANDLING =====
    # Maximum errors before skipping a file
    MAX_ERRORS_PER_FILE = 5
    
    # Continue processing after errors
    CONTINUE_ON_ERROR = True
    
    # Detailed error logging
    VERBOSE_ERROR_LOGGING = True
    
    # ===== OUTPUT CONFIGURATION =====
    # CSV output settings
    CSV_ENCODING = 'utf-8'
    CSV_DELIMITER = ','
    
    # Enhanced output fields
    OUTPUT_FIELDS = [
        # Basic file info
        'filename', 'file_size_mb', 'page_count',
        
        # Database mapping
        'database_category', 'database_subject',
        
        # PDF metadata
        'pdf_title', 'pdf_author', 'pdf_subject', 
        'pdf_creator', 'pdf_producer', 'pdf_creation_date',
        
        # Extracted metadata
        'extracted_isbn', 'extracted_year', 'extracted_publisher', 
        'extracted_edition', 'extracted_doi', 'extracted_issn',
        
        # Text content (expanded)
        'first_page_text', 'title_page_text', 'copyright_page_text',
        'table_of_contents', 'full_text_sample', 'tables_content',
        'abstract_text', 'index_text', 'bibliography_text',
        
        # Processing info
        'extraction_method', 'ocr_used', 'enhanced_extraction',
        'extraction_quality_score', 'processing_time_seconds',
        'text_language', 'errors'
    ]
    
    # ===== CONTENT DETECTION =====
    # Keywords for detecting specific page types
    COPYRIGHT_KEYWORDS = ['copyright', '©', 'all rights reserved', 'published by']
    TOC_KEYWORDS = ['contents', 'table of contents', 'toc', 'index']
    ABSTRACT_KEYWORDS = ['abstract', 'summary', 'executive summary']
    BIBLIOGRAPHY_KEYWORDS = ['bibliography', 'references', 'works cited', 'citations']
    
    # ===== VALIDATION =====
    @classmethod
    def validate_config(cls):
        """Validate configuration settings"""
        errors = []
        
        # Check paths
        if not Path(cls.PDF_DIRECTORY).exists():
            errors.append(f"PDF directory not found: {cls.PDF_DIRECTORY}")
            
        # Check output directory is writable
        output_dir = Path(cls.OUTPUT_CSV).parent
        if not output_dir.exists():
            try:
                output_dir.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                errors.append(f"Cannot create output directory: {e}")
        
        # Check limits are reasonable
        if cls.MAX_TEXT_LENGTH < 1000:
            errors.append("MAX_TEXT_LENGTH should be at least 1000 characters")
            
        if cls.MAX_PAGES_TO_PROCESS < 1:
            errors.append("MAX_PAGES_TO_PROCESS should be at least 1")
        
        # Check OCR settings
        if cls.OCR_ENABLED:
            try:
                import pytesseract
                pytesseract.get_tesseract_version()
            except Exception as e:
                errors.append(f"OCR enabled but Tesseract not available: {e}")
        
        return errors
    
    @classmethod
    def print_config(cls):
        """Print current configuration"""
        print("🔧 ENHANCED PDF EXTRACTOR CONFIGURATION")
        print("=" * 50)
        print(f"📂 PDF Directory: {cls.PDF_DIRECTORY}")
        print(f"📊 Output CSV: {cls.OUTPUT_CSV}")
        print(f"📏 Max text per field: {cls.MAX_TEXT_LENGTH:,} characters")
        print(f"📄 Max pages to process: {cls.MAX_PAGES_TO_PROCESS}")
        print(f"🔍 OCR enabled: {cls.OCR_ENABLED}")
        print(f"📈 Progress interval: {cls.PROGRESS_INTERVAL}")
        
        # Validate configuration
        errors = cls.validate_config()
        if errors:
            print("\n❌ Configuration errors:")
            for error in errors:
                print(f"   • {error}")
            return False
        else:
            print("\n✅ Configuration validated successfully")
            return True

# Example usage and testing
if __name__ == "__main__":
    config = EnhancedExtractorConfig()
    config.print_config()
    
    # Example of how to customize for your environment
    print("\n" + "=" * 50)
    print("📝 CUSTOMIZATION EXAMPLE")
    print("=" * 50)
    print("To customize for your environment, edit these settings:")
    print()
    print("# For different PDF directory:")
    print("PDF_DIRECTORY = '/your/pdf/directory/path'")
    print()
    print("# For faster processing (fewer pages):")
    print("MAX_PAGES_TO_PROCESS = 5")
    print()
    print("# For higher quality OCR:")
    print("OCR_DPI = 600")
    print()
    print("# For larger text extraction:")
    print("MAX_TEXT_LENGTH = 25000")
    print()
    print("Save your changes and run the enhanced extractor!")
