-- ===============================================
-- Enhanced MyLibrary Schema v2.0 - MySQL Compatible
-- Fixes MySQL key length limitations
-- Standard: AIDEV-PascalCase-1.8
-- Author: Herb Bowers - Project Himalaya
-- ===============================================

-- CREATE DATABASE MyLibrary;

-- Set MySQL specific settings
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- =============================================
-- CORE LIBRARY TABLES
-- =============================================

-- Categories Table - Primary classification system
CREATE TABLE Categories (
    CategoryID INTEGER NOT NULL AUTO_INCREMENT,
    CategoryName VARCHAR(100) NOT NULL,
    Description TEXT,
    ParentCategoryID INTEGER DEFAULT NULL,
    Color VARCHAR(7) DEFAULT '#4285f4',
    SortOrder INTEGER DEFAULT 0,
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (CategoryID),
    FOREIGN KEY (ParentCategoryID) REFERENCES Categories(CategoryID) ON DELETE SET NULL,
    CONSTRAINT UK_Categories_Name UNIQUE (CategoryName),
    INDEX idx_categories_active (IsActive),
    INDEX idx_categories_parent (ParentCategoryID),
    INDEX idx_categories_sort (SortOrder)
);

-- Subjects Table - Secondary classification within categories
CREATE TABLE Subjects (
    SubjectID INTEGER NOT NULL AUTO_INCREMENT,
    SubjectName VARCHAR(150) NOT NULL,
    CategoryID INTEGER NOT NULL,
    Description TEXT,
    KeywordTags TEXT,
    SortOrder INTEGER DEFAULT 0,
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (SubjectID),
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID) ON DELETE CASCADE,
    CONSTRAINT UK_Subjects_CategoryName UNIQUE (SubjectName, CategoryID),
    INDEX idx_subjects_category (CategoryID),
    INDEX idx_subjects_active (IsActive),
    INDEX idx_subjects_sort (CategoryID, SortOrder)
);

-- Main Books Table - Core book records
CREATE TABLE Books (
    BookID INTEGER NOT NULL AUTO_INCREMENT,
    FileName VARCHAR(255) NOT NULL,
    FilePath VARCHAR(500),
    FileSize BIGINT,
    FileSizeMB DECIMAL(10,2),
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
    CategoryConfidence DECIMAL(5,4) DEFAULT NULL,
    SubjectConfidence DECIMAL(5,4) DEFAULT NULL,
    OverallConfidence DECIMAL(5,4) DEFAULT NULL,
    
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
    ReadingLevel DECIMAL(4,2),
    ComplexityScore DECIMAL(4,2),
    QualityScore DECIMAL(4,2),
    ContentTags TEXT,
    
    -- Processing Metadata
    ExtractionMethod VARCHAR(50),
    ProcessingDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ProcessingVersion VARCHAR(20),
    ProcessingErrors TEXT,
    ProcessingFlags VARCHAR(500),
    
    -- User Interaction Data
    ViewCount INTEGER DEFAULT 0,
    DownloadCount INTEGER DEFAULT 0,
    Rating DECIMAL(3,2) DEFAULT 0.00,
    RatingCount INTEGER DEFAULT 0,
    
    -- System Fields
    DateAdded TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    DateModified TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    LastAccessed TIMESTAMP NULL,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (BookID),
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID) ON DELETE SET NULL,
    FOREIGN KEY (SubjectID) REFERENCES Subjects(SubjectID) ON DELETE SET NULL,
    CONSTRAINT UK_Books_FileName UNIQUE (FileName)
);

-- =============================================
-- OPTIMIZED INDEXES (MySQL Key Length Compatible)
-- =============================================

-- Individual indexes (fast and within key limits)
CREATE INDEX idx_books_title ON Books(Title(191));           -- Prefix index for long titles
CREATE INDEX idx_books_author ON Books(Author(191));         -- Prefix index for long authors  
CREATE INDEX idx_books_publisher ON Books(Publisher(100));   -- Reasonable publisher length
CREATE INDEX idx_books_year ON Books(PublicationYear);
CREATE INDEX idx_books_category ON Books(CategoryID);
CREATE INDEX idx_books_subject ON Books(SubjectID);
CREATE INDEX idx_books_confidence ON Books(OverallConfidence);
CREATE INDEX idx_books_rating ON Books(Rating);
CREATE INDEX idx_books_active ON Books(IsActive);
CREATE INDEX idx_books_isbn ON Books(ISBN);
CREATE INDEX idx_books_extracted_isbn ON Books(ExtractedISBN);
CREATE INDEX idx_books_language ON Books(Language);

-- Composite indexes (carefully sized to avoid key length issues)
CREATE INDEX idx_books_title_author ON Books(Title(100), Author(100));   -- Combined search
CREATE INDEX idx_books_category_rating ON Books(CategoryID, Rating);     -- Category browsing
CREATE INDEX idx_books_year_rating ON Books(PublicationYear, Rating);    -- Temporal browsing
CREATE INDEX idx_books_active_rating ON Books(IsActive, Rating);         -- Active books by rating

-- =============================================
-- THUMBNAIL & ASSET MANAGEMENT
-- =============================================

-- Book Assets - Tracks covers, thumbnails, and related files
CREATE TABLE BookAssets (
    AssetID INTEGER NOT NULL AUTO_INCREMENT,
    BookID INTEGER NOT NULL,
    AssetType ENUM('cover', 'thumbnail', 'preview', 'excerpt') NOT NULL,
    AssetFormat VARCHAR(10) NOT NULL,  -- png, jpg, pdf, etc.
    
    -- File Information (paths calculated: folder + filename)
    BaseFileName VARCHAR(255) NOT NULL,  -- Same as book filename (without extension)
    FileSize INTEGER,
    Width INTEGER,
    Height INTEGER,
    FileHash VARCHAR(64),
    
    -- Asset Metadata
    Quality DECIMAL(3,2),              -- 0.00-1.00 quality score
    GenerationMethod VARCHAR(50),       -- 'extracted', 'generated', 'manual'
    SourceAssetID INTEGER DEFAULT NULL, -- Reference to source asset if derived
    
    -- System Fields
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (AssetID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (SourceAssetID) REFERENCES BookAssets(AssetID) ON DELETE SET NULL,
    CONSTRAINT UK_BookAssets_Type UNIQUE (BookID, AssetType),
    
    INDEX idx_assets_book (BookID),
    INDEX idx_assets_type (AssetType),
    INDEX idx_assets_active (IsActive)
);

-- =============================================
-- CONTENT & SEARCH TABLES
-- =============================================

-- Book Content - Extracted text content for search
CREATE TABLE BookContent (
    BookID INTEGER NOT NULL,
    FirstPageText TEXT,
    TitlePageText TEXT,
    CopyrightPageText TEXT,
    ExtractedKeywords TEXT,
    ExtractedEntities TEXT,
    ExtractedTopics TEXT,
    ContentLanguage VARCHAR(20),
    ContentEncoding VARCHAR(20),
    ExtractionDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- Full-Text Search Table (MySQL FULLTEXT compatible)
CREATE TABLE BookSearchIndex (
    BookID INTEGER NOT NULL,
    SearchableContent TEXT,
    Title TEXT,
    Author TEXT,
    Publisher TEXT,
    Keywords TEXT,
    IndexedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    -- MySQL FULLTEXT indexes
    FULLTEXT INDEX ft_searchable_content (SearchableContent),
    FULLTEXT INDEX ft_title_author (Title, Author),
    FULLTEXT INDEX ft_all_content (SearchableContent, Title, Author, Publisher, Keywords)
);

-- =============================================
-- AI CLASSIFICATION SYSTEM
-- =============================================

-- LLM Classifications - Track AI classification attempts
CREATE TABLE LLMClassifications (
    ClassificationID INTEGER NOT NULL AUTO_INCREMENT,
    BookID INTEGER NOT NULL,
    ModelName VARCHAR(100) NOT NULL,
    ModelVersion VARCHAR(50),
    InputPrompt TEXT,
    RawResponse TEXT,
    ParsedResults TEXT,
    CategorySuggested VARCHAR(100),
    SubjectSuggested VARCHAR(150),
    ConfidenceScore DECIMAL(5,4),
    ProcessingTime DECIMAL(8,3),
    TokensUsed INTEGER,
    ClassificationDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsAccepted BOOLEAN DEFAULT FALSE,
    UserOverride TEXT,
    
    PRIMARY KEY (ClassificationID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    INDEX idx_llm_book (BookID),
    INDEX idx_llm_model (ModelName, ModelVersion),
    INDEX idx_llm_accepted (IsAccepted),
    INDEX idx_llm_confidence (ConfidenceScore)
);

-- =============================================
-- BOOK RELATIONSHIPS & ANALYTICS
-- =============================================

-- Book Relationships - Knowledge graph connections
CREATE TABLE BookRelationships (
    RelationshipID INTEGER NOT NULL AUTO_INCREMENT,
    BookID1 INTEGER NOT NULL,
    BookID2 INTEGER NOT NULL,
    RelationshipType ENUM('similar', 'prerequisite', 'sequel', 'cites', 'references') NOT NULL,
    Strength DECIMAL(3,2) DEFAULT 0.50,  -- 0.00 to 1.00 confidence
    Source ENUM('ai', 'user', 'metadata', 'api') DEFAULT 'ai',
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (RelationshipID),
    FOREIGN KEY (BookID1) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (BookID2) REFERENCES Books(BookID) ON DELETE CASCADE,
    CONSTRAINT UK_BookRel_Pair UNIQUE (BookID1, BookID2, RelationshipType),
    
    INDEX idx_relations_book1 (BookID1),
    INDEX idx_relations_book2 (BookID2),
    INDEX idx_relations_type (RelationshipType),
    INDEX idx_relations_strength (Strength)
);

-- Book Analytics - Track user interactions
CREATE TABLE BookAnalytics (
    AnalyticsID INTEGER NOT NULL AUTO_INCREMENT,
    BookID INTEGER NOT NULL,
    EventType VARCHAR(50) NOT NULL,  -- 'view', 'download', 'search', 'rate'
    EventData JSON,                  -- MySQL JSON data type
    UserAgent VARCHAR(500),
    IPAddress VARCHAR(45),
    EventDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (AnalyticsID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    INDEX idx_analytics_book (BookID),
    INDEX idx_analytics_event (EventType),
    INDEX idx_analytics_date (EventDate)
);

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
         THEN CONCAT('Covers/', REPLACE(b.FileName, '.pdf', '.png'))
         ELSE NULL END AS CoverPath,
    CASE WHEN ta.AssetID IS NOT NULL 
         THEN CONCAT('Thumbs/', REPLACE(b.FileName, '.pdf', '.png'))
         ELSE NULL END AS ThumbnailPath,
         
    -- Statistics
    b.Rating,
    b.ViewCount,
    b.DateAdded,
    b.IsActive
    
FROM Books b
LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
LEFT JOIN Subjects s ON b.SubjectID = s.SubjectID
LEFT JOIN BookAssets ca ON b.BookID = ca.BookID AND ca.AssetType = 'cover' AND ca.IsActive = TRUE
LEFT JOIN BookAssets ta ON b.BookID = ta.BookID AND ta.AssetType = 'thumbnail' AND ta.IsActive = TRUE;

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
WHERE b.IsActive = TRUE;

-- =============================================
-- MYSQL OPTIMIZATION NOTES
-- =============================================

/*
Key Length Solutions Implemented:
1. Prefix indexes: Title(191), Author(191) instead of full length
2. Separate indexes instead of one large composite index
3. Strategic composite indexes under 3072 byte limit
4. FULLTEXT indexes for advanced search capabilities

MySQL-Specific Features Used:
1. ENUM data types for constrained values
2. JSON data type for EventData
3. FULLTEXT indexes for search
4. BOOLEAN data type
5. ON UPDATE CURRENT_TIMESTAMP triggers
6. AUTO_INCREMENT (MySQL syntax)

Search Performance:
1. FULLTEXT search: SELECT * FROM BookSearchIndex WHERE MATCH(SearchableContent) AGAINST('python programming' IN NATURAL LANGUAGE MODE)
2. Prefix search: SELECT * FROM Books WHERE Title LIKE 'Python%'
3. Combined search: Use BookDetails view with optimized indexes

Path Calculation:
- Cover: 'Covers/' + REPLACE(filename, '.pdf', '.png')
- Thumbnail: 'Thumbs/' + REPLACE(filename, '.pdf', '.png')
- Book: 'Books/' + filename
*/