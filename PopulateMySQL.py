#!/usr/bin/env python3
"""
File: PopulateMySQL.py
Path: BowersWorld-com/Scripts/Migration/PopulateMySQL.py
Standard: AIDEV-PascalCase-1.8
Created: 2025-07-03
Author: Herb Bowers - Project Himalaya
Description: Migrate MyLibraryGPU.csv to MySQL Master Database

Purpose: Populates the MySQL master database from the enhanced Himalaya CSV
with proper normalization and error handling.
"""

import mysql.connector
import pandas as pd
import os
import hashlib
import re
from pathlib import Path
from datetime import datetime
import json
from typing import Dict, List, Optional, Tuple

class CSVToMySQLMigrator:
    """Migrates Anderson's Library CSV data to MySQL master database"""
    
    def __init__(self, csv_path: str, mysql_config: dict, books_directory: str):
        """Initialize migrator with paths and configuration"""
        self.csv_path = csv_path
        self.mysql_config = mysql_config
        self.books_directory = Path(books_directory)
        
        # Statistics tracking
        self.stats = {
            'total_records': 0,
            'books_migrated': 0,
            'authors_created': 0,
            'publishers_created': 0,
            'categories_created': 0,
            'errors_encountered': 0,
            'duplicates_skipped': 0
        }
        
        # Data caches to avoid duplicate database calls
        self.author_cache = {}
        self.publisher_cache = {}
        self.category_cache = {}
        
        print(f"🚀 Starting CSV to MySQL migration...")
        print(f"📁 CSV Path: {csv_path}")
        print(f"📚 Books Directory: {books_directory}")
    
    def connect_to_mysql(self) -> mysql.connector.MySQLConnection:
        """Create MySQL connection"""
        try:
            connection = mysql.connector.connect(**self.mysql_config)
            print(f"✅ Connected to MySQL database: {self.mysql_config['database']}")
            return connection
        except Exception as e:
            print(f"❌ Failed to connect to MySQL: {e}")
            raise
    
    def create_tables_if_not_exist(self, connection: mysql.connector.MySQLConnection):
        """Create tables if they don't exist"""
        cursor = connection.cursor()
        
        try:
            # Create Authors table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS Authors (
                    AuthorID INT AUTO_INCREMENT PRIMARY KEY,
                    AuthorName VARCHAR(500) NOT NULL,
                    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY unique_author (AuthorName)
                )
            """)
            
            # Create Publishers table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS Publishers (
                    PublisherID INT AUTO_INCREMENT PRIMARY KEY,
                    PublisherName VARCHAR(500) NOT NULL,
                    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY unique_publisher (PublisherName)
                )
            """)
            
            # Create Categories table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS Categories (
                    CategoryID INT AUTO_INCREMENT PRIMARY KEY,
                    CategoryName VARCHAR(200) NOT NULL,
                    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY unique_category (CategoryName)
                )
            """)
            
            # Create Books table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS Books (
                    BookID INT AUTO_INCREMENT PRIMARY KEY,
                    
                    -- File Information
                    FileName VARCHAR(500) NOT NULL,
                    FilePath VARCHAR(1000),
                    FileSize BIGINT,
                    FileSizeMB DECIMAL(10,2),
                    PageCount INT,
                    FileHash VARCHAR(64),
                    
                    -- Bibliographic Information
                    Title VARCHAR(1000),
                    Subtitle VARCHAR(1000),
                    AuthorID INT,
                    PublisherID INT,
                    CopyrightYear INT,
                    PublicationYear INT,
                    Edition VARCHAR(200),
                    Language VARCHAR(100) DEFAULT 'English',
                    CategoryID INT,
                    
                    -- Identifiers
                    PrimaryISBN VARCHAR(50),
                    ExtractedISBN VARCHAR(50),
                    ExtractedLCCN VARCHAR(50),
                    ExtractedISSN VARCHAR(50),
                    ExtractedOCLC VARCHAR(50),
                    ExtractedDOI VARCHAR(200),
                    ExtractedPublisher VARCHAR(500),
                    ExtractedYear INT,
                    
                    -- Content Text (truncated for storage)
                    FirstPageText TEXT,
                    TitlePageText TEXT,
                    CopyrightPageText TEXT,
                    ExtractedKeywords TEXT,
                    
                    -- Processing Information
                    ProcessingVersion VARCHAR(20),
                    ExtractionMethod VARCHAR(50),
                    QualityScore DECIMAL(5,2),
                    
                    -- Asset Flags
                    HasCover BOOLEAN DEFAULT FALSE,
                    HasThumbnail BOOLEAN DEFAULT FALSE,
                    
                    -- Access Control
                    AccessLevel VARCHAR(20) DEFAULT 'public',
                    
                    -- Timestamps
                    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
                    UpdatedDate DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    
                    -- Indexes
                    UNIQUE KEY unique_filename (FileName),
                    KEY idx_author (AuthorID),
                    KEY idx_publisher (PublisherID),
                    KEY idx_category (CategoryID),
                    KEY idx_title (Title(100)),
                    KEY idx_isbn (PrimaryISBN),
                    
                    -- Foreign Keys
                    FOREIGN KEY (AuthorID) REFERENCES Authors(AuthorID) ON DELETE SET NULL,
                    FOREIGN KEY (PublisherID) REFERENCES Publishers(PublisherID) ON DELETE SET NULL,
                    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID) ON DELETE SET NULL
                )
            """)
            
            connection.commit()
            print("✅ Database tables created/verified successfully")
            
        except Exception as e:
            print(f"❌ Error creating tables: {e}")
            raise
        finally:
            cursor.close()
    
    def load_csv_data(self) -> pd.DataFrame:
        """Load and validate CSV data"""
        try:
            df = pd.read_csv(self.csv_path).fillna('')
            self.stats['total_records'] = len(df)
            print(f"✅ Loaded {len(df)} records from CSV")
            
            # Show column names for verification
            print("📋 Available columns:")
            for i, col in enumerate(df.columns, 1):
                print(f"   {i:2d}. {col}")
            
            return df
        except Exception as e:
            print(f"❌ Failed to load CSV: {e}")
            raise
    
    def normalize_text(self, text: str) -> str:
        """Normalize text for consistent comparison"""
        if not text or pd.isna(text):
            return ""
        return str(text).strip().replace('  ', ' ')
    
    def extract_year_from_text(self, text: str) -> Optional[int]:
        """Extract year from various text formats"""
        if not text:
            return None
        
        # Look for 4-digit years
        year_match = re.search(r'\b(19|20)\d{2}\b', str(text))
        if year_match:
            year = int(year_match.group())
            if 1800 <= year <= 2030:  # Reasonable range
                return year
        return None
    
    def calculate_file_hash(self, file_path: Path) -> Optional[str]:
        """Calculate SHA-256 hash of file if it exists"""
        if not file_path.exists():
            return None
        
        try:
            sha256_hash = hashlib.sha256()
            with open(file_path, "rb") as f:
                for byte_block in iter(lambda: f.read(4096), b""):
                    sha256_hash.update(byte_block)
            return sha256_hash.hexdigest()
        except Exception as e:
            print(f"⚠️ Could not hash file {file_path}: {e}")
            return None
    
    def get_or_create_author(self, connection: mysql.connector.MySQLConnection, 
                           author_name: str) -> Optional[int]:
        """Get existing author or create new one"""
        if not author_name:
            return None
        
        author_name = self.normalize_text(author_name)
        if not author_name:
            return None
        
        # Check cache first
        if author_name in self.author_cache:
            return self.author_cache[author_name]
        
        cursor = connection.cursor()
        try:
            # Try to find existing author
            cursor.execute("SELECT AuthorID FROM Authors WHERE AuthorName = %s", (author_name,))
            result = cursor.fetchone()
            
            if result:
                author_id = result[0]
            else:
                # Create new author
                cursor.execute("INSERT INTO Authors (AuthorName) VALUES (%s)", (author_name,))
                author_id = cursor.lastrowid
                self.stats['authors_created'] += 1
            
            # Cache the result
            self.author_cache[author_name] = author_id
            return author_id
            
        except Exception as e:
            print(f"⚠️ Error handling author '{author_name}': {e}")
            return None
        finally:
            cursor.close()
    
    def get_or_create_publisher(self, connection: mysql.connector.MySQLConnection, 
                              publisher_name: str) -> Optional[int]:
        """Get existing publisher or create new one"""
        if not publisher_name:
            return None
        
        publisher_name = self.normalize_text(publisher_name)
        if not publisher_name:
            return None
        
        # Check cache first
        if publisher_name in self.publisher_cache:
            return self.publisher_cache[publisher_name]
        
        cursor = connection.cursor()
        try:
            # Try to find existing publisher
            cursor.execute("SELECT PublisherID FROM Publishers WHERE PublisherName = %s", (publisher_name,))
            result = cursor.fetchone()
            
            if result:
                publisher_id = result[0]
            else:
                # Create new publisher
                cursor.execute("INSERT INTO Publishers (PublisherName) VALUES (%s)", (publisher_name,))
                publisher_id = cursor.lastrowid
                self.stats['publishers_created'] += 1
            
            # Cache the result
            self.publisher_cache[publisher_name] = publisher_id
            return publisher_id
            
        except Exception as e:
            print(f"⚠️ Error handling publisher '{publisher_name}': {e}")
            return None
        finally:
            cursor.close()
    
    def get_or_create_category(self, connection: mysql.connector.MySQLConnection, 
                             category_name: str) -> Optional[int]:
        """Get existing category or create new one"""
        if not category_name or category_name.lower() in ['unknown', 'not found', '']:
            return None
        
        category_name = self.normalize_text(category_name)
        if not category_name:
            return None
        
        # Check cache first
        if category_name in self.category_cache:
            return self.category_cache[category_name]
        
        cursor = connection.cursor()
        try:
            # Try to find existing category
            cursor.execute("SELECT CategoryID FROM Categories WHERE CategoryName = %s", (category_name,))
            result = cursor.fetchone()
            
            if result:
                category_id = result[0]
            else:
                # Create new category
                cursor.execute("INSERT INTO Categories (CategoryName) VALUES (%s)", (category_name,))
                category_id = cursor.lastrowid
                self.stats['categories_created'] += 1
            
            # Cache the result
            self.category_cache[category_name] = category_id
            return category_id
            
        except Exception as e:
            print(f"⚠️ Error handling category '{category_name}': {e}")
            return None
        finally:
            cursor.close()
    
    def check_assets_exist(self, filename: str) -> Dict[str, bool]:
        """Check if cover and thumbnail files exist in Data directory"""
        base_name = Path(filename).stem
        
        # First try exact match
        cover_path = Path("Data/Covers") / f"{base_name}.png"
        thumb_path = Path("Data/Thumbs") / f"{base_name}.png"
        
        has_cover = cover_path.exists()
        has_thumbnail = thumb_path.exists()
        
        # If exact match fails, try with original spacing from filesystem
        if not has_cover or not has_thumbnail:
            cover_dir = Path("Data/Covers")
            thumb_dir = Path("Data/Thumbs")
            
            # Look for files that match when spaces are normalized
            normalized_base = self.normalize_spaces(base_name)
            
            if not has_cover and cover_dir.exists():
                for cover_file in cover_dir.glob("*.png"):
                    if self.normalize_spaces(cover_file.stem) == normalized_base:
                        has_cover = True
                        break
            
            if not has_thumbnail and thumb_dir.exists():
                for thumb_file in thumb_dir.glob("*.png"):
                    if self.normalize_spaces(thumb_file.stem) == normalized_base:
                        has_thumbnail = True
                        break
        
        return {
            'has_cover': has_cover,
            'has_thumbnail': has_thumbnail
        }
    
    def normalize_spaces(self, text: str) -> str:
        """Normalize multiple spaces to single spaces for comparison"""
        import re
        return re.sub(r'\s+', ' ', text.strip())
    
    def migrate_book_record(self, connection: mysql.connector.MySQLConnection, 
                          row: pd.Series) -> bool:
        """Migrate a single book record"""
        try:
            # Get normalized data
            filename = self.normalize_text(row.get('filename', ''))
            if not filename:
                print("⚠️ Skipping record with no filename")
                return False
            
            # Check if book already exists
            cursor = connection.cursor()
            cursor.execute("SELECT BookID FROM Books WHERE FileName = %s", (filename,))
            if cursor.fetchone():
                self.stats['duplicates_skipped'] += 1
                cursor.close()
                return True  # Not an error, just already exists
            cursor.close()
            
            # Get file information
            book_file_path = self.books_directory / filename
            file_size = book_file_path.stat().st_size if book_file_path.exists() else None
            file_hash = self.calculate_file_hash(book_file_path)
            
            # Get normalized entities
            author_id = self.get_or_create_author(connection, row.get('pdf_author', ''))
            publisher_id = self.get_or_create_publisher(connection, row.get('pdf_producer', '') or row.get('extracted_publisher', ''))
            category_id = self.get_or_create_category(connection, row.get('database_category', ''))
            
            # Extract years
            copyright_year = self.extract_year_from_text(row.get('pdf_creation_date', ''))
            publication_year = int(row.get('extracted_year', 0)) if row.get('extracted_year') else copyright_year
            
            # Check for assets
            assets = self.check_assets_exist(filename)
            
            # Prepare book data
            book_data = {
                'FileName': filename,
                'FilePath': str(book_file_path) if book_file_path.exists() else None,
                'FileSize': file_size,
                'FileSizeMB': float(row.get('file_size_mb', 0)) if row.get('file_size_mb') else None,
                'PageCount': int(row.get('page_count', 0)) if row.get('page_count') else None,
                'FileHash': file_hash,
                
                # Bibliographic data
                'Title': self.normalize_text(row.get('pdf_title', '') or filename.replace('.pdf', '')),
                'Subtitle': None,  # Not in CSV
                'AuthorID': author_id,
                'PublisherID': publisher_id,
                'CopyrightYear': copyright_year,
                'PublicationYear': publication_year,
                'Edition': self.normalize_text(row.get('extracted_edition', '')),
                'Language': 'English',  # Default for now
                'CategoryID': category_id,
                
                # Identifiers
                'PrimaryISBN': self.normalize_text(row.get('extracted_isbn', '')),
                'ExtractedISBN': self.normalize_text(row.get('extracted_isbn', '')),
                'ExtractedLCCN': self.normalize_text(row.get('extracted_lccn', '')),
                'ExtractedISSN': self.normalize_text(row.get('extracted_issn', '')),
                'ExtractedOCLC': self.normalize_text(row.get('extracted_oclc', '')),
                'ExtractedDOI': self.normalize_text(row.get('extracted_doi', '')),
                'ExtractedPublisher': self.normalize_text(row.get('extracted_publisher', '')),
                'ExtractedYear': int(row.get('extracted_year', 0)) if row.get('extracted_year') else None,
                
                # Content
                'FirstPageText': str(row.get('first_page_text', ''))[:10000] if row.get('first_page_text') else None,
                'TitlePageText': str(row.get('title_page_text', ''))[:10000] if row.get('title_page_text') else None,
                'CopyrightPageText': str(row.get('copyright_page_text', ''))[:10000] if row.get('copyright_page_text') else None,
                'ExtractedKeywords': self.normalize_text(row.get('extracted_keywords', '')),
                
                # Processing info
                'ProcessingVersion': '1.0',
                'ExtractionMethod': 'himalaya_gpu',
                'QualityScore': 75.0,  # Default reasonable score
                
                # Assets
                'HasCover': assets['has_cover'],
                'HasThumbnail': assets['has_thumbnail'],
                
                # Access
                'AccessLevel': 'public'
            }
            
            # Build INSERT statement
            columns = []
            values = []
            placeholders = []
            
            for key, value in book_data.items():
                if value is not None and value != '':
                    columns.append(key)
                    values.append(value)
                    placeholders.append('%s')
            
            insert_sql = f"""
                INSERT INTO Books ({', '.join(columns)})
                VALUES ({', '.join(placeholders)})
            """
            
            # Execute insert
            cursor = connection.cursor()
            cursor.execute(insert_sql, values)
            book_id = cursor.lastrowid
            cursor.close()
            
            connection.commit()
            self.stats['books_migrated'] += 1
            
            return True
            
        except Exception as e:
            print(f"❌ Error migrating book '{filename}': {e}")
            self.stats['errors_encountered'] += 1
            connection.rollback()
            return False
    
    def execute_migration(self) -> bool:
        """Execute the complete migration process"""
        try:
            # Load CSV data
            df = self.load_csv_data()
            
            # Connect to MySQL
            connection = self.connect_to_mysql()
            
            # Create tables if they don't exist
            self.create_tables_if_not_exist(connection)
            
            print(f"\n🚀 Starting migration of {len(df)} books...")
            
            # Process each book record
            for index, row in df.iterrows():
                if index % 50 == 0:  # Progress report every 50 books
                    print(f"📊 Progress: {index}/{len(df)} ({(index/len(df)*100):.1f}%)")
                
                self.migrate_book_record(connection, row)
            
            # Final progress report
            print(f"📊 Progress: {len(df)}/{len(df)} (100.0%)")
            
            # Close connection
            connection.close()
            
            # Generate final report
            self.generate_migration_report()
            
            return True
            
        except Exception as e:
            print(f"❌ Migration failed: {e}")
            return False
    
    def generate_migration_report(self):
        """Generate comprehensive migration report"""
        print("\n" + "="*60)
        print("📊 MIGRATION REPORT")
        print("="*60)
        print(f"📁 Source CSV: {self.csv_path}")
        print(f"🗄️ Target Database: {self.mysql_config['database']}")
        print(f"📅 Migration Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        print("📈 STATISTICS:")
        print(f"   📚 Total records in CSV: {self.stats['total_records']}")
        print(f"   ✅ Books successfully migrated: {self.stats['books_migrated']}")
        print(f"   👥 Authors created: {self.stats['authors_created']}")
        print(f"   🏢 Publishers created: {self.stats['publishers_created']}")
        print(f"   📂 Categories created: {self.stats['categories_created']}")
        print(f"   🔄 Duplicates skipped: {self.stats['duplicates_skipped']}")
        print(f"   ❌ Errors encountered: {self.stats['errors_encountered']}")
        print()
        
        success_rate = (self.stats['books_migrated'] / self.stats['total_records']) * 100
        print(f"✅ Success Rate: {success_rate:.1f}%")
        
        if self.stats['errors_encountered'] == 0:
            print("\n🎉 MIGRATION COMPLETED SUCCESSFULLY!")
            print("🔍 All books have been indexed for full-text search")
            print("📊 Database is ready for SQLite generation")
        else:
            print(f"\n⚠️ Migration completed with {self.stats['errors_encountered']} errors")
            print("📝 Check the output above for error details")
        
        print("="*60)

def main():
    """Main execution function"""
    
    # Configuration
    CSV_PATH = "MyLibraryGPU.csv"
    BOOKS_DIRECTORY = "Data/Books"  # Updated to correct Data directory structure
    
    # MySQL configuration - update with your settings
    MYSQL_CONFIG = {
        'host': 'localhost',        # Host without port
        'port': 3306,              # Port as separate parameter
        'user': 'workbench',       # Update this
        'password': 'Workbench123!',  # Update this
        'database': 'MyLibrary_Master',
        'charset': 'utf8mb4',
        'autocommit': False
    }
    
    print("🏔️ HIMALAYA CSV TO MYSQL MIGRATION")
    print("Standard: AIDEV-PascalCase-1.8")
    print("Enhanced with full bibliographic data extraction")
    print("="*60)
    
    # Validate input files exist
    if not os.path.exists(CSV_PATH):
        print(f"❌ CSV file not found: {CSV_PATH}")
        print("📁 Please ensure the MyLibraryGPU.csv file is in the current directory")
        return False
    
    if not os.path.exists(BOOKS_DIRECTORY):
        print(f"⚠️ Books directory not found: {BOOKS_DIRECTORY}")
        print("📁 Migration will continue but file paths may not be accurate")
        print("💡 Expected structure: Data/Books/ (symlink or directory)")
        print("💡 Also checking: Data/Covers/ and Data/Thumbs/ for assets")
    
    # Create migrator and execute
    migrator = CSVToMySQLMigrator(CSV_PATH, MYSQL_CONFIG, BOOKS_DIRECTORY)
    success = migrator.execute_migration()
    
    if success:
        print("\n🚀 NEXT STEPS:")
        print("1. Verify data in MySQL: SELECT COUNT(*) FROM Books;")
        print("2. Test search functionality: SELECT * FROM Books LIMIT 5;")
        print("3. Generate SQLite databases for users")
        print("4. Set up web interface")
        
        return True
    else:
        print("\n❌ Migration failed - check error messages above")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)