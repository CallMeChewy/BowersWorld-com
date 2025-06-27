#!/usr/bin/env python3
"""
Resumable PDF Metadata Extractor - Continue where previous extraction left off
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

# Configuration
PDF_DIRECTORY = "/home/herb/Desktop/Not Backed Up/Anderson's Library/Andy/Anderson eBooks"
DATABASE_PATH = "/home/herb/Desktop/BowersWorld-com/Assets/my_library.db"
OUTPUT_CSV = "/home/herb/Desktop/BowersWorld-com/AndersonLibrary_PDFMetadata.csv"
PROGRESS_INTERVAL = 25

# Text extraction patterns
ISBN_PATTERN = re.compile(r'ISBN[:\-\s]*([0-9\-X]{10,17})', re.IGNORECASE)
YEAR_PATTERN = re.compile(r'(19|20)\d{2}')
PUBLISHER_PATTERN = re.compile(r'Published by[:\s]*([^.\n\r]{5,50})', re.IGNORECASE)
COPYRIGHT_PATTERN = re.compile(r'Copyright[:\s]*©?\s*(\d{4})', re.IGNORECASE)
EDITION_PATTERN = re.compile(r'(\d+)(st|nd|rd|th)\s+edition', re.IGNORECASE)

class ResumablePDFExtractor:
    def __init__(self, PDFDirectory, DatabasePath, OutputFile):
        self.PDFDirectory = Path(PDFDirectory)
        self.DatabasePath = DatabasePath
        self.OutputFile = OutputFile
        self.ProcessedCount = 0
        self.ErrorCount = 0
        self.SkippedCount = 0
        self.ExtractedData = []
        
        # Load existing data if available
        self.LoadExistingData()
        self.LoadDatabaseInfo()
    
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
    
    def ExtractPDFMetadata(self, PDFPath):
        """Extract metadata from a single PDF file with improved error handling"""
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
            'first_page_text': '',
            'title_page_text': '',
            'copyright_page_text': '',
            'database_category': 'Not Found',
            'database_subject': 'Not Found',
            'extraction_method': 'None',
            'errors': ''
        }
        
        # Get database info for this book
        BookTitle = PDFPath.stem
        if BookTitle in self.DatabaseBooks:
            Metadata['database_category'] = self.DatabaseBooks[BookTitle]['category']
            Metadata['database_subject'] = self.DatabaseBooks[BookTitle]['subject']
        
        ErrorMessages = []
        
        # Try PyMuPDF first
        try:
            PDFDocument = fitz.open(str(PDFPath))
            Metadata['page_count'] = len(PDFDocument)
            Metadata['extraction_method'] = 'PyMuPDF'
            
            # Extract PDF metadata with safe string conversion
            PDFMetadata = PDFDocument.metadata
            Metadata['pdf_title'] = str(PDFMetadata.get('title', '')).strip()
            Metadata['pdf_author'] = str(PDFMetadata.get('author', '')).strip()
            Metadata['pdf_subject'] = str(PDFMetadata.get('subject', '')).strip()
            Metadata['pdf_creator'] = str(PDFMetadata.get('creator', '')).strip()
            Metadata['pdf_producer'] = str(PDFMetadata.get('producer', '')).strip()
            
            if PDFMetadata.get('creationDate'):
                Metadata['pdf_creation_date'] = str(PDFMetadata['creationDate'])[:10]
            
            # Extract text from key pages with size limits
            if len(PDFDocument) > 0:
                try:
                    FirstPage = PDFDocument[0]
                    Metadata['first_page_text'] = FirstPage.get_text()[:1000]
                except:
                    pass
                
                if len(PDFDocument) > 1:
                    try:
                        TitlePage = PDFDocument[1]
                        Metadata['title_page_text'] = TitlePage.get_text()[:1000]
                    except:
                        pass
                
                # Look for copyright page
                for PageNum in range(min(4, len(PDFDocument))):
                    try:
                        PageText = PDFDocument[PageNum].get_text()
                        if 'copyright' in PageText.lower() or '©' in PageText:
                            Metadata['copyright_page_text'] = PageText[:1000]
                            break
                    except:
                        continue
            
            PDFDocument.close()
            
        except Exception as PyMuPDFError:
            ErrorMessages.append(f"PyMuPDF: {str(PyMuPDFError)[:100]}")
            
            # Fallback to PyPDF2
            try:
                with open(PDFPath, 'rb') as PDFFile:
                    PDFReader = PyPDF2.PdfReader(PDFFile)
                    Metadata['page_count'] = len(PDFReader.pages)
                    Metadata['extraction_method'] = 'PyPDF2'
                    
                    if PDFReader.metadata:
                        Metadata['pdf_title'] = str(PDFReader.metadata.get('/Title', '')).strip()
                        Metadata['pdf_author'] = str(PDFReader.metadata.get('/Author', '')).strip()
                        Metadata['pdf_subject'] = str(PDFReader.metadata.get('/Subject', '')).strip()
                        Metadata['pdf_creator'] = str(PDFReader.metadata.get('/Creator', '')).strip()
                        Metadata['pdf_producer'] = str(PDFReader.metadata.get('/Producer', '')).strip()
                        
                        CreationDate = PDFReader.metadata.get('/CreationDate')
                        if CreationDate:
                            Metadata['pdf_creation_date'] = str(CreationDate)[:10]
                    
                    # Extract text from first few pages
                    if len(PDFReader.pages) > 0:
                        try:
                            Metadata['first_page_text'] = PDFReader.pages[0].extract_text()[:1000]
                        except:
                            pass
                        
                        if len(PDFReader.pages) > 1:
                            try:
                                Metadata['title_page_text'] = PDFReader.pages[1].extract_text()[:1000]
                            except:
                                pass
                        
                        # Look for copyright page
                        for PageNum in range(min(4, len(PDFReader.pages))):
                            try:
                                PageText = PDFReader.pages[PageNum].extract_text()
                                if 'copyright' in PageText.lower() or '©' in PageText:
                                    Metadata['copyright_page_text'] = PageText[:1000]
                                    break
                            except:
                                continue
                
            except Exception as PyPDF2Error:
                ErrorMessages.append(f"PyPDF2: {str(PyPDF2Error)[:100]}")
                Metadata['extraction_method'] = 'Failed'
        
        # Extract specific information from text
        AllText = ' '.join(filter(None, [
            Metadata.get('first_page_text', ''),
            Metadata.get('title_page_text', ''),
            Metadata.get('copyright_page_text', '')
        ]))
        
        if AllText:
            # Extract ISBN
            ISBNMatch = ISBN_PATTERN.search(AllText)
            if ISBNMatch:
                Metadata['extracted_isbn'] = ISBNMatch.group(1).replace('-', '').replace(' ', '')
            
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
        
        # Store errors as string
        Metadata['errors'] = '; '.join(ErrorMessages) if ErrorMessages else ''
        
        return Metadata
    
    def ProcessRemainingPDFs(self):
        """Process only PDFs that haven't been processed yet"""
        print(f"📚 Resumable PDF Metadata Extractor")
        print("=" * 60)
        print(f"📂 PDF Directory: {self.PDFDirectory}")
        print(f"📊 Output CSV: {self.OutputFile}")
        print("=" * 60)
        
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
        
        print(f"🔄 Starting extraction of remaining {RemainingCount} files...\n")
        
        # Process remaining PDFs
        for FileIndex, PDFFile in enumerate(UnprocessedFiles, 1):
            try:
                print(f"[{FileIndex:4d}/{RemainingCount}] Processing: {PDFFile.name}")
                
                ExtractedMetadata = self.ExtractPDFMetadata(PDFFile)
                self.AppendToCSV(ExtractedMetadata)
                self.ProcessedCount += 1
                
                # Show progress
                if FileIndex % PROGRESS_INTERVAL == 0:
                    self.ShowProgress(FileIndex, RemainingCount)
                
            except Exception as ProcessingError:
                print(f"   ❌ Critical error processing {PDFFile.name}: {ProcessingError}")
                self.ErrorCount += 1
                # Continue processing other files
                continue
        
        # Final progress
        self.ShowProgress(RemainingCount, RemainingCount)
        self.GenerateReport(TotalFiles, len(self.ProcessedFiles) + self.ProcessedCount)
        
        return True
    
    def AppendToCSV(self, BookData):
        """Append a single record to CSV file"""
        file_exists = os.path.exists(self.OutputFile)
        
        # Define CSV columns
        Columns = [
            'filename', 'file_size_mb', 'page_count',
            'database_category', 'database_subject',
            'pdf_title', 'pdf_author', 'pdf_subject', 'pdf_creator', 'pdf_producer',
            'pdf_creation_date', 'extracted_isbn', 'extracted_year', 
            'extracted_publisher', 'extracted_edition',
            'first_page_text', 'title_page_text', 'copyright_page_text',
            'extraction_method', 'errors'
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
    
    def ShowProgress(self, Current, Total):
        """Show processing progress"""
        ProcessedPct = (Current / Total) * 100
        
        print(f"\n📊 Progress: {Current}/{Total} ({ProcessedPct:.1f}%)")
        print(f"   ✅ Successfully processed: {self.ProcessedCount}")
        print(f"   ❌ Errors: {self.ErrorCount}")
        print()
    
    def GenerateReport(self, TotalInDirectory, TotalProcessed):
        """Generate final report"""
        print("\n" + "=" * 60)
        print("📊 RESUMABLE EXTRACTION COMPLETE!")
        print("=" * 60)
        print(f"📁 Total PDFs in directory: {TotalInDirectory}")
        print(f"✅ Total processed: {TotalProcessed}")
        print(f"❌ Total errors: {self.ErrorCount}")
        print(f"📈 Success rate: {((TotalProcessed - self.ErrorCount) / TotalInDirectory * 100):.1f}%")
        print()
        
        if TotalProcessed == TotalInDirectory:
            print("🎉 ALL PDFs SUCCESSFULLY PROCESSED!")
            print("📊 Ready for Library of Congress data enhancement!")
        else:
            missing = TotalInDirectory - TotalProcessed
            print(f"⚠️ {missing} PDFs still need processing")
            print("🔄 Run the script again to continue")
        
        print("=" * 60)

if __name__ == "__main__":
    # Run resumable extraction
    Extractor = ResumablePDFExtractor(
        PDFDirectory=PDF_DIRECTORY,
        DatabasePath=DATABASE_PATH, 
        OutputFile=OUTPUT_CSV
    )
    
    Success = Extractor.ProcessRemainingPDFs()
    
    if Success:
        print(f"\n🎉 Extraction session complete!")
        print(f"📊 Results appended to: {OUTPUT_CSV}")
    else:
        print(f"\n❌ Extraction failed!")
        exit(1)