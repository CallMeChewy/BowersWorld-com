-- ===============================================
-- Enhanced MyLibrary Schema v2.0
-- SQLite Compatible / MySQL Future-Proofed
-- Standard: AIDEV-PascalCase-1.8
-- Author: Herb Bowers - Project Himalaya
-- ===============================================

-- =============================================
-- CORE LIBRARY TABLES
-- =============================================

-- Categories Table - Primary classification system
CREATE TABLE Categories (
    CategoryID INTEGER PRIMARY KEY AUTOINCREMENT,
    CategoryName VARCHAR(100) NOT NULL,
    Description TEXT,
    ParentCategoryID INTEGER DEFAULT NULL,
    Color VARCHAR(7) DEFAULT '#4285f4',
    SortOrder INTEGER DEFAULT 0,
    CreatedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    IsActive INTEGER DEFAULT 1,
    
    FOREIGN KEY (ParentCategoryID) REFERENCES Categories(CategoryID) ON DELETE SET NULL,
    CONSTRAINT UK_Categories_Name UNIQUE (CategoryName)
);

-- Subjects Table - Secondary classification within categories
CREATE TABLE Subjects (
    SubjectID INTEGER PRIMARY KEY AUTOINCREMENT,
    SubjectName VARCHAR(150) NOT NULL,
    CategoryID INTEGER NOT NULL,
    Description TEXT,
    KeywordTags TEXT,
    SortOrder INTEGER DEFAULT 0,
    CreatedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    IsActive INTEGER DEFAULT 1,
    
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID) ON DELETE CASCADE,
    CONSTRAINT UK_Subjects_CategoryName UNIQUE (SubjectName, CategoryID)
);

-- Main Books Table - Core book records
CREATE TABLE Books (
    BookID INTEGER PRIMARY KEY AUTOINCREMENT,
    FileName VARCHAR(255) NOT NULL,
    FilePath VARCHAR(500),
    FileSize INTEGER,
    FileSizeMB REAL,
    PageCount INTEGER,
    FileHash VARCHAR(64),
    
    -- Basic Bibliographic Data
    Title VARCHAR(500),
    Author VARCHAR(300),
    Publisher VARCHAR(200),
    PublicationYear INTEGER,
    ISBN VARCHAR(20),
    Language VARCHAR(50) DEFAULT 'English',
    Edition VARCHAR(100),
    
    -- PDF Extracted Metadata
    PDFTitle VARCHAR(500),
    PDFAuthor VARCHAR(300),
    PDFSubject VARCHAR(300),
    PDFCreator VARCHAR(100),
    PDFProducer VARCHAR(100),
    PDFCreationDate VARCHAR(50),
    
    -- Classification (Foreign Keys - Can be NULL until AI processes)
    CategoryID INTEGER DEFAULT NULL,
    SubjectID INTEGER DEFAULT NULL,
    CategoryConfidence REAL DEFAULT NULL,
    SubjectConfidence REAL DEFAULT NULL,
    OverallConfidence REAL DEFAULT NULL,
    
    -- Enhanced Bibliographic Identifiers (from Himalaya CSV)
    ExtractedISBN VARCHAR(20),
    ExtractedLCCN VARCHAR(20),        -- Library of Congress Control Number
    ExtractedISSN VARCHAR(20),        -- International Standard Serial Number
    ExtractedOCLC VARCHAR(20),        -- OCLC Number
    ExtractedDOI VARCHAR(200),        -- Digital Object Identifier
    ExtractedYear INTEGER,
    ExtractedPublisher VARCHAR(200),
    ExtractedEdition VARCHAR(100),
    
    -- AI Analysis Metrics
    ReadingLevel REAL,
    ComplexityScore REAL,
    QualityScore REAL,
    ContentTags TEXT,
    
    -- Processing Metadata
    ExtractionMethod VARCHAR(50),
    ProcessingDate TEXT DEFAULT CURRENT_TIMESTAMP,
    ProcessingVersion VARCHAR(20),
    ProcessingErrors TEXT,
    ProcessingFlags VARCHAR(500),
    
    -- User Interaction Data
    ViewCount INTEGER DEFAULT 0,
    DownloadCount INTEGER DEFAULT 0,
    Rating REAL DEFAULT 0.00,
    RatingCount INTEGER DEFAULT 0,
    
    -- System Fields
    DateAdded TEXT DEFAULT CURRENT_TIMESTAMP,
    DateModified TEXT DEFAULT CURRENT_TIMESTAMP,
    LastAccessed TEXT,
    IsActive INTEGER DEFAULT 1,
    
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID) ON DELETE SET NULL,
    FOREIGN KEY (SubjectID) REFERENCES Subjects(SubjectID) ON DELETE SET NULL,
    CONSTRAINT UK_Books_FileName UNIQUE (FileName)
);

-- =============================================
-- THUMBNAIL & ASSET MANAGEMENT
-- =============================================

-- Book Assets - Tracks covers, thumbnails, and related files
CREATE TABLE BookAssets (
    AssetID INTEGER PRIMARY KEY AUTOINCREMENT,
    BookID INTEGER NOT NULL,
    AssetType VARCHAR(20) NOT NULL CHECK (AssetType IN ('cover', 'thumbnail', 'preview', 'excerpt')),
    AssetFormat VARCHAR(10) NOT NULL,  -- png, jpg, pdf, etc.
    
    -- File Information (paths calculated: folder + filename)
    BaseFileName VARCHAR(255) NOT NULL,  -- Same as book filename (without extension)
    FileSize INTEGER,
    Width INTEGER,
    Height INTEGER,
    FileHash VARCHAR(64),
    
    -- Asset Metadata
    Quality REAL,                      -- 0.00-1.00 quality score
    GenerationMethod VARCHAR(50),       -- 'extracted', 'generated', 'manual'
    SourceAssetID INTEGER DEFAULT NULL, -- Reference to source asset if derived
    
    -- System Fields
    CreatedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    IsActive INTEGER DEFAULT 1,
    
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (SourceAssetID) REFERENCES BookAssets(AssetID) ON DELETE SET NULL,
    CONSTRAINT UK_BookAssets_Type UNIQUE (BookID, AssetType)
);

-- =============================================
-- CONTENT & SEARCH TABLES
-- =============================================

-- Book Content - Extracted text content for search
CREATE TABLE BookContent (
    BookID INTEGER PRIMARY KEY,
    FirstPageText TEXT,
    TitlePageText TEXT,
    CopyrightPageText TEXT,
    ExtractedKeywords TEXT,
    ExtractedEntities TEXT,
    ExtractedTopics TEXT,
    ContentLanguage VARCHAR(20),
    ContentEncoding VARCHAR(20),
    ExtractionDate TEXT DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- Full-Text Search Table (Universal compatibility)
-- Note: Use FTS5 if available, otherwise regular table with LIKE searches
CREATE TABLE BookSearchIndex (
    BookID INTEGER PRIMARY KEY,
    SearchableContent TEXT,
    Title TEXT,
    Author TEXT,
    Publisher TEXT,
    Keywords TEXT,
    IndexedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- Optional FTS5 Virtual Table (if FTS5 module available)
-- Uncomment and run this separately if your SQLite has FTS5:
-- CREATE VIRTUAL TABLE BooksFullText USING fts5(
--     Title, Author, Publisher, PDFTitle, PDFAuthor, PDFSubject, ExtractedKeywords,
--     content='Books', content_rowid='BookID'
-- );

-- =============================================
-- AI CLASSIFICATION SYSTEM
-- =============================================

-- LLM Classifications - Track AI classification attempts
CREATE TABLE LLMClassifications (
    ClassificationID INTEGER PRIMARY KEY AUTOINCREMENT,
    BookID INTEGER NOT NULL,
    ModelName VARCHAR(100) NOT NULL,
    ModelVersion VARCHAR(50),
    InputPrompt TEXT,
    RawResponse TEXT,
    ParsedResults TEXT,
    CategorySuggested VARCHAR(100),
    SubjectSuggested VARCHAR(150),
    ConfidenceScore REAL,
    ProcessingTime REAL,
    TokensUsed INTEGER,
    ClassificationDate TEXT DEFAULT CURRENT_TIMESTAMP,
    IsAccepted INTEGER DEFAULT 0,
    UserOverride TEXT,
    
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- =============================================
-- BOOK RELATIONSHIPS & ANALYTICS
-- =============================================

-- Book Relationships - Knowledge graph connections
CREATE TABLE BookRelationships (
    RelationshipID INTEGER PRIMARY KEY AUTOINCREMENT,
    BookID1 INTEGER NOT NULL,
    BookID2 INTEGER NOT NULL,
    RelationshipType VARCHAR(20) NOT NULL CHECK (RelationshipType IN ('similar', 'prerequisite', 'sequel', 'cites', 'references')),
    Strength REAL DEFAULT 0.50,       -- 0.00 to 1.00 confidence
    Source VARCHAR(20) DEFAULT 'ai' CHECK (Source IN ('ai', 'user', 'metadata', 'api')),
    CreatedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    IsActive INTEGER DEFAULT 1,
    
    FOREIGN KEY (BookID1) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (BookID2) REFERENCES Books(BookID) ON DELETE CASCADE,
    CONSTRAINT UK_BookRel_Pair UNIQUE (BookID1, BookID2, RelationshipType)
);

-- Book Analytics - Track user interactions
CREATE TABLE BookAnalytics (
    AnalyticsID INTEGER PRIMARY KEY AUTOINCREMENT,
    BookID INTEGER NOT NULL,
    EventType VARCHAR(50) NOT NULL,  -- 'view', 'download', 'search', 'rate'
    EventData TEXT,                  -- JSON-formatted event-specific data
    UserAgent VARCHAR(500),
    IPAddress VARCHAR(45),
    EventDate TEXT DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

-- Categories indexes
CREATE INDEX idx_categories_active ON Categories(IsActive);
CREATE INDEX idx_categories_parent ON Categories(ParentCategoryID);
CREATE INDEX idx_categories_sort ON Categories(SortOrder);

-- Subjects indexes
CREATE INDEX idx_subjects_category ON Subjects(CategoryID);
CREATE INDEX idx_subjects_active ON Subjects(IsActive);

-- Books indexes
CREATE INDEX idx_books_title ON Books(Title);
CREATE INDEX idx_books_author ON Books(Author);
CREATE INDEX idx_books_publisher ON Books(Publisher);
CREATE INDEX idx_books_year ON Books(PublicationYear);
CREATE INDEX idx_books_category ON Books(CategoryID);
CREATE INDEX idx_books_subject ON Books(SubjectID);
CREATE INDEX idx_books_confidence ON Books(OverallConfidence);
CREATE INDEX idx_books_rating ON Books(Rating);
CREATE INDEX idx_books_active ON Books(IsActive);
CREATE INDEX idx_books_isbn ON Books(ISBN);
CREATE INDEX idx_books_extracted_isbn ON Books(ExtractedISBN);

-- BookAssets indexes
CREATE INDEX idx_assets_book ON BookAssets(BookID);
CREATE INDEX idx_assets_type ON BookAssets(AssetType);
CREATE INDEX idx_assets_active ON BookAssets(IsActive);

-- LLM Classifications indexes
CREATE INDEX idx_llm_book ON LLMClassifications(BookID);
CREATE INDEX idx_llm_model ON LLMClassifications(ModelName);
CREATE INDEX idx_llm_accepted ON LLMClassifications(IsAccepted);
CREATE INDEX idx_llm_confidence ON LLMClassifications(ConfidenceScore);

-- Relationships indexes
CREATE INDEX idx_relations_book1 ON BookRelationships(BookID1);
CREATE INDEX idx_relations_book2 ON BookRelationships(BookID2);
CREATE INDEX idx_relations_type ON BookRelationships(RelationshipType);

-- Analytics indexes
CREATE INDEX idx_analytics_book ON BookAnalytics(BookID);
CREATE INDEX idx_analytics_event ON BookAnalytics(EventType);
CREATE INDEX idx_analytics_date ON BookAnalytics(EventDate);

-- BookSearchIndex indexes (for fast LIKE searches without FTS5)
CREATE INDEX idx_search_content ON BookSearchIndex(SearchableContent);
CREATE INDEX idx_search_title ON BookSearchIndex(Title);
CREATE INDEX idx_search_author ON BookSearchIndex(Author);
CREATE INDEX idx_search_publisher ON BookSearchIndex(Publisher);
CREATE INDEX idx_search_keywords ON BookSearchIndex(Keywords);

-- =============================================
-- VIEWS FOR COMMON OPERATIONS
-- =============================================

-- Book Details - Primary view for displaying books
CREATE VIEW BookDetails AS
SELECT 
    b.BookID,
    b.FileName,
    b.Title,
    b.Author,
    b.Publisher,
    b.PublicationYear,
    b.ISBN,
    b.Language,
    b.PageCount,
    b.FileSizeMB,
    
    -- Classification
    c.CategoryName,
    s.SubjectName,
    b.CategoryConfidence,
    b.SubjectConfidence,
    b.OverallConfidence,
    
    -- Assets (calculated paths - no storage needed)
    CASE WHEN ca.AssetID IS NOT NULL 
         THEN 'Covers/' || REPLACE(b.FileName, '.pdf', '.png')
         ELSE NULL END AS CoverPath,
    CASE WHEN ta.AssetID IS NOT NULL 
         THEN 'Thumbs/' || REPLACE(b.FileName, '.pdf', '.png')
         ELSE NULL END AS ThumbnailPath,
         
    -- Statistics
    b.Rating,
    b.ViewCount,
    b.DateAdded,
    b.IsActive
    
FROM Books b
LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
LEFT JOIN Subjects s ON b.SubjectID = s.SubjectID
LEFT JOIN BookAssets ca ON b.BookID = ca.BookID AND ca.AssetType = 'cover' AND ca.IsActive = 1
LEFT JOIN BookAssets ta ON b.BookID = ta.BookID AND ta.AssetType = 'thumbnail' AND ta.IsActive = 1;

-- Book Search - Optimized for search operations
CREATE VIEW BookSearch AS
SELECT 
    b.BookID,
    b.FileName,
    b.Title,
    b.Author,
    b.Publisher,
    b.PublicationYear,
    c.CategoryName,
    s.SubjectName,
    b.ISBN,
    b.ExtractedISBN,
    b.OverallConfidence,
    b.Rating,
    b.ViewCount
FROM Books b
LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
LEFT JOIN Subjects s ON b.SubjectID = s.SubjectID
WHERE b.IsActive = 1;

-- =============================================
-- TRIGGERS FOR DATA INTEGRITY
-- =============================================

-- Update ModifiedDate on Books changes
CREATE TRIGGER tr_books_modified 
AFTER UPDATE ON Books
FOR EACH ROW
BEGIN
    UPDATE Books SET ModifiedDate = CURRENT_TIMESTAMP WHERE BookID = NEW.BookID;
END;

-- Update ModifiedDate on Categories changes
CREATE TRIGGER tr_categories_modified 
AFTER UPDATE ON Categories
FOR EACH ROW
BEGIN
    UPDATE Categories SET ModifiedDate = CURRENT_TIMESTAMP WHERE CategoryID = NEW.CategoryID;
END;

-- Update ModifiedDate on Subjects changes
CREATE TRIGGER tr_subjects_modified 
AFTER UPDATE ON Subjects
FOR EACH ROW
BEGIN
    UPDATE Subjects SET ModifiedDate = CURRENT_TIMESTAMP WHERE SubjectID = NEW.SubjectID;
END;

-- =============================================
-- COMPATIBILITY NOTES
-- =============================================

/*
MySQL Conversion Changes Needed:
1. AUTOINCREMENT → AUTO_INCREMENT
2. INTEGER → BOOLEAN for IsActive fields
3. VARCHAR(20) CHECK → ENUM for constrained values
4. TEXT → JSON for EventData
5. Add FULLTEXT indexes
6. Add ON UPDATE CURRENT_TIMESTAMP for timestamps
7. REAL → DECIMAL(precision,scale) for exact decimals

SQLite Optimizations:
1. Uses regular table for search if FTS5 unavailable
2. Uses triggers for timestamp updates
3. Uses CHECK constraints for data validation
4. Optimized indexing strategy

FTS5 Full-Text Search:
- Check availability: SELECT fts5('test');
- If available, create FTS5 virtual table
- If not, use BookSearchIndex with LIKE searches
- Performance: FTS5 > LIKE with indexes > plain LIKE

Path Calculation Logic:
- Cover: 'Covers/' + filename.replace('.pdf', '.png')
- Thumbnail: 'Thumbs/' + filename.replace('.pdf', '.png')
- Book: 'Books/' + filename

Search Implementation Without FTS5:
SELECT * FROM BookDetails 
WHERE Title LIKE '%python%' 
   OR Author LIKE '%python%' 
   OR Publisher LIKE '%python%'
ORDER BY OverallConfidence DESC;
*/