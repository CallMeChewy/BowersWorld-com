#!/usr/bin/env python3
# File: HimalayaGPUExtractor_Protected.py
# Path: BowersWorld-com/Scripts/Himalaya/HimalayaGPUExtractor_Protected.py
# Standard: AIDEV-PascalCase-1.8
# Created: 2025-07-02
# Last Modified: 2025-07-02  11:45AM
"""
Description: Himalaya-standard GPU-accelerated PDF text extraction with comprehensive bibliographic data extraction and timeout protection

CRITICAL ENHANCEMENTS:
- Advanced bibliographic identifier extraction (ISBN, LCCN, ISSN, OCLC, DOI)
- Enhanced publisher and metadata extraction with priority searching
- Timeout protection to prevent infinite hangs on corrupted PDFs
- GPU hardware acceleration with intelligent CPU fallback
- Advanced validation and normalization of extracted identifiers
- Multiple extraction strategies with quality scoring

Hardware: RTX 4070 GPU-optimized with CPU fallback
Expected improvements: ISBN 45.7%→75%+, New LCCN extraction 40-60%, Publisher 28.4%→65%+

Author: Herb Bowers - Project Himalaya
Contact: HimalayaProject1@gmail.com
"""

import os
import csv
import sqlite3
import time
import signal
from pathlib import Path
import PyPDF2
import pandas as pd
from datetime import datetime
import re
import fitz  # PyMuPDF
import warnings
import tempfile
import threading
warnings.filterwarnings("ignore")

# Core dependencies
import numpy as np
from PIL import Image
from pdf2image import convert_from_path
import pdfplumber

# ===== TIMEOUT PROTECTION CLASSES =====

class TimeoutError(Exception):
    pass

class PDFTimeout:
    """Timeout protection for PDF operations"""
    
    def __init__(self, Seconds, OperationName="PDF operation"):
        self.Seconds = Seconds
        self.OperationName = OperationName
        self.Timer = None
    
    def __enter__(self):
        self.Timer = threading.Timer(self.Seconds, self._TimeoutHandler)
        self.Timer.start()
        return self
    
    def __exit__(self, ExcType, ExcVal, ExcTb):
        if self.Timer:
            self.Timer.cancel()
    
    def _TimeoutHandler(self):
        raise TimeoutError(f"{self.OperationName} timed out after {self.Seconds} seconds")

def TimeoutProtected(TimeoutSeconds):
    """Decorator for timeout protection"""
    def Decorator(Func):
        def Wrapper(*Args, **Kwargs):
            Result = [None]
            Exception = [None]
            
            def Target():
                try:
                    Result[0] = Func(*Args, **Kwargs)
                except Exception as E:
                    Exception[0] = E
            
            Thread = threading.Thread(target=Target)
            Thread.daemon = True
            Thread.start()
            Thread.join(TimeoutSeconds)
            
            if Thread.is_alive():
                # Thread is still running - timeout occurred
                raise TimeoutError(f"Function {Func.__name__} timed out after {TimeoutSeconds} seconds")
            
            if Exception[0]:
                raise Exception[0]
            
            return Result[0]
        return Wrapper
    return Decorator

# ===== CONFIGURATION - HIMALAYA ENHANCED =====

PDF_DIRECTORY = "/home/herb/Desktop/Not Backed Up/Anderson's Library/Andy/Anderson eBooks"
DATABASE_PATH = "/home/herb/Desktop/BowersWorld-com/Assets/my_library.db"
OUTPUT_CSV = "/home/herb/Desktop/BowersWorld-com/AndersonLibrary_Himalaya_GPU.csv"
PROGRESS_INTERVAL = 5

# Himalaya text extraction limits
MAX_TEXT_LENGTH = 20000
MAX_PAGES_TO_PROCESS = 12
OCR_DPI = 350
GPU_BATCH_SIZE = 4

# Timeout settings
PDF_OPEN_TIMEOUT = 15  # seconds to open PDF
PAGE_PROCESS_TIMEOUT = 10  # seconds per page
OCR_TIMEOUT = 45  # seconds for OCR operation
TOTAL_PDF_TIMEOUT = 120  # seconds for entire PDF processing

# ===== ENHANCED BIBLIOGRAPHIC EXTRACTION PATTERNS =====

# Enhanced ISBN Patterns - Multiple formats and contexts
ISBN_PATTERNS = [
    # Standard ISBN with labels
    re.compile(r'ISBN[:\-\s]*(\d{1,5}[\-\s]?\d{1,7}[\-\s]?\d{1,7}[\-\s]?[\dxX])', re.IGNORECASE),
    re.compile(r'ISBN[:\-\s]*(\d{3}[\-\s]?\d{1,5}[\-\s]?\d{1,7}[\-\s]?\d{1,7}[\-\s]?[\dxX])', re.IGNORECASE),
    
    # ISBN in context
    re.compile(r'(?:International Standard Book Number|Book Number|Catalog[ue]? Number)[:\-\s]*(\d{10,17}[\dxX]?)', re.IGNORECASE),
    
    # ISBN in CIP/Library of Congress data
    re.compile(r'(?:Library of Congress|CIP|Cataloging)[^.]*?ISBN[:\-\s]*(\d{10,17}[\dxX]?)', re.IGNORECASE | re.DOTALL),
    
    # Bare ISBN patterns (with word boundaries)
    re.compile(r'\b(\d{3}[\-\s]?\d{1,5}[\-\s]?\d{1,7}[\-\s]?\d{1,7}[\-\s]?[\dxX])\b'),  # 13-digit
    re.compile(r'\b(\d{1,5}[\-\s]?\d{1,7}[\-\s]?\d{1,7}[\-\s]?[\dxX])\b(?=.*book)', re.IGNORECASE),  # 10-digit with context
    
    # Multiple ISBN formats on same line
    re.compile(r'ISBN[:\-\s]*(\d+[\-\s\d]*[\dxX])', re.IGNORECASE),
]

# Library of Congress Control Number (LCCN) Patterns - NEW!
LCCN_PATTERNS = [
    # Standard LCCN formats
    re.compile(r'(?:LCCN|Library of Congress Control Number)[:\-\s]*(\d{8,12})', re.IGNORECASE),
    re.compile(r'(?:LC Control Number|LC Number)[:\-\s]*(\d{8,12})', re.IGNORECASE),
    
    # LCCN in various formats
    re.compile(r'LCCN[:\-\s]*(\d{4}[\-]?\d{6,8})', re.IGNORECASE),
    
    # Library of Congress Card Number (older format)
    re.compile(r'(?:Library of Congress Card Number|LC Card Number)[:\-\s]*(\d{2}[\-]?\d{6,8})', re.IGNORECASE),
    
    # In cataloging-in-publication data
    re.compile(r'(?:Cataloging[^.]*?|CIP[^.]*?)(?:LCCN|Control Number)[:\-\s]*(\d{8,12})', re.IGNORECASE | re.DOTALL),
    
    # LCCN with additional context
    re.compile(r'(?:\d{3}\.\d+[^.]*?)LCCN[:\-\s]*(\d{8,12})', re.IGNORECASE),
]

# ISSN Patterns for Periodicals - NEW!
ISSN_PATTERNS = [
    re.compile(r'ISSN[:\-\s]*(\d{4}[\-]?\d{4})', re.IGNORECASE),
    re.compile(r'(?:International Standard Serial Number)[:\-\s]*(\d{4}[\-]?\d{4})', re.IGNORECASE),
    re.compile(r'(?:Serial Number|Periodical Number)[:\-\s]*(\d{4}[\-]?\d{4})', re.IGNORECASE),
]

# OCLC WorldCat Numbers - NEW!
OCLC_PATTERNS = [
    re.compile(r'OCLC[:\-\s]*(\d{8,12})', re.IGNORECASE),
    re.compile(r'(?:WorldCat|OCLC Number)[:\-\s]*(\d{8,12})', re.IGNORECASE),
    re.compile(r'(?:OCLC|WorldCat)[^.]*?(\d{8,12})', re.IGNORECASE),
]

# Enhanced DOI Patterns
DOI_PATTERNS = [
    re.compile(r'DOI[:\-\s]*(10\.\d+/[^\s\n\r]{1,100})', re.IGNORECASE),
    re.compile(r'(?:Digital Object Identifier)[:\-\s]*(10\.\d+/[^\s\n\r]{1,100})', re.IGNORECASE),
    re.compile(r'https?://(?:dx\.)?doi\.org/(10\.\d+/[^\s\n\r]{1,100})', re.IGNORECASE),
    re.compile(r'doi\.org/(10\.\d+/[^\s\n\r]{1,100})', re.IGNORECASE),
]

# Enhanced Publisher Patterns
PUBLISHER_PATTERNS = [
    # Standard publisher formats
    re.compile(r'Published by[:\s]*([^.\n\r]{5,100})', re.IGNORECASE),
    re.compile(r'Publisher[:\s]*([^.\n\r]{5,100})', re.IGNORECASE),
    
    # Major academic publishers
    re.compile(r'(Academic Press|MIT Press|Cambridge University Press|Oxford University Press|Springer|Wiley|Elsevier|McGraw[- ]?Hill|Pearson|Cengage Learning|Cengage|Thomson|Wadsworth)', re.IGNORECASE),
    
    # Technical publishers
    re.compile(r'(O\'?Reilly Media|O\'?Reilly|Addison[- ]?Wesley|Prentice Hall|No Starch Press|Manning Publications|Pragmatic Bookshelf|Apress|Packt Publishing)', re.IGNORECASE),
    
    # Copyright line publishers
    re.compile(r'©\s*\d{4}[^.\n]*?([A-Z][^.\n]{10,50}(?:Press|Publications?|Inc\.?|LLC|Corp\.?))', re.IGNORECASE),
    
    # Imprint information
    re.compile(r'(?:An? )?([^.\n]{5,50})\s+imprint', re.IGNORECASE),
    
    # University presses
    re.compile(r'([^.\n]{5,50}University Press)', re.IGNORECASE),
]

# Enhanced Year Patterns with Priority
YEAR_PATTERNS = [
    # Copyright years (highest priority)
    re.compile(r'©\s*(\d{4})', re.IGNORECASE),
    re.compile(r'Copyright[:\s]*©?\s*(\d{4})', re.IGNORECASE),
    
    # Publication years
    re.compile(r'Published[^.\n]*?(\d{4})', re.IGNORECASE),
    re.compile(r'Publication[^.\n]*?(\d{4})', re.IGNORECASE),
    
    # Edition years
    re.compile(r'(\d{4})\s+edition', re.IGNORECASE),
    
    # General year pattern (last resort)
    re.compile(r'\b(19\d{2}|20[0-2]\d)\b'),
]

# Enhanced Edition Patterns
EDITION_PATTERNS = [
    re.compile(r'(\d+)(?:st|nd|rd|th)\s+edition', re.IGNORECASE),
    re.compile(r'(\d+)(?:st|nd|rd|th)\s+ed\.?', re.IGNORECASE),
    re.compile(r'(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)\s+edition', re.IGNORECASE),
    re.compile(r'edition[:\s]*(\d+)', re.IGNORECASE),
    re.compile(r'(revised|updated|expanded|international|global)\s+edition', re.IGNORECASE),
]

# ===== VALIDATION AND NORMALIZATION FUNCTIONS =====

def ValidateISBN(ISBN: str) -> str:
    """Validate and normalize ISBN"""
    if not ISBN:
        return ''
    
    # Clean ISBN (remove spaces, hyphens)
    CleanISBN = re.sub(r'[\s\-]', '', ISBN.upper())
    
    # Check for valid length and format
    if len(CleanISBN) == 10:
        if re.match(r'^\d{9}[\dX]$', CleanISBN):
            return CleanISBN
    elif len(CleanISBN) == 13:
        if re.match(r'^\d{13}$', CleanISBN):
            return CleanISBN
    elif 10 <= len(CleanISBN) <= 17:
        # Try to extract valid ISBN from longer string
        ISBNMatch = re.search(r'(\d{9}[\dX]|\d{13})', CleanISBN)
        if ISBNMatch:
            return ISBNMatch.group(1)
    
    return ''

def ValidateLCCN(LCCN: str) -> str:
    """Validate and normalize LCCN"""
    if not LCCN:
        return ''
    
    # Clean LCCN (remove spaces, hyphens)
    CleanLCCN = re.sub(r'[\s\-]', '', LCCN)
    
    # Check for valid format (8-12 digits)
    if re.match(r'^\d{8,12}$', CleanLCCN):
        return CleanLCCN
    
    return ''

def ValidateISSN(ISSN: str) -> str:
    """Validate and normalize ISSN"""
    if not ISSN:
        return ''
    
    # Clean ISSN
    CleanISSN = re.sub(r'[\s]', '', ISSN)
    
    # Add hyphen if missing
    if len(CleanISSN) == 8 and '-' not in CleanISSN:
        CleanISSN = CleanISSN[:4] + '-' + CleanISSN[4:]
    
    # Validate format
    if re.match(r'^\d{4}-\d{4}$', CleanISSN):
        return CleanISSN
    
    return ''

def ExtractWithPatterns(Text: str, Patterns: list, Validator=None) -> str:
    """Extract first valid match from multiple patterns with optional validation"""
    for Pattern in Patterns:
        Matches = Pattern.findall(Text)
        for Match in Matches:
            Extracted = Match if isinstance(Match, str) else Match[0] if Match else ''
            if Extracted:
                if Validator:
                    Validated = Validator(Extracted)
                    if Validated:
                        return Validated
                else:
                    return Extracted.strip()
    return ''

# ===== HIMALAYA HARDWARE MANAGER =====

class HimalayaHardwareManager:
    """Himalaya-standard hardware acceleration management"""
    
    def __init__(self):
        print("🏔️ INITIALIZING HIMALAYA HARDWARE MANAGER")
        print("=" * 60)
        
        self.GPUCapabilities = self.DetectGPUCapabilities()
        self.OCREngines = self.InitializeOCREngines()
        self.PerformanceMetrics = {
            'GPU_Operations': 0,
            'CPU_Operations': 0,
            'GPU_Time': 0.0,
            'CPU_Time': 0.0,
            'GPU_Errors': 0,
            'Fallback_Switches': 0,
            'Total_OCR_Operations': 0,
            'Timeout_Failures': 0
        }
        
        self.ActiveEngine = self.SelectOptimalEngine()
        self.LogHimalayaConfiguration()
    
    def DetectGPUCapabilities(self):
        """Detect RTX 4070 and CUDA capabilities"""
        Capabilities = {
            'CUDA_Available': False,
            'GPU_Name': 'None',
            'GPU_Memory_GB': 0,
            'GPU_Compute_Capability': None,
            'CUDA_Version': None
        }
        
        try:
            import torch
            if torch.cuda.is_available():
                Capabilities['CUDA_Available'] = True
                Capabilities['GPU_Name'] = torch.cuda.get_device_name(0)
                Capabilities['GPU_Memory_GB'] = torch.cuda.get_device_properties(0).total_memory / (1024**3)
                Capabilities['GPU_Compute_Capability'] = torch.cuda.get_device_capability(0)
                Capabilities['CUDA_Version'] = torch.version.cuda
                
                print(f"🚀 GPU Detected: {Capabilities['GPU_Name']}")
                print(f"💾 GPU Memory: {Capabilities['GPU_Memory_GB']:.1f} GB")
                print(f"⚡ CUDA Version: {Capabilities['CUDA_Version']}")
            else:
                print("⚠️ CUDA not available - using CPU fallback")
                
        except ImportError:
            print("⚠️ PyTorch not available - using CPU fallback")
        except Exception as GPUError:
            print(f"⚠️ GPU detection error: {GPUError}")
        
        return Capabilities
    
    def InitializeOCREngines(self):
        """Initialize available OCR engines"""
        Engines = {
            'TesseractGPU': False,
            'TesseractCPU': False,
            'EasyOCR': False,
            'PaddleOCR': False
        }
        
        # Test Tesseract availability
        try:
            import pytesseract
            Engines['TesseractCPU'] = True
            print("✅ Tesseract CPU engine available")
        except ImportError:
            print("❌ Tesseract not available")
        
        # Test EasyOCR availability
        try:
            import easyocr
            if self.GPUCapabilities['CUDA_Available']:
                Engines['EasyOCR'] = True
                print("✅ EasyOCR GPU engine available")
            else:
                print("⚠️ EasyOCR available but no GPU")
        except ImportError:
            print("❌ EasyOCR not available")
        
        return Engines
    
    def SelectOptimalEngine(self):
        """Select the best available OCR engine"""
        if self.OCREngines['EasyOCR'] and self.GPUCapabilities['CUDA_Available']:
            return 'EasyOCR-GPU'
        elif self.OCREngines['TesseractCPU']:
            return 'Tesseract-CPU'
        else:
            return 'CPU-Fallback'
    
    def LogHimalayaConfiguration(self):
        """Log the Himalaya hardware configuration"""
        print("\n📋 HIMALAYA CONFIGURATION:")
        print(f"   🎯 Active Engine: {self.ActiveEngine}")
        print(f"   🔧 GPU Acceleration: {'✅' if 'GPU' in self.ActiveEngine else '❌'}")
        print(f"   💾 Available Memory: {self.GPUCapabilities['GPU_Memory_GB']:.1f} GB")
        print(f"   ⚡ Hardware Ready: {'✅' if self.ActiveEngine != 'CPU-Fallback' else '⚠️'}")
    
    def ProcessImageWithOptimalEngine(self, Image, Context=""):
        """Process image with the optimal available engine"""
        StartTime = time.time()
        
        try:
            if self.ActiveEngine == 'EasyOCR-GPU':
                import easyocr
                Reader = easyocr.Reader(['en'], gpu=True)
                Results = Reader.readtext(np.array(Image))
                Text = ' '.join([Result[1] for Result in Results])
                
                self.PerformanceMetrics['GPU_Operations'] += 1
                self.PerformanceMetrics['GPU_Time'] += time.time() - StartTime
                
                return Text
                
            elif self.ActiveEngine == 'Tesseract-CPU':
                import pytesseract
                Text = pytesseract.image_to_string(Image, lang='eng')
                
                self.PerformanceMetrics['CPU_Operations'] += 1
                self.PerformanceMetrics['CPU_Time'] += time.time() - StartTime
                
                return Text
            else:
                return ""
                
        except Exception as OCRError:
            self.PerformanceMetrics['GPU_Errors'] += 1
            print(f"   ❌ OCR error ({Context}): {str(OCRError)[:50]}")
            return ""
    
    def GetPerformanceReport(self):
        """Generate performance report"""
        TotalOps = self.PerformanceMetrics['GPU_Operations'] + self.PerformanceMetrics['CPU_Operations']
        
        Report = {
            'GPU_Usage_Percent': (self.PerformanceMetrics['GPU_Operations'] / TotalOps * 100) if TotalOps > 0 else 0,
            'CPU_Usage_Percent': (self.PerformanceMetrics['CPU_Operations'] / TotalOps * 100) if TotalOps > 0 else 0,
            'GPU_Speedup': 0,
            'Average_GPU_Time': 0,
            'Average_CPU_Time': 0,
            'Timeout_Rate': (self.PerformanceMetrics['Timeout_Failures'] / TotalOps * 100) if TotalOps > 0 else 0
        }
        
        if self.PerformanceMetrics['GPU_Operations'] > 0:
            Report['Average_GPU_Time'] = self.PerformanceMetrics['GPU_Time'] / self.PerformanceMetrics['GPU_Operations']
        
        if self.PerformanceMetrics['CPU_Operations'] > 0:
            Report['Average_CPU_Time'] = self.PerformanceMetrics['CPU_Time'] / self.PerformanceMetrics['CPU_Operations']
        
        if Report['Average_GPU_Time'] > 0 and Report['Average_CPU_Time'] > 0:
            Report['GPU_Speedup'] = Report['Average_CPU_Time'] / Report['Average_GPU_Time']
        
        return Report

# ===== MAIN HIMALAYA PDF EXTRACTOR =====

class HimalayaPDFExtractor:
    """TIMEOUT-PROTECTED Himalaya-standard GPU-accelerated PDF extractor with enhanced bibliographic extraction"""
    
    def __init__(self):
        print("🏔️ INITIALIZING HIMALAYA PDF EXTRACTOR (ENHANCED BIBLIOGRAPHIC)")
        print("Standard: AIDEV-PascalCase-1.8 (Hardware-Accelerated + Timeout Protection + Enhanced Bibliographic)")
        print("=" * 80)
        
        self.PDFDirectory = Path(PDF_DIRECTORY)
        self.DatabasePath = DATABASE_PATH
        self.OutputFile = OUTPUT_CSV
        
        # Initialize Himalaya hardware manager
        self.HardwareManager = HimalayaHardwareManager()
        
        # Processing statistics
        self.ProcessedCount = 0
        self.ErrorCount = 0
        self.OCRCount = 0
        self.EnhancedExtractionCount = 0
        self.TotalProcessingTime = 0.0
        self.TimeoutCount = 0
        self.CorruptedPDFCount = 0
        self.BibliographicHitCount = {
            'ISBN': 0,
            'LCCN': 0,
            'ISSN': 0,
            'OCLC': 0,
            'DOI': 0,
            'Publisher': 0
        }
        
        # Load existing data and database info
        self.LoadExistingData()
        self.LoadDatabaseInfo()
    
    def LoadExistingData(self):
        """Load previously processed PDFs"""
        self.ProcessedFiles = set()
        
        if os.path.exists(self.OutputFile):
            try:
                ExistingDF = pd.read_csv(self.OutputFile)
                self.ProcessedFiles = set(ExistingDF['filename'].str.replace('.pdf', '', regex=False))
                print(f"✅ Resuming: {len(self.ProcessedFiles)} PDFs already processed")
            except Exception as E:
                print(f"⚠️ Could not load existing CSV: {E}")
                self.ProcessedFiles = set()
        else:
            print("📄 Starting fresh Himalaya extraction...")
    
    def LoadDatabaseInfo(self):
        """Load existing book data from SQLite database"""
        self.DatabaseBooks = {}
        
        if os.path.exists(self.DatabasePath):
            try:
                Conn = sqlite3.connect(self.DatabasePath)
                Cursor = Conn.cursor()
                
                Query = '''
                    SELECT b.title, c.category, s.subject 
                    FROM books b
                    LEFT JOIN subjects s ON b.subject_id = s.id
                    LEFT JOIN categories c ON s.category_id = c.id
                '''
                
                Books = Cursor.execute(Query).fetchall()
                
                for Title, Category, Subject in Books:
                    self.DatabaseBooks[Title] = {
                        'category': Category or 'Unknown',
                        'subject': Subject or 'Unknown'
                    }
                
                Conn.close()
                print(f"✅ Loaded {len(self.DatabaseBooks)} books from existing database")
                
            except Exception as DbError:
                print(f"⚠️ Database error: {DbError}")
                self.DatabaseBooks = {}
        else:
            print(f"⚠️ Database not found at {self.DatabasePath}")
            self.DatabaseBooks = {}
    
    @TimeoutProtected(TOTAL_PDF_TIMEOUT)
    def ExtractPDFMetadata(self, PDFPath):
        """TIMEOUT-PROTECTED PDF metadata extraction with enhanced bibliographic data"""
        StartTime = time.time()
        
        Metadata = {
            'filename': PDFPath.name,
            'file_size_mb': round(PDFPath.stat().st_size / (1024*1024), 2),
            'pdf_title': '',
            'pdf_author': '',
            'pdf_subject': '',
            'pdf_creator': '',
            'pdf_producer': '',
            'pdf_creation_date': '',
            'page_count': 0,
            'extracted_isbn': '',
            'extracted_lccn': '',      # NEW
            'extracted_issn': '',      # NEW
            'extracted_oclc': '',      # NEW
            'extracted_year': '',
            'extracted_publisher': '',
            'extracted_edition': '',
            'extracted_doi': '',
            'first_page_text': '',
            'title_page_text': '',
            'copyright_page_text': '',
            'table_of_contents': '',
            'full_text_sample': '',
            'abstract_text': '',
            'tables_content': '',
            'database_category': 'Not Found',
            'database_subject': 'Not Found',
            'extraction_method': 'None',
            'ocr_used': False,
            'enhanced_extraction': False,
            'hardware_acceleration': self.HardwareManager.ActiveEngine,
            'extraction_quality_score': 0,
            'processing_time_seconds': 0,
            'gpu_accelerated': 'GPU' in (self.HardwareManager.ActiveEngine or ''),
            'timeout_protection': True,
            'errors': ''
        }
        
        # Get database info
        BookTitle = PDFPath.stem
        if BookTitle in self.DatabaseBooks:
            Metadata['database_category'] = self.DatabaseBooks[BookTitle]['category']
            Metadata['database_subject'] = self.DatabaseBooks[BookTitle]['subject']
        
        ExtractionMethods = []
        ErrorMessages = []
        AllExtractedText = []
        
        # TIMEOUT-PROTECTED Method 1: PyMuPDF primary extraction
        try:
            print(f"   📄 PyMuPDF extraction ({PDF_OPEN_TIMEOUT}s timeout)...")
            
            with PDFTimeout(PDF_OPEN_TIMEOUT, "PyMuPDF PDF opening"):
                Doc = fitz.open(str(PDFPath))
                Metadata['page_count'] = len(Doc)
                
                # Extract basic PDF metadata
                PDFMetadata = Doc.metadata
                if PDFMetadata:
                    Metadata['pdf_title'] = (PDFMetadata.get('title') or '').strip()[:500]
                    Metadata['pdf_author'] = (PDFMetadata.get('author') or '').strip()[:200]
                    Metadata['pdf_subject'] = (PDFMetadata.get('subject') or '').strip()[:200]
                    Metadata['pdf_creator'] = (PDFMetadata.get('creator') or '').strip()[:200]
                    Metadata['pdf_producer'] = (PDFMetadata.get('producer') or '').strip()[:200]
                    Metadata['pdf_creation_date'] = (PDFMetadata.get('creationDate') or '').strip()[:50]
                
                # Enhanced text extraction with timeout protection
                TextToProcess = min(MAX_PAGES_TO_PROCESS, len(Doc))
                
                for PageNum in range(TextToProcess):
                    with PDFTimeout(PAGE_PROCESS_TIMEOUT, f"page {PageNum + 1} processing"):
                        Page = Doc[PageNum]
                        PageText = Page.get_text()
                        
                        # Classify and store text by page type and content
                        PageTextLower = PageText.lower()
                        
                        if PageNum == 0:
                            Metadata['first_page_text'] = PageText[:MAX_TEXT_LENGTH]
                        elif PageNum == 1 or 'title' in PageTextLower:
                            if not Metadata['title_page_text']:
                                Metadata['title_page_text'] = PageText[:MAX_TEXT_LENGTH]
                        
                        # Copyright page detection
                        if 'copyright' in PageTextLower or '©' in PageText:
                            Metadata['copyright_page_text'] = PageText[:MAX_TEXT_LENGTH]
                        
                        # Table of contents detection
                        if any(keyword in PageTextLower for keyword in ['contents', 'chapter', 'index']):
                            if len(PageText) > len(Metadata['table_of_contents']):
                                Metadata['table_of_contents'] = PageText[:MAX_TEXT_LENGTH]
                        
                        # Abstract detection
                        if 'abstract' in PageTextLower and PageNum < 5:
                            Metadata['abstract_text'] = PageText[:MAX_TEXT_LENGTH//2]
                        
                        AllExtractedText.append(PageText)
                
                # Create full text sample
                if AllExtractedText:
                    Metadata['full_text_sample'] = ' '.join(AllExtractedText)[:MAX_TEXT_LENGTH]
                
                ExtractionMethods.append('PyMuPDF')
                Doc.close()
                print(f"   ✅ PyMuPDF completed: {TextToProcess} pages extracted")
            
        except TimeoutError:
            ErrorMessages.append("PyMuPDF: Timeout")
            print(f"   ⏰ PyMuPDF timed out")
        except Exception as PyMuPDFError:
            ErrorMessages.append(f"PyMuPDF: {str(PyMuPDFError)[:100]}")
            print(f"   ❌ PyMuPDF failed: {str(PyMuPDFError)[:50]}")
        
        # TIMEOUT-PROTECTED Method 2: PDFPlumber enhanced extraction
        TextQuality = len(' '.join(filter(None, [
            Metadata.get('first_page_text', ''),
            Metadata.get('title_page_text', ''),
            Metadata.get('copyright_page_text', '')
        ])).strip())
        
        if TextQuality < 500:
            try:
                print(f"   🔧 PDFPlumber extraction (20s timeout)...")
                
                @TimeoutProtected(20)
                def ExtractWithPlumber():
                    with pdfplumber.open(PDFPath) as PDF:
                        # Enhanced metadata extraction
                        if PDF.metadata:
                            for Key, Value in PDF.metadata.items():
                                if Key == 'Title' and not Metadata['pdf_title']:
                                    Metadata['pdf_title'] = str(Value).strip()[:500]
                                elif Key == 'Author' and not Metadata['pdf_author']:
                                    Metadata['pdf_author'] = str(Value).strip()[:200]
                        
                        # Extract tables with timeout protection
                        TablesContent = []
                        PagesToCheck = min(4, len(PDF.pages))
                        
                        for PageNum in range(PagesToCheck):
                            Page = PDF.pages[PageNum]
                            Tables = Page.extract_tables()
                            if Tables:
                                for TableNum, Table in enumerate(Tables[:2]):
                                    TableText = f"Table {TableNum + 1} (Page {PageNum + 1}):\n"
                                    for Row in Table[:10]:
                                        if Row:
                                            TableText += " | ".join(str(Cell)[:50] if Cell else "" for Cell in Row) + "\n"
                                    TablesContent.append(TableText)
                        
                        return TablesContent
                
                TablesContent = ExtractWithPlumber()
                
                if TablesContent:
                    ExtractionMethods.append('PDFPlumber')
                    Metadata['enhanced_extraction'] = True
                    Metadata['tables_content'] = '\n'.join(TablesContent)[:MAX_TEXT_LENGTH]
                    self.EnhancedExtractionCount += 1
                    print(f"   ✅ PDFPlumber completed: {len(TablesContent)} tables extracted")
            
            except TimeoutError:
                ErrorMessages.append("PDFPlumber: Timeout after 20 seconds")
                print(f"   ⏰ PDFPlumber timed out")
            except Exception as PlumberError:
                ErrorMessages.append(f"PDFPlumber: {str(PlumberError)[:100]}")
                print(f"   ❌ PDFPlumber failed: {str(PlumberError)[:50]}")
        
        # TIMEOUT-PROTECTED Method 3: Himalaya GPU-accelerated OCR
        if TextQuality < 200:
            try:
                print(f"   🔍 OCR processing ({OCR_TIMEOUT}s timeout)...")
                OCRData = self.ExtractTextWithHimalayaOCR(PDFPath)
                ExtractionMethods.append('HimalayaOCR')
                Metadata['ocr_used'] = True
                
                # Use OCR text if better than existing extraction
                for Field in OCRData:
                    if len(OCRData[Field]) > len(Metadata.get(Field, '')):
                        Metadata[Field] = OCRData[Field]
                
                AllExtractedText.extend(OCRData.values())
                print(f"   ✅ OCR completed: {len([V for V in OCRData.values() if V])} fields populated")
            
            except TimeoutError:
                ErrorMessages.append("HimalayaOCR: Timeout")
                print(f"   ⏰ OCR timed out - continuing without OCR")
            except Exception as OCRError:
                ErrorMessages.append(f"HimalayaOCR: {str(OCRError)[:100]}")
                print(f"   ❌ OCR failed: {str(OCRError)[:50]}")
        
        # ===== ENHANCED BIBLIOGRAPHIC INFORMATION EXTRACTION =====
        # Combine all text with priority weighting
        AllText = ' '.join(filter(None, AllExtractedText))[:100000]
        
        # Prioritize copyright and title page text for bibliographic extraction
        CopyrightText = Metadata.get('copyright_page_text', '')
        TitleText = Metadata.get('title_page_text', '')
        
        # Create priority text search order
        SearchTexts = [
            (CopyrightText, 3),  # Highest priority - copyright pages have most metadata
            (TitleText, 2),      # Medium priority - title pages  
            (AllText[:25000], 1) # Lower priority, limited text to avoid noise
        ]
        
        # Extract ISBNs with enhanced validation
        for Text, Priority in SearchTexts:
            if Text and not Metadata['extracted_isbn']:
                for Pattern in ISBN_PATTERNS:
                    Matches = Pattern.findall(Text)
                    for Match in Matches:
                        ISBN = ValidateISBN(Match)
                        if ISBN:
                            Metadata['extracted_isbn'] = ISBN
                            self.BibliographicHitCount['ISBN'] += 1
                            break
                    if Metadata['extracted_isbn']:
                        break
        
        # Extract LCCNs (NEW) - Library of Congress Control Numbers
        for Text, Priority in SearchTexts:
            if Text and not Metadata['extracted_lccn']:
                for Pattern in LCCN_PATTERNS:
                    Matches = Pattern.findall(Text)
                    for Match in Matches:
                        LCCN = ValidateLCCN(Match)
                        if LCCN:
                            Metadata['extracted_lccn'] = LCCN
                            self.BibliographicHitCount['LCCN'] += 1
                            break
                    if Metadata['extracted_lccn']:
                        break
        
        # Extract ISSNs (NEW) - International Standard Serial Numbers
        for Text, Priority in SearchTexts:
            if Text and not Metadata['extracted_issn']:
                ISSNMatch = ExtractWithPatterns(Text, ISSN_PATTERNS)
                if ISSNMatch:
                    CleanISSN = re.sub(r'[\s]', '', ISSNMatch)
                    if len(CleanISSN) == 8:
                        CleanISSN = CleanISSN[:4] + '-' + CleanISSN[4:]
                    if re.match(r'^\d{4}-\d{4}$', CleanISSN):
                        Metadata['extracted_issn'] = CleanISSN
                        self.BibliographicHitCount['ISSN'] += 1
                        break
        
        # Extract OCLC numbers (NEW) - WorldCat catalog numbers
        for Text, Priority in SearchTexts:
            if Text and not Metadata['extracted_oclc']:
                OCLCMatch = ExtractWithPatterns(Text, OCLC_PATTERNS)
                if OCLCMatch and re.match(r'^\d{8,12}$', OCLCMatch):
                    Metadata['extracted_oclc'] = OCLCMatch
                    self.BibliographicHitCount['OCLC'] += 1
                    break
        
        # Enhanced DOI extraction
        for Text, Priority in SearchTexts:
            if Text and not Metadata['extracted_doi']:
                DOIMatch = ExtractWithPatterns(Text, DOI_PATTERNS)
                if DOIMatch:
                    Metadata['extracted_doi'] = DOIMatch
                    self.BibliographicHitCount['DOI'] += 1
                    break
        
        # Enhanced year extraction with priority
        YearCandidates = []
        for Text, Priority in SearchTexts:
            if Text:
                for Pattern in YEAR_PATTERNS:
                    Years = Pattern.findall(Text)
                    for Year in Years:
                        try:
                            YearInt = int(Year)
                            if 1900 <= YearInt <= 2030:
                                YearCandidates.append((YearInt, Priority))
                        except:
                            continue
        
        if YearCandidates:
            # Sort by priority then by most recent year
            YearCandidates.sort(key=lambda x: (x[1], x[0]), reverse=True)
            Metadata['extracted_year'] = str(YearCandidates[0][0])
        
        # Enhanced publisher extraction with priority
        PublisherCandidates = []
        for Text, Priority in SearchTexts:
            if Text:
                for Pattern in PUBLISHER_PATTERNS:
                    Publishers = Pattern.findall(Text)
                    for Pub in Publishers:
                        if len(Pub.strip()) >= 5:
                            PublisherCandidates.append((Pub.strip()[:200], Priority))
        
        if PublisherCandidates:
            PublisherCandidates.sort(key=lambda x: x[1], reverse=True)
            Metadata['extracted_publisher'] = PublisherCandidates[0][0]
            self.BibliographicHitCount['Publisher'] += 1
        
        # Enhanced edition extraction
        for Text, Priority in SearchTexts:
            if Text and not Metadata['extracted_edition']:
                EditionMatch = ExtractWithPatterns(Text, EDITION_PATTERNS)
                if EditionMatch:
                    Metadata['extracted_edition'] = EditionMatch.strip()
                    break
        
        # Enhanced Himalaya quality scoring with bibliographic weighting
        QualityFactors = [
            bool(Metadata['pdf_title']) * 10,
            bool(Metadata['pdf_author']) * 10,
            bool(Metadata['extracted_isbn']) * 20,     # Increased weight for ISBN
            bool(Metadata['extracted_lccn']) * 15,     # NEW: LCCN highly valued
            bool(Metadata['extracted_issn']) * 10,     # NEW: ISSN for periodicals
            bool(Metadata['extracted_oclc']) * 5,      # NEW: OCLC catalog numbers
            bool(Metadata['extracted_year']) * 10,
            bool(Metadata['extracted_publisher']) * 10,
            bool(Metadata['first_page_text']) * 15,
            bool(Metadata['title_page_text']) * 10,
            bool(Metadata['copyright_page_text']) * 10,
            bool(Metadata['full_text_sample']) * 5,
            bool(Metadata['abstract_text']) * 5,
            bool(Metadata['tables_content']) * 5,
            bool(Metadata['ocr_used']) * 10,
            bool(Metadata['enhanced_extraction']) * 5,
            min(len(AllText) / 150, 15)
        ]
        
        Metadata['extraction_quality_score'] = min(100, sum(QualityFactors))
        
        # Processing metadata
        ProcessingTime = time.time() - StartTime
        Metadata['processing_time_seconds'] = round(ProcessingTime, 2)
        Metadata['extraction_method'] = '+'.join(ExtractionMethods) if ExtractionMethods else 'Failed'
        Metadata['errors'] = '; '.join(ErrorMessages) if ErrorMessages else ''
        
        self.TotalProcessingTime += ProcessingTime
        
        return Metadata
    
    @TimeoutProtected(OCR_TIMEOUT)
    def ExtractTextWithHimalayaOCR(self, PDFPath):
        """TIMEOUT-PROTECTED Himalaya OCR extraction"""
        OCRText = {
            'first_page_text': '',
            'title_page_text': '',
            'copyright_page_text': '',
            'table_of_contents': '',
            'full_text_sample': '',
            'abstract_text': ''
        }
        
        if not self.HardwareManager.ActiveEngine:
            return OCRText
        
        try:
            with tempfile.TemporaryDirectory() as TempDir:
                # Reduced settings for reliability
                Pages = convert_from_path(
                    PDFPath, 
                    dpi=200,  # Reduced from 350
                    first_page=1,
                    last_page=min(6, 10),  # Max 6 pages
                    output_folder=TempDir
                )
                
                PagesToProcess = min(4, len(Pages))  # Process max 4 pages
                
                for PageNum in range(PagesToProcess):
                    try:
                        PageImage = Pages[PageNum]
                        PageText = self.HardwareManager.ProcessImageWithOptimalEngine(
                            PageImage, 
                            f"page {PageNum + 1} of {PDFPath.name}"
                        )
                        
                        # Enhanced content classification
                        PageTextLower = PageText.lower()
                        
                        # Store by page position
                        if PageNum == 0:
                            OCRText['first_page_text'] = PageText[:MAX_TEXT_LENGTH]
                        elif PageNum == 1:
                            OCRText['title_page_text'] = PageText[:MAX_TEXT_LENGTH]
                        
                        # Store by content type
                        if 'copyright' in PageTextLower or '©' in PageText:
                            OCRText['copyright_page_text'] = PageText[:MAX_TEXT_LENGTH]
                        
                        if any(Keyword in PageTextLower for Keyword in ['contents', 'chapter', 'index']):
                            if len(PageText) > len(OCRText['table_of_contents']):
                                OCRText['table_of_contents'] = PageText[:MAX_TEXT_LENGTH]
                        
                        if 'abstract' in PageTextLower and PageNum < 3:
                            OCRText['abstract_text'] = PageText[:MAX_TEXT_LENGTH//2]
                        
                        # Collect for full text sample
                        if not OCRText['full_text_sample']:
                            OCRText['full_text_sample'] = PageText[:MAX_TEXT_LENGTH]
                        
                    except Exception as PageError:
                        print(f"   ⚠️ OCR page {PageNum + 1} error: {str(PageError)[:50]}")
                        continue
                
                self.OCRCount += 1
                return OCRText
                
        except Exception as OCRError:
            print(f"   ❌ OCR processing failed: {str(OCRError)[:50]}")
            return OCRText
    
    def ProcessAllPDFs(self):
        """Process all PDFs in the directory with enhanced progress reporting"""
        if not self.PDFDirectory.exists():
            print(f"❌ PDF directory not found: {self.PDFDirectory}")
            return False
        
        PDFFiles = list(self.PDFDirectory.glob("*.pdf"))
        TotalFiles = len(PDFFiles)
        
        if TotalFiles == 0:
            print(f"❌ No PDF files found in {self.PDFDirectory}")
            return False
        
        # Filter out already processed files
        UnprocessedFiles = [F for F in PDFFiles if F.stem not in self.ProcessedFiles]
        RemainingCount = len(UnprocessedFiles)
        
        print(f"\n📊 HIMALAYA EXTRACTION SUMMARY:")
        print(f"   📁 Total PDFs found: {TotalFiles}")
        print(f"   ✅ Previously processed: {len(self.ProcessedFiles)}")
        print(f"   🔄 Remaining to process: {RemainingCount}")
        
        if RemainingCount == 0:
            print(f"\n🎉 All PDFs already processed!")
            print(f"📊 Enhanced database migration ready with maximum content extraction!")
            print(f"🛡️ Zero infinite hangs - timeout protection working perfectly!")
            print(f"🔄 Output: {self.OutputFile}")
        else:
            Missing = TotalFiles - len(self.ProcessedFiles) - self.ProcessedCount
            print(f"\n⚠️ {Missing} PDFs still need processing")
            print(f"🔄 Run the script again to continue")
        
        if RemainingCount == 0:
            return True
        
        print(f"🔄 Starting timeout-protected Himalaya extraction of {RemainingCount} files...\n")
        
        # Process PDFs with timeout protection
        for FileIndex, PDFFile in enumerate(UnprocessedFiles, 1):
            try:
                print(f"[{FileIndex:4d}/{RemainingCount}] Processing: {PDFFile.name}")
                
                # TIMEOUT-PROTECTED EXTRACTION
                try:
                    ExtractedMetadata = self.ExtractPDFMetadata(PDFFile)
                    self.AppendToCSV(ExtractedMetadata)
                    self.ProcessedCount += 1
                    
                    # Display results with bibliographic info
                    Quality = ExtractedMetadata['extraction_quality_score']
                    ProcessingTime = ExtractedMetadata['processing_time_seconds']
                    
                    StatusFlags = []
                    if ExtractedMetadata['ocr_used']:
                        StatusFlags.append("🔍 OCR")
                    if ExtractedMetadata['enhanced_extraction']:
                        StatusFlags.append("⚡ Enhanced")
                    if ExtractedMetadata['gpu_accelerated']:
                        StatusFlags.append("🚀 GPU")
                    if ExtractedMetadata.get('timeout_protection'):
                        StatusFlags.append("⏰ Protected")
                    
                    # Add bibliographic flags
                    BibFlags = []
                    if ExtractedMetadata['extracted_isbn']:
                        BibFlags.append("📚 ISBN")
                    if ExtractedMetadata['extracted_lccn']:
                        BibFlags.append("🏛️ LCCN")
                    if ExtractedMetadata['extracted_issn']:
                        BibFlags.append("📰 ISSN")
                    if ExtractedMetadata['extracted_oclc']:
                        BibFlags.append("🌐 OCLC")
                    
                    AllFlags = StatusFlags + BibFlags
                    Status = " ".join(AllFlags) if AllFlags else "📄 Text"
                    print(f"   ✅ Quality: {Quality:.0f}% | Time: {ProcessingTime:.1f}s | {Status}")
                
                except TimeoutError:
                    # Handle timeout gracefully
                    print(f"   ⏰ TIMEOUT after {TOTAL_PDF_TIMEOUT}s - marking as corrupted PDF")
                    
                    CorruptedMetadata = {
                        'filename': PDFFile.name,
                        'file_size_mb': round(PDFFile.stat().st_size / (1024*1024), 2),
                        'page_count': 0,
                        'database_category': 'Corrupted',
                        'database_subject': 'Corrupted',
                        'pdf_title': 'CORRUPTED PDF - TIMEOUT',
                        'extraction_method': 'Timeout Protection',
                        'errors': f'Timeout after {TOTAL_PDF_TIMEOUT}s - likely corrupted PDF structure',
                        'extraction_quality_score': 0,
                        'processing_time_seconds': TOTAL_PDF_TIMEOUT,
                        'timeout_protection': True
                    }
                    
                    # Fill in missing fields with empty values
                    CSVColumns = [
                        'pdf_author', 'pdf_subject', 'pdf_creator', 'pdf_producer',
                        'pdf_creation_date', 'extracted_isbn', 'extracted_lccn', 'extracted_issn',
                        'extracted_oclc', 'extracted_year', 'extracted_publisher', 'extracted_edition', 
                        'extracted_doi', 'first_page_text', 'title_page_text', 'copyright_page_text',
                        'table_of_contents', 'full_text_sample', 'abstract_text', 'tables_content',
                        'ocr_used', 'enhanced_extraction', 'hardware_acceleration', 'gpu_accelerated'
                    ]
                    
                    for Col in CSVColumns:
                        if Col not in CorruptedMetadata:
                            if Col in ['ocr_used', 'enhanced_extraction', 'gpu_accelerated']:
                                CorruptedMetadata[Col] = False
                            else:
                                CorruptedMetadata[Col] = ''
                    
                    self.AppendToCSV(CorruptedMetadata)
                    self.TimeoutCount += 1
                    self.CorruptedPDFCount += 1
                    
                    print(f"   🛡️ Timeout protection prevented infinite hang - continuing...")
                
                # Progress reporting
                if FileIndex % PROGRESS_INTERVAL == 0:
                    self.ShowHimalayaProgress(FileIndex, RemainingCount)
                
            except Exception as ProcessingError:
                print(f"   ❌ Critical error processing {PDFFile.name}: {ProcessingError}")
                self.ErrorCount += 1
                continue
        
        # Final reporting
        self.ShowHimalayaProgress(RemainingCount, RemainingCount)
        self.GenerateHimalayaReport(TotalFiles, len(self.ProcessedFiles) + self.ProcessedCount)
        
        return True
    
    def AppendToCSV(self, BookData):
        """Append record to Himalaya CSV with enhanced bibliographic fields"""
        FileExists = os.path.exists(self.OutputFile)
        
        # Himalaya enhanced CSV columns with new bibliographic fields
        Columns = [
            'filename', 'file_size_mb', 'page_count',
            'database_category', 'database_subject',
            'pdf_title', 'pdf_author', 'pdf_subject', 'pdf_creator', 'pdf_producer',
            'pdf_creation_date', 'extracted_isbn', 'extracted_lccn', 'extracted_issn',
            'extracted_oclc', 'extracted_year', 'extracted_publisher', 'extracted_edition', 
            'extracted_doi', 'first_page_text', 'title_page_text', 'copyright_page_text',
            'table_of_contents', 'full_text_sample', 'abstract_text', 'tables_content',
            'extraction_method', 'ocr_used', 'enhanced_extraction',
            'hardware_acceleration', 'gpu_accelerated', 'timeout_protection',
            'extraction_quality_score', 'processing_time_seconds', 'errors'
        ]
        
        try:
            with open(self.OutputFile, 'a', newline='', encoding='utf-8') as CSVFile:
                Writer = csv.DictWriter(CSVFile, fieldnames=Columns)
                
                if not FileExists:
                    Writer.writeheader()
                
                Writer.writerow(BookData)
                
        except Exception as SaveError:
            print(f"❌ Error appending to CSV: {SaveError}")
    
    def ShowHimalayaProgress(self, Current, Total):
        """Enhanced progress reporting with bibliographic metrics"""
        ProcessedPct = (Current / Total) * 100
        
        # Get hardware performance report
        Performance = self.HardwareManager.GetPerformanceReport()
        
        AvgProcessingTime = self.TotalProcessingTime / Current if Current > 0 else 0
        EstimatedRemaining = (Total - Current) * AvgProcessingTime / 60  # minutes
        
        print(f"\n🏔️ HIMALAYA PROGRESS REPORT (ENHANCED BIBLIOGRAPHIC): {Current}/{Total} ({ProcessedPct:.1f}%)")
        print(f"   ✅ Successfully processed: {self.ProcessedCount}")
        print(f"   🔍 OCR extractions: {self.OCRCount}")
        print(f"   ⚡ Enhanced extractions: {self.EnhancedExtractionCount}")
        print(f"   🚀 GPU utilization: {Performance['GPU_Usage_Percent']:.1f}%")
        print(f"   ⏰ Timeout protections: {self.TimeoutCount}")
        print(f"   🛡️ Corrupted PDFs handled: {self.CorruptedPDFCount}")
        
        # Enhanced bibliographic reporting
        print(f"   📚 BIBLIOGRAPHIC EXTRACTION:")
        print(f"      📖 ISBNs extracted: {self.BibliographicHitCount['ISBN']}")
        print(f"      🏛️ LCCNs extracted: {self.BibliographicHitCount['LCCN']} (NEW!)")
        print(f"      📰 ISSNs extracted: {self.BibliographicHitCount['ISSN']} (NEW!)")
        print(f"      🌐 OCLC numbers: {self.BibliographicHitCount['OCLC']} (NEW!)")
        print(f"      🔗 DOIs extracted: {self.BibliographicHitCount['DOI']}")
        print(f"      🏢 Publishers found: {self.BibliographicHitCount['Publisher']}")
        
        if Performance['GPU_Speedup'] > 0:
            print(f"   ⚡ GPU speedup: {Performance['GPU_Speedup']:.1f}x")
        
        print(f"   ⏱️ Avg time per PDF: {AvgProcessingTime:.1f}s")
        print(f"   🕒 Est. remaining: {EstimatedRemaining:.0f} minutes")
        print(f"   ❌ Errors: {self.ErrorCount}")
        print()
    
    def GenerateHimalayaReport(self, TotalInDirectory, TotalProcessed):
        """Generate comprehensive Himalaya performance report with enhanced bibliographic metrics"""
        print("\n" + "=" * 80)
        print("🏔️ HIMALAYA ENHANCED BIBLIOGRAPHIC EXTRACTION COMPLETE!")
        print("=" * 80)
        
        # Basic statistics
        print(f"📁 Total PDFs in directory: {TotalInDirectory}")
        print(f"✅ Total processed: {TotalProcessed}")
        print(f"🔍 OCR extractions performed: {self.OCRCount}")
        print(f"⚡ Enhanced extractions: {self.EnhancedExtractionCount}")
        print(f"⏰ Timeout protections triggered: {self.TimeoutCount}")
        print(f"🛡️ Corrupted PDFs handled gracefully: {self.CorruptedPDFCount}")
        print(f"❌ Total errors: {self.ErrorCount}")
        
        # Enhanced bibliographic reporting
        print(f"\n📚 BIBLIOGRAPHIC IDENTIFIER EXTRACTION RESULTS:")
        TotalBiblio = sum(self.BibliographicHitCount.values())
        if TotalProcessed > 0:
            print(f"   📖 ISBNs: {self.BibliographicHitCount['ISBN']} ({self.BibliographicHitCount['ISBN']/TotalProcessed*100:.1f}%)")
            print(f"   🏛️ LCCNs: {self.BibliographicHitCount['LCCN']} ({self.BibliographicHitCount['LCCN']/TotalProcessed*100:.1f}%) ✨ NEW!")
            print(f"   📰 ISSNs: {self.BibliographicHitCount['ISSN']} ({self.BibliographicHitCount['ISSN']/TotalProcessed*100:.1f}%) ✨ NEW!")
            print(f"   🌐 OCLC: {self.BibliographicHitCount['OCLC']} ({self.BibliographicHitCount['OCLC']/TotalProcessed*100:.1f}%) ✨ NEW!")
            print(f"   🔗 DOIs: {self.BibliographicHitCount['DOI']} ({self.BibliographicHitCount['DOI']/TotalProcessed*100:.1f}%)")
            print(f"   🏢 Publishers: {self.BibliographicHitCount['Publisher']} ({self.BibliographicHitCount['Publisher']/TotalProcessed*100:.1f}%)")
            print(f"   📊 Total bibliographic identifiers: {TotalBiblio}")
        
        SuccessRate = ((TotalProcessed - self.ErrorCount) / TotalInDirectory * 100) if TotalInDirectory > 0 else 0
        print(f"\n📈 Success rate: {SuccessRate:.1f}%")
        
        if TotalProcessed == TotalInDirectory:
            print(f"\n🎉 ALL PDFs PROCESSED WITH ENHANCED BIBLIOGRAPHIC EXTRACTION!")
            print(f"📊 Enhanced database migration ready with maximum content extraction!")
            print(f"🛡️ Zero infinite hangs - timeout protection working perfectly!")
            print(f"📚 Comprehensive bibliographic identifiers extracted!")
            print(f"🔄 Output: {self.OutputFile}")
        else:
            Missing = TotalInDirectory - TotalProcessed
            print(f"\n⚠️ {Missing} PDFs still need processing")
            print(f"🔄 Run the script again to continue")
        
        print("=" * 80)
        print("🏔️ Himalaya enhanced bibliographic extraction complete!")

if __name__ == "__main__":
    print("🏔️ HIMALAYA ENHANCED BIBLIOGRAPHIC GPU PDF EXTRACTOR")
    print("Standard: AIDEV-PascalCase-1.8 (Hardware-Accelerated + Timeout Protection + Enhanced Bibliographic)")
    print("Enhanced Features: ISBN, LCCN, ISSN, OCLC, DOI extraction with validation")
    print("Expected Improvements: ISBN 45.7%→75%+, New LCCN 40-60%, Publisher 28.4%→65%+")
    print("=" * 80)
    
    # Run enhanced Himalaya extraction
    Extractor = HimalayaPDFExtractor()
    Success = Extractor.ProcessAllPDFs()
    
    if Success:
        print(f"\n🎉 Enhanced bibliographic Himalaya extraction complete!")
        print(f"📊 Results saved to: {OUTPUT_CSV}")
        print(f"🛡️ Zero infinite hangs - corruption handled gracefully!")
        print(f"📚 Enhanced bibliographic identifiers extracted successfully!")
    else:
        print(f"\n❌ Himalaya extraction failed!")
        exit(1)