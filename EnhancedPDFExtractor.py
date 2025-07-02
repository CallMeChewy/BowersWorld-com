#!/usr/bin/env python3
"""
File: EnhancedPDFExtractor.py
Path: BowersWorld-com/Scripts/Enhanced/EnhancedPDFExtractor.py
Standard: AIDEV-PascalCase-1.8
Created: 2025-07-01
Modified: 2025-07-01
Author: Herb Bowers - Project Himalaya
Description: Maximum PDF text extraction with OCR capabilities for Anderson's Library

Enhanced features:
- Tesseract OCR for scanned documents
- Expanded text capture (10,000+ characters per field)
- Multiple extraction methods with fallbacks
- Image-based PDF processing
- Comprehensive page range extraction
- Enhanced error handling and recovery
"""

import os
import csv
import sqlite3
from pathlib import Path
import PyPDF2
import pandas as pd
from datetime import datetime
import re
import fitz  # PyMuPDF
import warnings
warnings.filterwarnings("ignore")

# OCR and Image Processing
import pytesseract
from PIL import Image
import io
import numpy as np
import cv2

# Additional text processing
import pdfplumber
from pdf2image import convert_from_path
import tempfile

# Configuration - Enhanced limits
PDF_DIRECTORY = "/home/herb/Desktop/Not Backed Up/Anderson's Library/Andy/Anderson eBooks"
DATABASE_PATH = "/home/herb/Desktop/BowersWorld-com/Assets/my_library.db"
OUTPUT_CSV = "/home/herb/Desktop/BowersWorld-com/AndersonLibrary_Enhanced_Metadata.csv"
PROGRESS_INTERVAL = 10

# Enhanced text extraction limits
MAX_TEXT_LENGTH = 15000  # Increased from 1000 to 15,000 characters
MAX_PAGES_TO_PROCESS = 10  # Process up to 10 pages for content
OCR_DPI = 300  # High quality OCR processing
TESSERACT_CONFIG = '--oem 3 --psm 6'  # OCR Engine Mode and Page Segmentation Mode

# Text extraction patterns - Enhanced
ISBN_PATTERN = re.compile(r'ISBN[:\-\s]*([0-9\-X]{10,17})', re.IGNORECASE)
YEAR_PATTERN = re.compile(r'(19|20)\d{2}')
PUBLISHER_PATTERN = re.compile(r'Published by[:\s]*([^.\n\r]{5,50})', re.IGNORECASE)
COPYRIGHT_PATTERN = re.compile(r'Copyright[:\s]*©?\s*(\d{4})', re.IGNORECASE)
EDITION_PATTERN = re.compile(r'(\d+)(st|nd|rd|th)\s+edition', re.IGNORECASE)
DOI_PATTERN = re.compile(r'DOI[:\s]*([0-9a-zA-Z./\-]{10,50})', re.IGNORECASE)

class EnhancedPDFExtractor:
    def __init__(self, PDFDirectory, DatabasePath, OutputFile):
        self.PDFDirectory = Path(PDFDirectory)
        self.DatabasePath = DatabasePath
        self.OutputFile = OutputFile
        self.ProcessedCount = 0
        self.ErrorCount = 0
        self.OCRCount = 0
        self.EnhancedExtractionCount = 0
        
        # Verify OCR capability
        self.VerifyOCRSetup()
        
        # Load existing data if available
        self.LoadExistingData()
        self.LoadDatabaseInfo()
    
    def VerifyOCRSetup(self):
        """Verify Tesseract OCR is properly installed and configured"""
        try:
            # Test Tesseract
            test_result = pytesseract.get_tesseract_version()
            print(f"✅ Tesseract OCR detected: {test_result}")
            self.OCRAvailable = True
        except Exception as OCRError:
            print(f"⚠️ Tesseract OCR not available: {OCRError}")
            print("   Install with: sudo apt-get install tesseract-ocr")
            print("   Or: brew install tesseract (macOS)")
            self.OCRAvailable = False
    
    def LoadExistingData(self):
        """Load previously processed PDFs to resume extraction"""
        self.ProcessedFiles = set()
        
        if os.path.exists(self.OutputFile):
            try:
                existing_df = pd.read_csv(self.OutputFile)
                self.ProcessedFiles = set(existing_df['filename'].str.replace('.pdf', '', regex=False))
                print(f"✅ Found {len(self.ProcessedFiles)} previously processed PDFs")
                print(f"📄 Will resume extraction for remaining files...")
            except Exception as e:
                print(f"⚠️ Could not load existing CSV: {e}")
                print("📄 Starting fresh extraction...")
                self.ProcessedFiles = set()
        else:
            print("📄 No existing CSV found, starting fresh extraction...")
    
    def LoadDatabaseInfo(self):
        """Load existing book data from SQLite database"""
        self.DatabaseBooks = {}
        
        if os.path.exists(self.DatabasePath):
            try:
                conn = sqlite3.connect(self.DatabasePath)
                cursor = conn.cursor()
                
                query = '''
                    SELECT b.title, c.category, s.subject 
                    FROM books b
                    LEFT JOIN subjects s ON b.subject_id = s.id
                    LEFT JOIN categories c ON s.category_id = c.id
                '''
                
                books = cursor.execute(query).fetchall()
                
                for title, category, subject in books:
                    self.DatabaseBooks[title] = {
                        'category': category or 'Unknown',
                        'subject': subject or 'Unknown'
                    }
                
                conn.close()
                print(f"✅ Loaded {len(self.DatabaseBooks)} books from database")
                
            except Exception as DbError:
                print(f"⚠️ Database error: {DbError}")
                self.DatabaseBooks = {}
        else:
            print(f"⚠️ Database not found at {self.DatabasePath}")
            self.DatabaseBooks = {}
    
    def ExtractTextWithOCR(self, PDFPath):
        """Extract text using OCR for image-based PDFs"""
        OCRText = {
            'first_page_text': '',
            'title_page_text': '',
            'copyright_page_text': '',
            'table_of_contents': '',
            'full_text_sample': ''
        }
        
        if not self.OCRAvailable:
            return OCRText
        
        try:
            print(f"   🔍 Performing OCR extraction...")
            
            # Convert PDF pages to images
            with tempfile.TemporaryDirectory() as temp_dir:
                pages = convert_from_path(
                    PDFPath, 
                    dpi=OCR_DPI,
                    first_page=1,
                    last_page=min(MAX_PAGES_TO_PROCESS, 10),
                    output_folder=temp_dir
                )
                
                for page_num, page_image in enumerate(pages[:MAX_PAGES_TO_PROCESS]):
                    # Convert PIL image to numpy array for OpenCV processing
                    img_array = np.array(page_image)
                    
                    # Enhance image for better OCR
                    enhanced_img = self.EnhanceImageForOCR(img_array)
                    
                    # Convert back to PIL Image
                    enhanced_pil = Image.fromarray(enhanced_img)
                    
                    # Perform OCR
                    page_text = pytesseract.image_to_string(
                        enhanced_pil, 
                        config=TESSERACT_CONFIG
                    )
                    
                    # Store text based on page number
                    if page_num == 0:
                        OCRText['first_page_text'] = page_text[:MAX_TEXT_LENGTH]
                    elif page_num == 1:
                        OCRText['title_page_text'] = page_text[:MAX_TEXT_LENGTH]
                    
                    # Look for copyright page
                    if 'copyright' in page_text.lower() or '©' in page_text:
                        OCRText['copyright_page_text'] = page_text[:MAX_TEXT_LENGTH]
                    
                    # Look for table of contents
                    if any(keyword in page_text.lower() for keyword in ['contents', 'table of contents', 'index']):
                        OCRText['table_of_contents'] = page_text[:MAX_TEXT_LENGTH]
                    
                    # Accumulate full text sample
                    if len(OCRText['full_text_sample']) < MAX_TEXT_LENGTH:
                        remaining_space = MAX_TEXT_LENGTH - len(OCRText['full_text_sample'])
                        OCRText['full_text_sample'] += page_text[:remaining_space]
            
            self.OCRCount += 1
            print(f"   ✅ OCR extraction completed")
            
        except Exception as OCRError:
            print(f"   ❌ OCR extraction failed: {str(OCRError)[:100]}")
        
        return OCRText
    
    def EnhanceImageForOCR(self, img_array):
        """Enhance image quality for better OCR results"""
        # Convert to grayscale
        if len(img_array.shape) == 3:
            gray = cv2.cvtColor(img_array, cv2.COLOR_RGB2GRAY)
        else:
            gray = img_array
        
        # Apply noise reduction
        denoised = cv2.fastNlMeansDenoising(gray)
        
        # Apply adaptive thresholding for better text contrast
        thresh = cv2.adaptiveThreshold(
            denoised, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
        )
        
        # Apply morphological operations to clean up
        kernel = np.ones((1, 1), np.uint8)
        cleaned = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
        return cleaned
    
    def ExtractTextWithPDFPlumber(self, PDFPath):
        """Extract text using pdfplumber for enhanced table and layout detection"""
        PlumberText = {
            'structured_text': '',
            'tables_content': '',
            'metadata_enhanced': {}
        }
        
        try:
            with pdfplumber.open(PDFPath) as pdf:
                # Extract enhanced metadata
                PlumberText['metadata_enhanced'] = pdf.metadata or {}
                
                # Extract text from first few pages with layout preservation
                all_text = []
                for page_num, page in enumerate(pdf.pages[:MAX_PAGES_TO_PROCESS]):
                    # Extract text with layout
                    page_text = page.extract_text(layout=True)
                    if page_text:
                        all_text.append(f"=== Page {page_num + 1} ===\n{page_text}\n")
                    
                    # Extract tables
                    tables = page.extract_tables()
                    if tables:
                        for table_num, table in enumerate(tables):
                            table_text = f"\n=== Table {table_num + 1} on Page {page_num + 1} ===\n"
                            for row in table:
                                if row:
                                    table_text += " | ".join(str(cell) if cell else "" for cell in row) + "\n"
                            PlumberText['tables_content'] += table_text
                
                PlumberText['structured_text'] = ''.join(all_text)[:MAX_TEXT_LENGTH]
                
        except Exception as PlumberError:
            print(f"   ⚠️ PDFPlumber extraction failed: {str(PlumberError)[:100]}")
        
        return PlumberText
    
    def ExtractPDFMetadata(self, PDFPath):
        """Enhanced metadata extraction with multiple methods and OCR"""
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
            'extracted_year': '',
            'extracted_publisher': '',
            'extracted_edition': '',
            'extracted_doi': '',
            'first_page_text': '',
            'title_page_text': '',
            'copyright_page_text': '',
            'table_of_contents': '',
            'full_text_sample': '',
            'tables_content': '',
            'database_category': 'Not Found',
            'database_subject': 'Not Found',
            'extraction_method': 'None',
            'ocr_used': False,
            'enhanced_extraction': False,
            'extraction_quality_score': 0,
            'errors': ''
        }
        
        # Get database info for this book
        BookTitle = PDFPath.stem
        if BookTitle in self.DatabaseBooks:
            Metadata['database_category'] = self.DatabaseBooks[BookTitle]['category']
            Metadata['database_subject'] = self.DatabaseBooks[BookTitle]['subject']
        
        ErrorMessages = []
        ExtractionMethods = []
        AllExtractedText = []
        
        # Method 1: PyMuPDF (Primary)
        try:
            PDFDocument = fitz.open(str(PDFPath))
            Metadata['page_count'] = len(PDFDocument)
            ExtractionMethods.append('PyMuPDF')
            
            # Extract PDF metadata with safe string conversion
            PDFMetadata = PDFDocument.metadata
            if PDFMetadata: # Check if PDFMetadata is not None
                Metadata['pdf_title'] = str(PDFMetadata.get('title', '')).strip()
                Metadata['pdf_author'] = str(PDFMetadata.get('author', '')).strip()
                Metadata['pdf_subject'] = str(PDFMetadata.get('subject', '')).strip()
                Metadata['pdf_creator'] = str(PDFMetadata.get('creator', '')).strip()
                Metadata['pdf_producer'] = str(PDFMetadata.get('producer', '')).strip()
                
                if PDFMetadata.get('creationDate'):
                    Metadata['pdf_creation_date'] = str(PDFMetadata['creationDate'])[:10]
            
            # Extract text from multiple pages with increased limits
            if len(PDFDocument) > 0:
                # First page
                try:
                    FirstPage = PDFDocument[0]
                    first_text = FirstPage.get_text() if FirstPage else '' # Check if FirstPage is not None
                    Metadata['first_page_text'] = first_text[:MAX_TEXT_LENGTH]
                    AllExtractedText.append(first_text)
                except Exception as e:
                    ErrorMessages.append(f"PyMuPDF First Page Text: {str(e)[:100]}")
                
                # Title page (usually page 2)
                if len(PDFDocument) > 1:
                    try:
                        TitlePage = PDFDocument[1]
                        title_text = TitlePage.get_text() if TitlePage else '' # Check if TitlePage is not None
                        Metadata['title_page_text'] = title_text[:MAX_TEXT_LENGTH]
                        AllExtractedText.append(title_text)
                    except Exception as e:
                        ErrorMessages.append(f"PyMuPDF Title Page Text: {str(e)[:100]}")
                
                # Look for copyright page (scan first 5 pages)
                for PageNum in range(min(5, len(PDFDocument))):
                    try:
                        Page = PDFDocument[PageNum]
                        PageText = Page.get_text() if Page else '' # Check if Page is not None
                        if 'copyright' in PageText.lower() or '©' in PageText:
                            Metadata['copyright_page_text'] = PageText[:MAX_TEXT_LENGTH]
                            break
                    except Exception as e:
                        ErrorMessages.append(f"PyMuPDF Copyright Page Text: {str(e)[:100]}")
                        continue
                
                # Look for table of contents
                for PageNum in range(min(10, len(PDFDocument))):
                    try:
                        Page = PDFDocument[PageNum]
                        PageText = Page.get_text() if Page else '' # Check if Page is not None
                        if any(keyword in PageText.lower() for keyword in ['contents', 'table of contents']):
                            Metadata['table_of_contents'] = PageText[:MAX_TEXT_LENGTH]
                            break
                    except Exception as e:
                        ErrorMessages.append(f"PyMuPDF TOC Page Text: {str(e)[:100]}")
                        continue
                
                # Extract full text sample from multiple pages
                full_sample = []
                for PageNum in range(min(MAX_PAGES_TO_PROCESS, len(PDFDocument))):
                    try:
                        Page = PDFDocument[PageNum]
                        page_text = Page.get_text() if Page else '' # Check if Page is not None
                        full_sample.append(page_text)
                        if len(' '.join(full_sample)) > MAX_TEXT_LENGTH:
                            break
                    except Exception as e:
                        ErrorMessages.append(f"PyMuPDF Full Text Sample: {str(e)[:100]}")
                        continue
                
                Metadata['full_text_sample'] = ' '.join(full_sample)[:MAX_TEXT_LENGTH]
            
            PDFDocument.close()
            
        except Exception as PyMuPDFError:
            ErrorMessages.append(f"PyMuPDF: {str(PyMuPDFError)[:100]}")
        
        # Method 2: PyPDF2 (Fallback)
        if not Metadata['first_page_text']:  # Only if PyMuPDF failed
            try:
                with open(PDFPath, 'rb') as PDFFile:
                    PDFReader = PyPDF2.PdfReader(PDFFile)
                    Metadata['page_count'] = len(PDFReader.pages)
                    ExtractionMethods.append('PyPDF2')
                    
                    if PDFReader.metadata: # Check if PDFReader.metadata is not None
                        if not Metadata['pdf_title']:
                            Metadata['pdf_title'] = str(PDFReader.metadata.get('/Title', '')).strip()
                        if not Metadata['pdf_author']:
                            Metadata['pdf_author'] = str(PDFReader.metadata.get('/Author', '')).strip()
                        if not Metadata['pdf_subject']:
                            Metadata['pdf_subject'] = str(PDFReader.metadata.get('/Subject', '')).strip()
                        if not Metadata['pdf_creator']:
                            Metadata['pdf_creator'] = str(PDFReader.metadata.get('/Creator', '')).strip()
                        if not Metadata['pdf_producer']:
                            Metadata['pdf_producer'] = str(PDFReader.metadata.get('/Producer', '')).strip()
                        
                        if not Metadata['pdf_creation_date']:
                            CreationDate = PDFReader.metadata.get('/CreationDate')
                            if CreationDate:
                                Metadata['pdf_creation_date'] = str(CreationDate)[:10]
                    
                    # Extract text from first few pages
                    if len(PDFReader.pages) > 0:
                        try:
                            first_text = PDFReader.pages[0].extract_text()
                            Metadata['first_page_text'] = first_text[:MAX_TEXT_LENGTH]
                            AllExtractedText.append(first_text)
                        except Exception as e:
                            ErrorMessages.append(f"PyPDF2 First Page Text: {str(e)[:100]}")
                        
                        if len(PDFReader.pages) > 1:
                            try:
                                title_text = PDFReader.pages[1].extract_text()
                                Metadata['title_page_text'] = title_text[:MAX_TEXT_LENGTH]
                                AllExtractedText.append(title_text)
                            except Exception as e:
                                ErrorMessages.append(f"PyPDF2 Title Page Text: {str(e)[:100]}")
                        
                        # Look for copyright page
                        for PageNum in range(min(5, len(PDFReader.pages))):
                            try:
                                PageText = PDFReader.pages[PageNum].extract_text()
                                if 'copyright' in PageText.lower() or '©' in PageText:
                                    Metadata['copyright_page_text'] = PageText[:MAX_TEXT_LENGTH]
                                    break
                            except Exception as e:
                                ErrorMessages.append(f"PyPDF2 Copyright Page Text: {str(e)[:100]}")
                                continue
                
            except Exception as PyPDF2Error:
                ErrorMessages.append(f"PyPDF2: {str(PyPDF2Error)[:100]}")
        
        # Method 3: PDFPlumber (Enhanced extraction)
        if not Metadata['tables_content']:  # Extract tables and structured content
            try:
                PlumberData = self.ExtractTextWithPDFPlumber(PDFPath)
                if PlumberData['structured_text']:
                    ExtractionMethods.append('PDFPlumber')
                    Metadata['enhanced_extraction'] = True
                    self.EnhancedExtractionCount += 1
                    
                    # Use structured text if we don't have good text yet
                    if not Metadata['full_text_sample']:
                        Metadata['full_text_sample'] = PlumberData['structured_text']
                    
                    Metadata['tables_content'] = PlumberData['tables_content'][:MAX_TEXT_LENGTH]
                    
                    # Enhanced metadata
                    enhanced_meta = PlumberData['metadata_enhanced']
                    for key, value in enhanced_meta.items():
                        if key == 'Title' and not Metadata['pdf_title']:
                            Metadata['pdf_title'] = str(value).strip()
                        elif key == 'Author' and not Metadata['pdf_author']:
                            Metadata['pdf_author'] = str(value).strip()
                
            except Exception as PlumberError:
                ErrorMessages.append(f"PDFPlumber: {str(PlumberError)[:100]}")
        
        # Method 4: OCR (For image-based PDFs or when text extraction fails)
        text_quality = len(' '.join(filter(None, [
            Metadata.get('first_page_text', ''),
            Metadata.get('title_page_text', ''),
            Metadata.get('copyright_page_text', '')
        ])).strip())
        
        if text_quality < 100 and self.OCRAvailable:  # Poor text extraction, try OCR
            try:
                OCRData = self.ExtractTextWithOCR(PDFPath)
                ExtractionMethods.append('OCR')
                Metadata['ocr_used'] = True
                
                # Use OCR text if better than existing extraction
                if len(OCRData['first_page_text']) > len(Metadata['first_page_text']):
                    Metadata['first_page_text'] = OCRData['first_page_text']
                if len(OCRData['title_page_text']) > len(Metadata['title_page_text']):
                    Metadata['title_page_text'] = OCRData['title_page_text']
                if len(OCRData['copyright_page_text']) > len(Metadata['copyright_page_text']):
                    Metadata['copyright_page_text'] = OCRData['copyright_page_text']
                if len(OCRData['table_of_contents']) > len(Metadata['table_of_contents']):
                    Metadata['table_of_contents'] = OCRData['table_of_contents']
                if len(OCRData['full_text_sample']) > len(Metadata['full_text_sample']):
                    Metadata['full_text_sample'] = OCRData['full_text_sample']
                
                AllExtractedText.extend([
                    OCRData['first_page_text'],
                    OCRData['title_page_text'],
                    OCRData['copyright_page_text'],
                    OCRData['full_text_sample']
                ])
                
            except Exception as OCRError:
                ErrorMessages.append(f"OCR: {str(OCRError)[:100]}")
        
        # Extract specific information from all collected text
        AllText = ' '.join(filter(None, AllExtractedText))
        
        if AllText:
            # Extract ISBN
            ISBNMatch = ISBN_PATTERN.search(AllText)
            if ISBNMatch:
                Metadata['extracted_isbn'] = ISBNMatch.group(1).replace('-', '').replace(' ', '')
            
            # Extract DOI
            DOIMatch = DOI_PATTERN.search(AllText)
            if DOIMatch:
                Metadata['extracted_doi'] = DOIMatch.group(1)
            
            # Extract publication year
            YearMatches = YEAR_PATTERN.findall(AllText)
            if YearMatches:
                Years = [int(year) for year in YearMatches if 1900 <= int(year) <= 2025]
                if Years:
                    Metadata['extracted_year'] = max(Years)
            
            # Extract publisher
            PublisherMatch = PUBLISHER_PATTERN.search(AllText)
            if PublisherMatch:
                Metadata['extracted_publisher'] = PublisherMatch.group(1).strip()
            
            # Extract copyright year if no publication year found
            if not Metadata['extracted_year']:
                CopyrightMatch = COPYRIGHT_PATTERN.search(AllText)
                if CopyrightMatch:
                    Metadata['extracted_year'] = int(CopyrightMatch.group(1))
            
            # Extract edition
            EditionMatch = EDITION_PATTERN.search(AllText)
            if EditionMatch:
                Metadata['extracted_edition'] = f"{EditionMatch.group(1)}{EditionMatch.group(2)} edition"
        
        # Calculate extraction quality score
        quality_factors = [
            bool(Metadata['pdf_title']) * 10,
            bool(Metadata['pdf_author']) * 10,
            bool(Metadata['extracted_isbn']) * 15,
            bool(Metadata['extracted_year']) * 10,
            bool(Metadata['first_page_text']) * 20,
            bool(Metadata['title_page_text']) * 15,
            bool(Metadata['copyright_page_text']) * 10,
            bool(Metadata['full_text_sample']) * 10,
            len(AllText) / 100  # Bonus for amount of text extracted
        ]
        
        Metadata['extraction_quality_score'] = min(100, sum(quality_factors))
        
        # Set extraction method
        Metadata['extraction_method'] = '+'.join(ExtractionMethods) if ExtractionMethods else 'Failed'
        
        # Store errors as string
        Metadata['errors'] = '; '.join(ErrorMessages) if ErrorMessages else ''
        
        return Metadata
    
    def ProcessRemainingPDFs(self):
        """Process only PDFs that haven't been processed yet with enhanced extraction"""
        print(f"🚀 ENHANCED PDF METADATA EXTRACTOR WITH OCR")
        print("=" * 80)
        print(f"📂 PDF Directory: {self.PDFDirectory}")
        print(f"📊 Output CSV: {self.OutputFile}")
        print(f"🔍 OCR Available: {self.OCRAvailable}")
        print(f"📏 Max text per field: {MAX_TEXT_LENGTH:,} characters")
        print(f"📄 Max pages to process: {MAX_PAGES_TO_PROCESS}")
        print("=" * 80)
        
        if not self.PDFDirectory.exists():
            print(f"❌ PDF directory not found: {self.PDFDirectory}")
            return False
        
        # Find all PDF files
        AllPDFFiles = list(self.PDFDirectory.glob("*.pdf"))
        TotalFiles = len(AllPDFFiles)
        
        # Filter out already processed files
        UnprocessedFiles = [
            pdf for pdf in AllPDFFiles 
            if pdf.stem not in self.ProcessedFiles
        ]
        
        RemainingCount = len(UnprocessedFiles)
        
        print(f"📁 Total PDFs in directory: {TotalFiles}")
        print(f"✅ Already processed: {len(self.ProcessedFiles)}")
        print(f"⏳ Remaining to process: {RemainingCount}")
        
        if RemainingCount == 0:
            print("🎉 All PDFs have been processed!")
            return True
        
        print(f"🔄 Starting enhanced extraction of remaining {RemainingCount} files...\n")
        
        # Process remaining PDFs
        for FileIndex, PDFFile in enumerate(UnprocessedFiles, 1):
            try:
                print(f"[{FileIndex:4d}/{RemainingCount}] Processing: {PDFFile.name}")
                
                ExtractedMetadata = self.ExtractPDFMetadata(PDFFile)
                self.AppendToCSV(ExtractedMetadata)
                self.ProcessedCount += 1
                
                # Show enhanced progress
                quality = ExtractedMetadata['extraction_quality_score']
                ocr_status = "🔍 OCR" if ExtractedMetadata['ocr_used'] else ""
                enhanced_status = "⚡ Enhanced" if ExtractedMetadata['enhanced_extraction'] else ""
                
                print(f"   ✅ Quality: {quality:.0f}% {ocr_status} {enhanced_status}")
                
                # Show progress every interval
                if FileIndex % PROGRESS_INTERVAL == 0:
                    self.ShowEnhancedProgress(FileIndex, RemainingCount)
                
            except Exception as ProcessingError:
                print(f"   ❌ Critical error processing {PDFFile.name}: {ProcessingError}")
                self.ErrorCount += 1
                continue
        
        # Final progress
        self.ShowEnhancedProgress(RemainingCount, RemainingCount)
        self.GenerateEnhancedReport(TotalFiles, len(self.ProcessedFiles) + self.ProcessedCount)
        
        return True
    
    def AppendToCSV(self, BookData):
        """Append a single record to CSV file with enhanced fields"""
        file_exists = os.path.exists(self.OutputFile)
        
        # Enhanced CSV columns
        Columns = [
            'filename', 'file_size_mb', 'page_count',
            'database_category', 'database_subject',
            'pdf_title', 'pdf_author', 'pdf_subject', 'pdf_creator', 'pdf_producer',
            'pdf_creation_date', 'extracted_isbn', 'extracted_year', 
            'extracted_publisher', 'extracted_edition', 'extracted_doi',
            'first_page_text', 'title_page_text', 'copyright_page_text',
            'table_of_contents', 'full_text_sample', 'tables_content',
            'extraction_method', 'ocr_used', 'enhanced_extraction',
            'extraction_quality_score', 'errors'
        ]
        
        try:
            with open(self.OutputFile, 'a', newline='', encoding='utf-8') as CSVFile:
                Writer = csv.DictWriter(CSVFile, fieldnames=Columns)
                
                # Write header only if file is new
                if not file_exists:
                    Writer.writeheader()
                
                Writer.writerow(BookData)
                
        except Exception as SaveError:
            print(f"❌ Error appending to CSV: {SaveError}")
    
    def ShowEnhancedProgress(self, Current, Total):
        """Show enhanced processing progress with OCR statistics"""
        ProcessedPct = (Current / Total) * 100
        OCRPct = (self.OCRCount / Current * 100) if Current > 0 else 0
        EnhancedPct = (self.EnhancedExtractionCount / Current * 100) if Current > 0 else 0
        
        print(f"\n📊 PROGRESS REPORT: {Current}/{Total} ({ProcessedPct:.1f}%)")
        print(f"   ✅ Successfully processed: {self.ProcessedCount}")
        print(f"   🔍 OCR extractions: {self.OCRCount} ({OCRPct:.1f}%)")
        print(f"   ⚡ Enhanced extractions: {self.EnhancedExtractionCount} ({EnhancedPct:.1f}%)")
        print(f"   ❌ Errors: {self.ErrorCount}")
        print()
    
    def GenerateEnhancedReport(self, TotalInDirectory, TotalProcessed):
        """Generate enhanced final report with detailed statistics"""
        print("\n" + "=" * 80)
        print("📊 ENHANCED EXTRACTION COMPLETE!")
        print("=" * 80)
        print(f"📁 Total PDFs in directory: {TotalInDirectory}")
        print(f"✅ Total processed: {TotalProcessed}")
        print(f"🔍 OCR extractions performed: {self.OCRCount}")
        print(f"⚡ Enhanced extractions: {self.EnhancedExtractionCount}")
        print(f"❌ Total errors: {self.ErrorCount}")
        print(f"📈 Success rate: {((TotalProcessed - self.ErrorCount) / TotalInDirectory * 100):.1f}%")
        
        if self.OCRCount > 0:
            print(f"🔍 OCR usage rate: {(self.OCRCount / TotalProcessed * 100):.1f}%")
        
        if self.EnhancedExtractionCount > 0:
            print(f"⚡ Enhanced extraction rate: {(self.EnhancedExtractionCount / TotalProcessed * 100):.1f}%")
        
        print()
        
        if TotalProcessed == TotalInDirectory:
            print("🎉 ALL PDFs SUCCESSFULLY PROCESSED WITH ENHANCED EXTRACTION!")
            print("📊 Ready for database migration with maximum content!")
        else:
            missing = TotalInDirectory - TotalProcessed
            print(f"⚠️ {missing} PDFs still need processing")
            print("🔄 Run the script again to continue")
        
        print("=" * 80)

if __name__ == "__main__":
    print("🚀 ENHANCED PDF EXTRACTOR - MAXIMUM TEXT EXTRACTION")
    print("Features: OCR, Enhanced parsing, Extended text capture")
    print("Requirements check...")
    
    # Check dependencies
    required_packages = [
        'pytesseract', 'pdf2image', 'pdfplumber'
    ]
    
    missing_packages = []
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing_packages.append(package)

    # Special handling for opencv-python (imported as cv2) and pillow (imported as PIL)
    try:
        import cv2
    except ImportError:
        missing_packages.append('opencv-python')
    
    try:
        from PIL import Image
    except ImportError:
        missing_packages.append('pillow')
    
    if missing_packages:
        print(f"❌ Missing required packages: {', '.join(missing_packages)}")
        print(f"Install with: pip install {' '.join(missing_packages)}")
        exit(1)
    
    print("✅ All dependencies available")
    
    # Run enhanced extraction
    Extractor = EnhancedPDFExtractor(
        PDFDirectory=PDF_DIRECTORY,
        DatabasePath=DATABASE_PATH, 
        OutputFile=OUTPUT_CSV
    )
    
    Success = Extractor.ProcessRemainingPDFs()
    
    if Success:
        print(f"\n🎉 Enhanced extraction session complete!")
        print(f"📊 Results saved to: {OUTPUT_CSV}")
        print(f"🔄 Ready for enhanced database migration!")
    else:
        print(f"\n❌ Enhanced extraction failed!")
        exit(1)
