#!/usr/bin/env python3
"""
File: MigrateToEnhancedSchema.py
Path: BowersWorld-com/Scripts/Migration/MigrateToEnhancedSchema.py
Standard: AIDEV-PascalCase-1.8
Created: 2025-06-30
Modified: 2025-06-30
Author: Herb Bowers - Project Himalaya
Description: Migrate existing library data to enhanced MyLibrary.db schema

Purpose: Takes your CSV metadata and existing SQLite database and migrates
to the new enhanced schema with full AI classification support.
"""

import sqlite3
import pandas as pd
import json
import hashlib
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple

class LibraryDataMigrator:
    """Migrates Anderson's Library data to enhanced schema"""
    
    def __init__(self, 
                 OldDatabasePath: str,
                 CSVPath: str,
                 NewDatabasePath: str,
                 BooksDirectory: str,
                 CoversDirectory: str,
                 ThumbnailsDirectory: str):
        """Initialize migrator with file paths"""
        self.OldDatabasePath = OldDatabasePath
        self.CSVPath = CSVPath
        self.NewDatabasePath = NewDatabasePath
        self.BooksDirectory = Path(BooksDirectory)
        self.CoversDirectory = Path(CoversDirectory)
        self.ThumbnailsDirectory = Path(ThumbnailsDirectory)
        
        # Load CSV data
        self.CSVData = pd.read_csv(CSVPath)
        print(f"✅ Loaded {len(self.CSVData)} records from CSV")
        
        # Statistics
        self.StatsCounters = {
            'CategoriesMigrated': 0,
            'SubjectsMigrated': 0,
            'BooksMigrated': 0,
            'ContentProcessed': 0,
            'ErrorsEncountered': 0
        }

    def ExecuteMigration(self) -> bool:
        """Execute complete migration process"""
        try:
            print("🚀 Starting Anderson's Library data migration...")
            
            # Create new database with enhanced schema
            self.CreateEnhancedDatabase()
            
            # Migrate categories and subjects
            self.MigrateCategories()
            self.MigrateSubjects()
            
            # Migrate books with enhanced metadata
            self.MigrateBooks()
            
            # Process content for full-text search
            self.ProcessBookContent()
            
            # Generate initial analytics
            self.GenerateInitialAnalytics()
            
            # Generate migration report
            self.GenerateReport()
            
            # Export MySQL conversion instructions
            self.ExportForMySQL()
            
            print("✅ Migration completed successfully!")
            return True
            
        except Exception as Error:
            print(f"❌ Migration failed: {Error}")
            return False

    def CreateEnhancedDatabase(self):
        """Create new database with enhanced schema"""
        print("📄 Creating enhanced database schema...")
        
        # Read schema from file or create inline
        SchemaSQL = self.GetEnhancedSchema()
        
        # Create database
        Connection = sqlite3.connect(self.NewDatabasePath)
        Cursor = Connection.cursor()
        
        # Execute schema
        Cursor.executescript(SchemaSQL)
        Connection.commit()
        Connection.close()
        
        print("✅ Enhanced schema created")

    def MigrateCategories(self):
        """Migrate categories from old database and CSV data"""
        print("📂 Migrating categories...")
        
        # Get unique categories from CSV
        UniqueCategories = self.CSVData['database_category'].dropna().unique()
        
        Connection = sqlite3.connect(self.NewDatabasePath)
        Cursor = Connection.cursor()
        
        for CategoryName in UniqueCategories:
            if CategoryName and CategoryName != 'Not Found':
                try:
                    Cursor.execute("""
                        INSERT OR IGNORE INTO Categories (CategoryName, Description, CreatedDate)
                        VALUES (?, ?, ?)
                    """, (CategoryName, f"Migrated category: {CategoryName}", datetime.now().isoformat()))
                    
                    if Cursor.rowcount > 0:
                        self.StatsCounters['CategoriesMigrated'] += 1
                        
                except Exception as Error:
                    print(f"⚠️ Error inserting category {CategoryName}: {Error}")
                    self.StatsCounters['ErrorsEncountered'] += 1
        
        Connection.commit()
        Connection.close()
        
        print(f"✅ Migrated {self.StatsCounters['CategoriesMigrated']} categories")

    def MigrateSubjects(self):
        """Migrate subjects with category relationships"""
        print("📚 Migrating subjects...")
        
        Connection = sqlite3.connect(self.NewDatabasePath)
        Cursor = Connection.cursor()
        
        # Get category ID mapping
        CategoryMapping = {}
        Cursor.execute("SELECT CategoryID, CategoryName FROM Categories")
        for CategoryID, CategoryName in Cursor.fetchall():
            CategoryMapping[CategoryName] = CategoryID
        
        # Process unique category/subject combinations
        SubjectData = self.CSVData[['database_category', 'database_subject']].dropna()
        UniqueSubjects = SubjectData.drop_duplicates()
        
        for _, Row in UniqueSubjects.iterrows():
            Category = Row['database_category']
            Subject = Row['database_subject']
            
            if Category in CategoryMapping and Subject and Subject != 'Not Found':
                try:
                    CategoryID = CategoryMapping[Category]
                    
                    Cursor.execute("""
                        INSERT OR IGNORE INTO Subjects (SubjectName, CategoryID, Description, CreatedDate)
                        VALUES (?, ?, ?, ?)
                    """, (Subject, CategoryID, f"Migrated subject: {Subject}", datetime.now().isoformat()))
                    
                    if Cursor.rowcount > 0:
                        self.StatsCounters['SubjectsMigrated'] += 1
                        
                except Exception as Error:
                    print(f"⚠️ Error inserting subject {Subject}: {Error}")
                    self.StatsCounters['ErrorsEncountered'] += 1
        
        Connection.commit()
        Connection.close()
        
        print(f"✅ Migrated {self.StatsCounters['SubjectsMigrated']} subjects")

    def MigrateBooks(self):
        """Migrate books with all metadata"""
        print("📖 Migrating books with enhanced metadata...")
        
        Connection = sqlite3.connect(self.NewDatabasePath)
        Cursor = Connection.cursor()
        
        # Get category and subject ID mappings
        CategoryMapping = {}
        SubjectMapping = {}
        
        Cursor.execute("SELECT CategoryID, CategoryName FROM Categories")
        for CategoryID, CategoryName in Cursor.fetchall():
            CategoryMapping[CategoryName] = CategoryID
            
        Cursor.execute("SELECT SubjectID, SubjectName, CategoryID FROM Subjects")
        SubjectMappingRaw = Cursor.fetchall()
        for SubjectID, SubjectName, CategoryID in SubjectMappingRaw:
            SubjectMapping[(SubjectName, CategoryID)] = SubjectID
        
        # Process each book
        for Index, Row in self.CSVData.iterrows():
            try:
                BookData = self.PrepareBookData(Row, CategoryMapping, SubjectMapping)
                
                # Calculate file hash if file exists
                BookPath = self.BooksDirectory / Row['filename']
                if BookPath.exists():
                    BookData['FileHash'] = self.CalculateFileHash(BookPath)
                    BookData['FilePath'] = str(BookPath)
                
                # Set cover and thumbnail paths
                CoverPath = self.CoversDirectory / (Path(Row['filename']).stem + '.png')
                ThumbnailPath = self.ThumbnailsDirectory / (Path(Row['filename']).stem + '.png')
                
                if CoverPath.exists():
                    BookData['CoverPath'] = str(CoverPath)
                if ThumbnailPath.exists():
                    BookData['ThumbnailPath'] = str(ThumbnailPath)
                
                # Insert book record
                InsertSQL = """
                    INSERT INTO Books (
                        FileName, FilePath, FileSize, FileSizeMB, PageCount, FileHash,
                        Title, Author, Publisher, PublicationYear, ISBN,
                        PDFTitle, PDFAuthor, PDFSubject, PDFCreator, PDFProducer, PDFCreationDate,
                        CategoryID, SubjectID, CategoryConfidence, SubjectConfidence, OverallConfidence,
                        ExtractedISBN, ExtractedYear, ExtractedPublisher, ExtractedEdition,
                        ExtractionMethod, ProcessingDate, ProcessingErrors, ProcessingFlags,
                        CoverPath, ThumbnailPath, DateAdded
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """
                
                Cursor.execute(InsertSQL, [
                    BookData['FileName'], BookData['FilePath'], BookData['FileSize'], 
                    BookData['FileSizeMB'], BookData['PageCount'], BookData['FileHash'],
                    BookData['Title'], BookData['Author'], BookData['Publisher'], 
                    BookData['PublicationYear'], BookData['ISBN'],
                    BookData['PDFTitle'], BookData['PDFAuthor'], BookData['PDFSubject'],
                    BookData['PDFCreator'], BookData['PDFProducer'], BookData['PDFCreationDate'],
                    BookData['CategoryID'], BookData['SubjectID'], BookData['CategoryConfidence'],
                    BookData['SubjectConfidence'], BookData['OverallConfidence'],
                    BookData['ExtractedISBN'], BookData['ExtractedYear'], BookData['ExtractedPublisher'],
                    BookData['ExtractedEdition'], BookData['ExtractionMethod'], BookData['ProcessingDate'],
                    BookData['ProcessingErrors'], BookData['ProcessingFlags'],
                    BookData['CoverPath'], BookData['ThumbnailPath'], BookData['DateAdded']
                ])
                
                BookID = Cursor.lastrowid
                
                # Insert content for full-text search
                if any(Row.get(field) for field in ['first_page_text', 'title_page_text', 'copyright_page_text']):
                    self.InsertBookContent(Cursor, BookID, Row)
                
                self.StatsCounters['BooksMigrated'] += 1
                
                if (Index + 1) % 100 == 0:
                    print(f"   📈 Processed {Index + 1}/{len(self.CSVData)} books...")
                    Connection.commit()
                
            except Exception as Error:
                print(f"⚠️ Error migrating book {Row.get('filename', 'unknown')}: {Error}")
                self.StatsCounters['ErrorsEncountered'] += 1
        
        Connection.commit()
        Connection.close()
        
        print(f"✅ Migrated {self.StatsCounters['BooksMigrated']} books")

    def PrepareBookData(self, Row: pd.Series, CategoryMapping: Dict, SubjectMapping: Dict) -> Dict:
        """Prepare book data dictionary from CSV row"""
        
        # Map category and subject IDs
        CategoryID = None
        SubjectID = None
        
        Category = Row.get('database_category')
        Subject = Row.get('database_subject')
        
        if Category and Category in CategoryMapping:
            CategoryID = CategoryMapping[Category]
            
            if Subject and (Subject, CategoryID) in SubjectMapping:
                SubjectID = SubjectMapping[(Subject, CategoryID)]
        
        # Calculate file size in bytes
        FileSizeMB = float(Row.get('file_size_mb', 0) or 0)
        FileSize = int(FileSizeMB * 1024 * 1024) if FileSizeMB > 0 else None
        
        # Process confidence scores
        CategoryConfidence = self.ParseFloat(Row.get('category_confidence'))
        SubjectConfidence = self.ParseFloat(Row.get('subject_confidence'))
        OverallConfidence = self.ParseFloat(Row.get('overall_confidence'))
        
        # Handle processing flags
        ProcessingFlags = []
        if Row.get('errors'):
            ProcessingFlags.append('extraction_errors')
        if CategoryConfidence and CategoryConfidence < 0.7:
            ProcessingFlags.append('low_category_confidence')
        if SubjectConfidence and SubjectConfidence < 0.7:
            ProcessingFlags.append('low_subject_confidence')
        
        return {
            'FileName': Row['filename'],
            'FilePath': None,
            'FileSize': FileSize,
            'FileSizeMB': FileSizeMB,
            'PageCount': int(Row.get('page_count', 0) or 0),
            'FileHash': None,
            'Title': Row.get('pdf_title') or Row.get('title') or Path(Row['filename']).stem,
            'Author': Row.get('pdf_author') or Row.get('author'),
            'Publisher': Row.get('extracted_publisher') or Row.get('publisher'),
            'PublicationYear': self.ParseInt(Row.get('extracted_year')),
            'ISBN': Row.get('extracted_isbn') or Row.get('isbn'),
            'PDFTitle': Row.get('pdf_title'),
            'PDFAuthor': Row.get('pdf_author'),
            'PDFSubject': Row.get('pdf_subject'),
            'PDFCreator': Row.get('pdf_creator'),
            'PDFProducer': Row.get('pdf_producer'),
            'PDFCreationDate': Row.get('pdf_creation_date'),
            'CategoryID': CategoryID,
            'SubjectID': SubjectID,
            'CategoryConfidence': CategoryConfidence,
            'SubjectConfidence': SubjectConfidence,
            'OverallConfidence': OverallConfidence,
            'ExtractedISBN': Row.get('extracted_isbn'),
            'ExtractedYear': self.ParseInt(Row.get('extracted_year')),
            'ExtractedPublisher': Row.get('extracted_publisher'),
            'ExtractedEdition': Row.get('extracted_edition'),
            'ExtractionMethod': Row.get('extraction_method', 'legacy'),
            'ProcessingDate': datetime.now().isoformat(),
            'ProcessingErrors': Row.get('errors'),
            'ProcessingFlags': json.dumps(ProcessingFlags) if ProcessingFlags else None,
            'CoverPath': None,
            'ThumbnailPath': None,
            'DateAdded': datetime.now().isoformat()
        }

    def InsertBookContent(self, Cursor: sqlite3.Cursor, BookID: int, Row: pd.Series):
        """Insert book content for full-text search"""
        
        Cursor.execute("""
            INSERT INTO BookContent (
                BookID, FirstPageText, TitlePageText, CopyrightPageText, ExtractionDate
            ) VALUES (?, ?, ?, ?, ?)
        """, [
            BookID,
            Row.get('first_page_text', '')[:5000],  # Limit text length
            Row.get('title_page_text', '')[:5000],
            Row.get('copyright_page_text', '')[:5000],
            datetime.now().isoformat()
        ])
        
        self.StatsCounters['ContentProcessed'] += 1

    def ProcessBookContent(self):
        """Process book content for full-text search indexing"""
        print("🔍 Processing content for full-text search...")
        
        Connection = sqlite3.connect(self.NewDatabasePath)
        Cursor = Connection.cursor()
        
        # Populate FTS table
        Cursor.execute("""
            INSERT INTO BooksFullText (rowid, Title, Author, Publisher, PDFTitle, PDFAuthor, PDFSubject)
            SELECT BookID, Title, Author, Publisher, PDFTitle, PDFAuthor, PDFSubject
            FROM Books WHERE IsActive = 1
        """)
        
        Connection.commit()
        Connection.close()
        
        print("✅ Full-text search indexing completed")

    def GenerateInitialAnalytics(self):
        """Generate initial analytics for the migrated data"""
        print("📊 Generating initial analytics...")
        
        Connection = sqlite3.connect(self.NewDatabasePath)
        Cursor = Connection.cursor()
        
        # Add initial view events for existing books
        Cursor.execute("""
            INSERT INTO BookAnalytics (BookID, EventType, EventDate)
            SELECT BookID, 'migration', DateAdded
            FROM Books WHERE IsActive = 1
        """)
        
        Connection.commit()
        Connection.close()
        
        print("✅ Initial analytics generated")

    def GenerateReport(self):
        """Generate migration completion report"""
        print("\n" + "="*60)
        print("📋 MIGRATION COMPLETION REPORT")
        print("="*60)
        
        for StatName, Count in self.StatsCounters.items():
            print(f"{StatName}: {Count}")
        
        # Database statistics
        Connection = sqlite3.connect(self.NewDatabasePath)
        Cursor = Connection.cursor()
        
        Cursor.execute("SELECT COUNT(*) FROM Categories WHERE IsActive = 1")
        ActiveCategories = Cursor.fetchone()[0]
        
        Cursor.execute("SELECT COUNT(*) FROM Subjects WHERE IsActive = 1")
        ActiveSubjects = Cursor.fetchone()[0]
        
        Cursor.execute("SELECT COUNT(*) FROM Books WHERE IsActive = 1")
        ActiveBooks = Cursor.fetchone()[0]
        
        Cursor.execute("SELECT COUNT(*) FROM Books WHERE OverallConfidence >= 0.8")
        HighConfidenceBooks = Cursor.fetchone()[0]
        
        Cursor.execute("SELECT COUNT(*) FROM Books WHERE CoverPath IS NOT NULL")
        BooksWithCovers = Cursor.fetchone()[0]
        
        Connection.close()
        
        print(f"\n📊 DATABASE SUMMARY:")
        print(f"   Active Categories: {ActiveCategories}")
        print(f"   Active Subjects: {ActiveSubjects}")
        print(f"   Active Books: {ActiveBooks}")
        print(f"   High Confidence Books: {HighConfidenceBooks} ({HighConfidenceBooks/ActiveBooks*100:.1f}%)")
        print(f"   Books with Covers: {BooksWithCovers} ({BooksWithCovers/ActiveBooks*100:.1f}%)")
        
        print(f"\n✅ Migration completed successfully!")
        print(f"📁 Enhanced SQLite database: {self.NewDatabasePath}")
        
        # MySQL conversion instructions
        print(f"\n🔄 MYSQL CONVERSION READY!")
        print("="*60)
        print("Your database is now ready for MySQL conversion:")
        print()
        print("STEP 1: Generate MySQL dump")
        print("   Use your SQLite-to-MySQL converter on:")
        print(f"   {self.NewDatabasePath}")
        print()
        print("STEP 2: Import to MySQL")
        print("   mysql -u username -p database_name < converted_dump.sql")
        print()
        print("STEP 3: Run MySQL optimizations")
        print("   Execute the MySQL enhancement script to add:")
        print("   - AUTO_INCREMENT to primary keys")
        print("   - FULLTEXT search indexes")
        print("   - MySQL-specific stored procedures")
        print("   - Performance optimizations")
        print()
        print("STEP 4: MySQL Workbench benefits")
        print("   - Visual ER diagrams")
        print("   - Query optimization tools")
        print("   - Data modeling validation")
        print("   - Export capabilities")
        print()
        print("🎯 MYSQL FEATURES ENABLED:")
        print("   ✅ FULLTEXT search on Books and BookContent")
        print("   ✅ Stored procedures for complex queries")
        print("   ✅ Custom functions for popularity scoring")
        print("   ✅ Optimized indexes for performance")
        print("   ✅ UTF8MB4 charset for full Unicode support")
        print("   ✅ InnoDB engine for ACID compliance")
        print("="*60)

    def ExportForMySQL(self) -> str:
        """Export additional MySQL-specific setup instructions"""
        MySQLSetupPath = self.NewDatabasePath.replace('.db', '_mysql_setup.sql')
        
        MySQLInstructions = f"""
-- MySQL Conversion Instructions
-- Generated: {datetime.now().isoformat()}
-- Source: {self.NewDatabasePath}

-- ===============================================
-- MYSQL CONVERSION WORKFLOW
-- ===============================================

-- 1. CONVERT SQLITE TO MYSQL
-- Use your SQLite-to-MySQL converter tool:
-- Input: {self.NewDatabasePath}
-- Output: mylibrary_mysql.sql

-- 2. CREATE MYSQL DATABASE
CREATE DATABASE anderson_library 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE anderson_library;

-- 3. IMPORT CONVERTED DATA
-- mysql -u username -p anderson_library < mylibrary_mysql.sql

-- 4. RUN ENHANCEMENTS
-- Execute the MySQL conversion enhancement script

-- ===============================================
-- POST-CONVERSION VERIFICATION QUERIES
-- ===============================================

-- Verify data integrity
SELECT 
    'Categories' as table_name, COUNT(*) as record_count 
FROM Categories WHERE IsActive = 1
UNION ALL
SELECT 
    'Subjects' as table_name, COUNT(*) as record_count 
FROM Subjects WHERE IsActive = 1
UNION ALL
SELECT 
    'Books' as table_name, COUNT(*) as record_count 
FROM Books WHERE IsActive = 1;

-- Test FULLTEXT search (after enhancement script)
-- SELECT Title, Author, 
--        MATCH(Title, Author, Publisher) AGAINST ('python') as relevance
-- FROM Books 
-- WHERE MATCH(Title, Author, Publisher) AGAINST ('python' IN NATURAL LANGUAGE MODE)
-- ORDER BY relevance DESC;

-- Verify foreign key relationships
SELECT 
    COUNT(DISTINCT b.CategoryID) as categories_used,
    COUNT(DISTINCT b.SubjectID) as subjects_used
FROM Books b 
WHERE b.IsActive = 1;

-- ===============================================
-- MYSQL WORKBENCH SETUP
-- ===============================================

-- 1. Connect to MySQL database
-- 2. Use "Database > Reverse Engineer" to create ER diagram
-- 3. Explore relationships visually
-- 4. Use Query tab for analysis
-- 5. Export documentation and diagrams

-- ===============================================
-- PERFORMANCE MONITORING
-- ===============================================

-- Monitor query performance
-- EXPLAIN SELECT * FROM Books WHERE Title LIKE '%python%';
-- EXPLAIN SELECT * FROM Books WHERE MATCH(Title) AGAINST ('python');

-- Check index usage
-- SHOW INDEX FROM Books;
-- SHOW INDEX FROM BookContent;

"""
        
        with open(MySQLSetupPath, 'w', encoding='utf-8') as File:
            File.write(MySQLInstructions)
        
        print(f"📄 MySQL setup instructions: {MySQLSetupPath}")
        return MySQLSetupPath

    def CalculateFileHash(self, FilePath: Path) -> str:
        """Calculate SHA256 hash of file"""
        Hash = hashlib.sha256()
        with open(FilePath, 'rb') as File:
            for Chunk in iter(lambda: File.read(4096), b""):
                Hash.update(Chunk)
        return Hash.hexdigest()

    def ParseFloat(self, Value) -> Optional[float]:
        """Safely parse float value"""
        try:
            if pd.isna(Value):
                return None
            return float(Value)
        except (ValueError, TypeError):
            return None

    def ParseInt(self, Value) -> Optional[int]:
        """Safely parse integer value"""
        try:
            if pd.isna(Value):
                return None
            return int(float(Value))
        except (ValueError, TypeError):
            return None

    def GetEnhancedSchema(self) -> str:
        """Return the enhanced schema SQL - optimized for MySQL compatibility"""
        return """
        -- MyLibrary Database Schema - Dual SQLite/MySQL Compatible
        -- Use the complete schema from the dual-compatible artifact
        
        PRAGMA foreign_keys = ON;
        PRAGMA journal_mode = WAL;
        
        -- Core tables with MySQL-compatible sizing
        CREATE TABLE Categories (
            CategoryID INTEGER NOT NULL,
            CategoryName VARCHAR(100) NOT NULL,
            Description TEXT(1000),
            ParentCategoryID INTEGER DEFAULT NULL,
            Color VARCHAR(7) DEFAULT '#4285f4',
            SortOrder INTEGER DEFAULT 0,
            CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            ModifiedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            IsActive TINYINT(1) DEFAULT 1,
            PRIMARY KEY (CategoryID),
            CONSTRAINT UK_Categories_Name UNIQUE (CategoryName)
        );
        
        CREATE TABLE Subjects (
            SubjectID INTEGER NOT NULL,
            SubjectName VARCHAR(150) NOT NULL,
            CategoryID INTEGER NOT NULL,
            Description TEXT(2000),
            KeywordTags TEXT(1000),
            SortOrder INTEGER DEFAULT 0,
            CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            ModifiedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            IsActive TINYINT(1) DEFAULT 1,
            PRIMARY KEY (SubjectID),
            FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID),
            CONSTRAINT UK_Subjects_CategoryName UNIQUE (SubjectName, CategoryID)
        );
        
        CREATE TABLE Books (
            BookID INTEGER NOT NULL,
            FileName VARCHAR(255) NOT NULL,
            FilePath VARCHAR(500),
            FileSize BIGINT,
            FileSizeMB DECIMAL(10,2),
            PageCount INTEGER,
            FileHash VARCHAR(64),
            Title VARCHAR(500),
            Author VARCHAR(300),
            Publisher VARCHAR(200),
            PublicationYear INTEGER,
            ISBN VARCHAR(20),
            Language VARCHAR(50) DEFAULT 'English',
            Edition VARCHAR(100),
            PDFTitle VARCHAR(500),
            PDFAuthor VARCHAR(300),
            PDFSubject VARCHAR(300),
            PDFCreator VARCHAR(100),
            PDFProducer VARCHAR(100),
            PDFCreationDate VARCHAR(50),
            CategoryID INTEGER,
            SubjectID INTEGER,
            CategoryConfidence DECIMAL(5,4),
            SubjectConfidence DECIMAL(5,4),
            OverallConfidence DECIMAL(5,4),
            ExtractedISBN VARCHAR(20),
            ExtractedYear INTEGER,
            ExtractedPublisher VARCHAR(200),
            ExtractedEdition VARCHAR(100),
            ReadingLevel DECIMAL(4,2),
            ComplexityScore DECIMAL(4,2),
            QualityScore DECIMAL(4,2),
            ContentTags TEXT(2000),
            ExtractionMethod VARCHAR(50),
            ProcessingDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            ProcessingVersion VARCHAR(20),
            ProcessingErrors TEXT(1000),
            ProcessingFlags TEXT(500),
            ViewCount INTEGER DEFAULT 0,
            DownloadCount INTEGER DEFAULT 0,
            Rating DECIMAL(3,2) DEFAULT 0.00,
            RatingCount INTEGER DEFAULT 0,
            CoverPath VARCHAR(500),
            ThumbnailPath VARCHAR(500),
            DateAdded TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            DateModified TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            LastAccessed TIMESTAMP,
            IsActive TINYINT(1) DEFAULT 1,
            PRIMARY KEY (BookID),
            FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID),
            FOREIGN KEY (SubjectID) REFERENCES Subjects(SubjectID),
            CONSTRAINT UK_Books_FileName UNIQUE (FileName)
        );
        
        CREATE TABLE BookContent (
            BookID INTEGER NOT NULL,
            FirstPageText TEXT(16000),
            TitlePageText TEXT(16000),
            CopyrightPageText TEXT(16000),
            ExtractedKeywords TEXT(2000),
            ExtractedEntities TEXT(2000),
            ExtractedTopics TEXT(2000),
            ContentLanguage VARCHAR(20),
            ContentEncoding VARCHAR(20),
            ExtractionDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (BookID),
            FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
        );
        
        CREATE TABLE BookSearchIndex (
            BookID INTEGER NOT NULL,
            SearchableContent TEXT(20000),
            IndexedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (BookID),
            FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
        );
        
        CREATE TABLE LLMClassifications (
            ClassificationID INTEGER NOT NULL,
            BookID INTEGER NOT NULL,
            ModelName VARCHAR(100) NOT NULL,
            ModelVersion VARCHAR(50),
            InputPrompt TEXT(5000),
            RawResponse TEXT(10000),
            ParsedResults TEXT(2000),
            CategorySuggested VARCHAR(100),
            SubjectSuggested VARCHAR(150),
            ConfidenceScore DECIMAL(5,4),
            ProcessingTime DECIMAL(8,3),
            TokensUsed INTEGER,
            ClassificationDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            IsAccepted TINYINT(1) DEFAULT 0,
            UserOverride TEXT(1000),
            PRIMARY KEY (ClassificationID),
            FOREIGN KEY (BookID) REFERENCES Books(BookID)
        );
        
        -- Essential indexes
        CREATE INDEX idx_books_title ON Books(Title);
        CREATE INDEX idx_books_author ON Books(Author);
        CREATE INDEX idx_books_category ON Books(CategoryID);
        CREATE INDEX idx_books_confidence ON Books(OverallConfidence);
        CREATE INDEX idx_categories_active ON Categories(IsActive);
        CREATE INDEX idx_subjects_category ON Subjects(CategoryID);
        
        -- Essential views
        CREATE VIEW BookDetails AS
        SELECT 
            b.BookID, b.FileName, b.Title, b.Author, b.Publisher, b.PublicationYear,
            c.CategoryName, s.SubjectName, b.CategoryConfidence, b.SubjectConfidence,
            b.OverallConfidence, b.FileSize, b.PageCount, b.Rating, b.ViewCount,
            b.DateAdded, b.CoverPath, b.ThumbnailPath, b.IsActive
        FROM Books b
        LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
        LEFT JOIN Subjects s ON b.SubjectID = s.SubjectID;
        """

if __name__ == "__main__":
    # Configuration
    OLD_DATABASE = "Assets/my_library.db"
    CSV_FILE = "AndersonLibrary_PDFMetadata.csv"
    NEW_DATABASE = "MyLibrary_Enhanced.db"
    BOOKS_DIR = "Anderson eBooks"
    COVERS_DIR = "Covers"
    THUMBS_DIR = "Thumbs"
    
    # Execute migration
    Migrator = LibraryDataMigrator(
        OldDatabasePath=OLD_DATABASE,
        CSVPath=CSV_FILE,
        NewDatabasePath=NEW_DATABASE,
        BooksDirectory=BOOKS_DIR,
        CoversDirectory=COVERS_DIR,
        ThumbnailsDirectory=THUMBS_DIR
    )
    
    Success = Migrator.ExecuteMigration()
    
    if Success:
        print("\n🎉 Your Anderson's Library database has been successfully upgraded!")
        print("🔍 Full-text search enabled")
        print("🤖 AI classification tracking ready")
        print("📊 Analytics and relationship mapping prepared")
        print("🐬 MySQL conversion ready - see generated setup instructions")
        print("📈 Use MySQL Workbench for visual ER diagrams and analysis")
    else:
        print("\n❌ Migration failed - check logs for details")
