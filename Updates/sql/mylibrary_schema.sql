-- MyLibrary Database Schema - Dual SQLite/MySQL Compatible
-- Standard: AIDEV-PascalCase-1.8
-- Author: Herb Bowers - Project Himalaya
-- Purpose: Cross-platform digital library database with AI classification support
-- Compatibility: SQLite 3.x primary, MySQL 8.0+ secondary via conversion

-- ====================================
-- SQLITE CONFIGURATION
-- ====================================
-- These pragmas are ignored by MySQL conversion

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = 10000;
PRAGMA temp_store = MEMORY;

-- ====================================
-- MYSQL COMPATIBILITY NOTES
-- ====================================
-- 1. All TEXT fields sized appropriately for MySQL row limits (65,535 bytes max)
-- 2. BOOLEAN mapped to TINYINT(1) 
-- 3. Auto-increment uses standard syntax
-- 4. JSON fields sized for MySQL JSON type compatibility
-- 5. Index names follow MySQL conventions
-- 6. Foreign keys use explicit naming

-- ====================================
-- CATEGORIES - TOP LEVEL CLASSIFICATION
-- ====================================

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
    CONSTRAINT FK_Categories_Parent FOREIGN KEY (ParentCategoryID) REFERENCES Categories(CategoryID),
    CONSTRAINT UK_Categories_Name UNIQUE (CategoryName)
);

-- ====================================
-- SUBJECTS - SECONDARY CLASSIFICATION
-- ====================================

CREATE TABLE Subjects (
    SubjectID INTEGER NOT NULL,
    SubjectName VARCHAR(150) NOT NULL,
    CategoryID INTEGER NOT NULL,
    Description TEXT(2000),
    KeywordTags TEXT(1000), -- JSON array, sized for MySQL
    SortOrder INTEGER DEFAULT 0,
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsActive TINYINT(1) DEFAULT 1,
    
    PRIMARY KEY (SubjectID),
    CONSTRAINT FK_Subjects_Category FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID),
    CONSTRAINT UK_Subjects_CategoryName UNIQUE (SubjectName, CategoryID)
);

-- ====================================
-- BOOKS - ENHANCED CORE TABLE
-- ====================================

CREATE TABLE Books (
    BookID INTEGER NOT NULL,
    
    -- File Information (MySQL compatible sizes)
    FileName VARCHAR(255) NOT NULL,
    FilePath VARCHAR(500),
    FileSize BIGINT,
    FileSizeMB DECIMAL(10,2),
    PageCount INTEGER,
    FileHash VARCHAR(64), -- SHA256 hash
    
    -- Basic Metadata
    Title VARCHAR(500),
    Author VARCHAR(300),
    Publisher VARCHAR(200),
    PublicationYear INTEGER,
    ISBN VARCHAR(20),
    Language VARCHAR(50) DEFAULT 'English',
    Edition VARCHAR(100),
    
    -- PDF Extracted Metadata (sized for MySQL limits)
    PDFTitle VARCHAR(500),
    PDFAuthor VARCHAR(300),
    PDFSubject VARCHAR(300),
    PDFCreator VARCHAR(100),
    PDFProducer VARCHAR(100),
    PDFCreationDate VARCHAR(50),
    
    -- Classification Results
    CategoryID INTEGER,
    SubjectID INTEGER,
    CategoryConfidence DECIMAL(5,4), -- 0.0000 to 1.0000
    SubjectConfidence DECIMAL(5,4),
    OverallConfidence DECIMAL(5,4),
    
    -- AI Extracted Information
    ExtractedISBN VARCHAR(20),
    ExtractedYear INTEGER,
    ExtractedPublisher VARCHAR(200),
    ExtractedEdition VARCHAR(100),
    
    -- Content Analysis Scores
    ReadingLevel DECIMAL(4,2),
    ComplexityScore DECIMAL(4,2),
    QualityScore DECIMAL(4,2),
    ContentTags TEXT(2000), -- JSON array, MySQL sized
    
    -- Processing Information
    ExtractionMethod VARCHAR(50),
    ProcessingDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ProcessingVersion VARCHAR(20),
    ProcessingErrors TEXT(1000),
    ProcessingFlags TEXT(500), -- JSON array of flags
    
    -- User Interaction Metrics
    ViewCount INTEGER DEFAULT 0,
    DownloadCount INTEGER DEFAULT 0,
    Rating DECIMAL(3,2) DEFAULT 0.00, -- 0.00 to 5.00
    RatingCount INTEGER DEFAULT 0,
    
    -- File System Paths
    CoverPath VARCHAR(500),
    ThumbnailPath VARCHAR(500),
    
    -- System Timestamps
    DateAdded TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    DateModified TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastAccessed TIMESTAMP,
    IsActive TINYINT(1) DEFAULT 1,
    
    PRIMARY KEY (BookID),
    CONSTRAINT FK_Books_Category FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID),
    CONSTRAINT FK_Books_Subject FOREIGN KEY (SubjectID) REFERENCES Subjects(SubjectID),
    CONSTRAINT UK_Books_FileName UNIQUE (FileName)
);

-- ====================================
-- BOOK CONTENT - EXTRACTED TEXT
-- ====================================
-- Separated to handle large text fields better in MySQL

CREATE TABLE BookContent (
    BookID INTEGER NOT NULL,
    FirstPageText TEXT(16000), -- MySQL TEXT limit consideration
    TitlePageText TEXT(16000),
    CopyrightPageText TEXT(16000),
    ExtractedKeywords TEXT(2000), -- JSON array
    ExtractedEntities TEXT(2000), -- JSON array of named entities
    ExtractedTopics TEXT(2000), -- JSON array from topic modeling
    ContentLanguage VARCHAR(20),
    ContentEncoding VARCHAR(20),
    ExtractionDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID),
    CONSTRAINT FK_BookContent_Book FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- ====================================
-- FULL TEXT CONTENT - LARGE TEXT STORAGE
-- ====================================
-- Separate table for potentially very large full-text content

CREATE TABLE BookFullTextContent (
    BookID INTEGER NOT NULL,
    FullTextExtracted LONGTEXT, -- MySQL LONGTEXT for large content
    WordCount INTEGER,
    CharacterCount INTEGER,
    ProcessingMethod VARCHAR(50),
    ExtractionDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID),
    CONSTRAINT FK_FullText_Book FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- ====================================
-- SQLITE FTS5 SEARCH TABLE
-- ====================================
-- This will be converted to MySQL FULLTEXT indexes during conversion

CREATE VIRTUAL TABLE BooksSearchFTS USING fts5(
    Title, Author, Publisher, PDFTitle, PDFAuthor, PDFSubject,
    ExtractedKeywords, FirstPageText,
    content='Books', content_rowid='BookID'
);

-- ====================================
-- MYSQL FULLTEXT SEARCH HELPER
-- ====================================
-- This table supports MySQL FULLTEXT when SQLite FTS5 isn't available

CREATE TABLE BookSearchIndex (
    BookID INTEGER NOT NULL,
    SearchableContent TEXT(20000), -- Combined searchable text
    IndexedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID),
    CONSTRAINT FK_Search_Book FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- ====================================
-- BOOK RELATIONSHIPS
-- ====================================

CREATE TABLE BookRelationships (
    RelationshipID INTEGER NOT NULL,
    BookID1 INTEGER NOT NULL,
    BookID2 INTEGER NOT NULL,
    RelationshipType VARCHAR(50) NOT NULL, -- 'similar', 'series', 'prerequisite', 'cites'
    Strength DECIMAL(4,3) DEFAULT 0.000, -- 0.000 to 1.000
    Source VARCHAR(30) NOT NULL, -- 'llm', 'user', 'metadata', 'content_analysis'
    SourceDetails TEXT(1000), -- JSON with analysis details
    DateCreated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsActive TINYINT(1) DEFAULT 1,
    
    PRIMARY KEY (RelationshipID),
    CONSTRAINT FK_Relationship_Book1 FOREIGN KEY (BookID1) REFERENCES Books(BookID),
    CONSTRAINT FK_Relationship_Book2 FOREIGN KEY (BookID2) REFERENCES Books(BookID),
    CONSTRAINT UK_Relationship_Unique UNIQUE (BookID1, BookID2, RelationshipType)
);

-- ====================================
-- LLM CLASSIFICATION TRACKING
-- ====================================

CREATE TABLE LLMClassifications (
    ClassificationID INTEGER NOT NULL,
    BookID INTEGER NOT NULL,
    ModelName VARCHAR(100) NOT NULL,
    ModelVersion VARCHAR(50),
    InputPrompt TEXT(5000),
    RawResponse TEXT(10000), -- Limited for MySQL compatibility
    ParsedResults TEXT(2000), -- JSON structured results
    CategorySuggested VARCHAR(100),
    SubjectSuggested VARCHAR(150),
    ConfidenceScore DECIMAL(5,4),
    ProcessingTime DECIMAL(8,3), -- seconds with millisecond precision
    TokensUsed INTEGER,
    ClassificationDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsAccepted TINYINT(1) DEFAULT 0,
    UserOverride TEXT(1000), -- JSON if user modified results
    
    PRIMARY KEY (ClassificationID),
    CONSTRAINT FK_LLM_Book FOREIGN KEY (BookID) REFERENCES Books(BookID)
);

-- ====================================
-- ANALYTICS TABLES
-- ====================================

CREATE TABLE BookAnalytics (
    AnalyticsID INTEGER NOT NULL,
    BookID INTEGER NOT NULL,
    EventType VARCHAR(20) NOT NULL, -- 'view', 'download', 'search', 'rate'
    EventDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UserAgent VARCHAR(200),
    IPAddress VARCHAR(45), -- IPv6 compatible
    SessionID VARCHAR(100),
    Duration INTEGER, -- seconds
    EventDetails TEXT(1000), -- JSON for additional data
    
    PRIMARY KEY (AnalyticsID),
    CONSTRAINT FK_Analytics_Book FOREIGN KEY (BookID) REFERENCES Books(BookID)
);

CREATE TABLE SearchAnalytics (
    SearchID INTEGER NOT NULL,
    SearchQuery VARCHAR(500) NOT NULL,
    SearchType VARCHAR(20), -- 'basic', 'advanced', 'semantic', 'fulltext'
    ResultsCount INTEGER,
    UserAgent VARCHAR(200),
    IPAddress VARCHAR(45),
    SearchDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ClickedBookID INTEGER,
    ClickPosition INTEGER,
    
    PRIMARY KEY (SearchID),
    CONSTRAINT FK_SearchAnalytics_Book FOREIGN KEY (ClickedBookID) REFERENCES Books(BookID)
);

-- ====================================
-- SYSTEM CONFIGURATION
-- ====================================

CREATE TABLE SystemConfig (
    ConfigKey VARCHAR(100) NOT NULL,
    ConfigValue TEXT(2000),
    Description VARCHAR(500),
    DataType VARCHAR(20) DEFAULT 'string', -- 'string', 'integer', 'boolean', 'json'
    LastModified TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (ConfigKey)
);

-- ====================================
-- PERFORMANCE INDEXES (MySQL Compatible)
-- ====================================

-- Books table indexes
CREATE INDEX idx_books_title ON Books(Title);
CREATE INDEX idx_books_author ON Books(Author);
CREATE INDEX idx_books_category ON Books(CategoryID);
CREATE INDEX idx_books_subject ON Books(SubjectID);
CREATE INDEX idx_books_date_added ON Books(DateAdded);
CREATE INDEX idx_books_confidence ON Books(OverallConfidence);
CREATE INDEX idx_books_active ON Books(IsActive);
CREATE INDEX idx_books_file_hash ON Books(FileHash);
CREATE INDEX idx_books_rating ON Books(Rating);
CREATE INDEX idx_books_publication_year ON Books(PublicationYear);

-- Classification performance indexes
CREATE INDEX idx_books_classification ON Books(CategoryID, SubjectID, OverallConfidence);
CREATE INDEX idx_categories_active ON Categories(IsActive, SortOrder);
CREATE INDEX idx_subjects_category ON Subjects(CategoryID, IsActive);

-- Relationship indexes
CREATE INDEX idx_relationships_book1 ON BookRelationships(BookID1, RelationshipType);
CREATE INDEX idx_relationships_book2 ON BookRelationships(BookID2, RelationshipType);
CREATE INDEX idx_relationships_strength ON BookRelationships(Strength);
CREATE INDEX idx_relationships_active ON BookRelationships(IsActive);

-- Analytics indexes
CREATE INDEX idx_analytics_book_date ON BookAnalytics(BookID, EventDate);
CREATE INDEX idx_analytics_event_date ON BookAnalytics(EventType, EventDate);
CREATE INDEX idx_analytics_session ON BookAnalytics(SessionID);
CREATE INDEX idx_search_query_date ON SearchAnalytics(SearchQuery, SearchDate);

-- LLM tracking indexes
CREATE INDEX idx_llm_book_date ON LLMClassifications(BookID, ClassificationDate);
CREATE INDEX idx_llm_model ON LLMClassifications(ModelName, ModelVersion);
CREATE INDEX idx_llm_accepted ON LLMClassifications(IsAccepted, ConfidenceScore);

-- Content search optimization
CREATE INDEX idx_content_extraction ON BookContent(ExtractionDate);
CREATE INDEX idx_search_indexed ON BookSearchIndex(IndexedDate);

-- ====================================
-- MYSQL FULLTEXT INDEXES
-- ====================================
-- These will be added during MySQL conversion

-- MySQL conversion tool should add:
-- ALTER TABLE BookSearchIndex ADD FULLTEXT(SearchableContent);
-- ALTER TABLE Books ADD FULLTEXT(Title, Author, Publisher);
-- ALTER TABLE BookContent ADD FULLTEXT(FirstPageText, TitlePageText, CopyrightPageText);

-- ====================================
-- COMPATIBILITY VIEWS
-- ====================================

-- Complete book information (MySQL compatible)
CREATE VIEW BookDetails AS
SELECT 
    b.BookID,
    b.FileName,
    b.Title,
    b.Author,
    b.Publisher,
    b.PublicationYear,
    c.CategoryName,
    s.SubjectName,
    b.CategoryConfidence,
    b.SubjectConfidence,
    b.OverallConfidence,
    b.FileSize,
    b.PageCount,
    b.Rating,
    b.ViewCount,
    b.DateAdded,
    b.CoverPath,
    b.ThumbnailPath,
    b.IsActive
FROM Books b
LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
LEFT JOIN Subjects s ON b.SubjectID = s.SubjectID;

-- High confidence classifications
CREATE VIEW HighConfidenceBooks AS
SELECT 
    bd.*,
    bc.FirstPageText,
    bc.ExtractedKeywords
FROM BookDetails bd
LEFT JOIN BookContent bc ON bd.BookID = bc.BookID
WHERE bd.OverallConfidence >= 0.8 AND bd.IsActive = 1;

-- Books needing review
CREATE VIEW BooksNeedingReview AS
SELECT 
    b.BookID,
    b.FileName,
    b.Title,
    b.Author,
    c.CategoryName,
    s.SubjectName,
    b.OverallConfidence,
    b.ProcessingFlags,
    lc.RawResponse as LastLLMResponse,
    lc.ClassificationDate as LastClassified
FROM Books b
LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
LEFT JOIN Subjects s ON b.SubjectID = s.SubjectID
LEFT JOIN LLMClassifications lc ON b.BookID = lc.BookID 
    AND lc.ClassificationID = (
        SELECT MAX(ClassificationID) 
        FROM LLMClassifications l2
        WHERE l2.BookID = b.BookID
    )
WHERE (b.OverallConfidence < 0.7 
    OR b.ProcessingFlags IS NOT NULL 
    OR b.CategoryID IS NULL)
    AND b.IsActive = 1;

-- ====================================
-- UPDATE TRIGGERS (MySQL Compatible)
-- ====================================

-- Update modified date trigger for Books
CREATE TRIGGER trg_books_update_modified
AFTER UPDATE ON Books
FOR EACH ROW
BEGIN
    UPDATE Books 
    SET DateModified = CURRENT_TIMESTAMP 
    WHERE BookID = NEW.BookID;
END;

-- Update modified date trigger for Categories
CREATE TRIGGER trg_categories_update_modified
AFTER UPDATE ON Categories
FOR EACH ROW
BEGIN
    UPDATE Categories 
    SET ModifiedDate = CURRENT_TIMESTAMP 
    WHERE CategoryID = NEW.CategoryID;
END;

-- Update modified date trigger for Subjects
CREATE TRIGGER trg_subjects_update_modified
AFTER UPDATE ON Subjects
FOR EACH ROW
BEGIN
    UPDATE Subjects 
    SET ModifiedDate = CURRENT_TIMESTAMP 
    WHERE SubjectID = NEW.SubjectID;
END;

-- ====================================
-- INITIAL DATA SETUP
-- ====================================

-- System configuration defaults
INSERT INTO SystemConfig (ConfigKey, ConfigValue, Description, DataType) VALUES
('database_version', '2.0.0', 'Database schema version', 'string'),
('created_date', datetime('now'), 'Database creation timestamp', 'string'),
('ai_enabled', 'true', 'AI classification features enabled', 'boolean'),
('search_engine', 'hybrid', 'Search engine type (fts5, fulltext, hybrid)', 'string'),
('backup_interval', '3600', 'Backup interval in seconds', 'integer'),
('max_file_size_mb', '500', 'Maximum book file size in MB', 'integer'),
('supported_formats', '["pdf"]', 'Supported file formats', 'json'),
('default_confidence_threshold', '0.7', 'Minimum confidence for auto-classification', 'string');

-- ====================================
-- MySQL CONVERSION NOTES
-- ====================================

/*
MYSQL CONVERSION CONSIDERATIONS:

1. AUTO_INCREMENT:
   - SQLite: INTEGER PRIMARY KEY (implicit autoincrement)
   - MySQL: Add AUTO_INCREMENT to INT PRIMARY KEY columns

2. BOOLEAN FIELDS:
   - Schema uses TINYINT(1) which converts cleanly
   - MySQL will recognize as BOOLEAN type

3. TIMESTAMPS:
   - Uses standard TIMESTAMP which works in both
   - CURRENT_TIMESTAMP is standard SQL

4. TEXT FIELD SIZES:
   - All TEXT fields sized to stay within MySQL row limits
   - Large content separated into dedicated tables
   - LONGTEXT used where needed

5. JSON FIELDS:
   - Sized as TEXT for SQLite compatibility
   - MySQL 8.0+ will handle JSON validation

6. FULLTEXT SEARCH:
   - SQLite uses FTS5 virtual table
   - MySQL uses FULLTEXT indexes (add during conversion)
   - BookSearchIndex table provides fallback

7. FOREIGN KEYS:
   - Explicitly named for better MySQL compatibility
   - Standard CASCADE/RESTRICT options

8. INDEXES:
   - All use standard SQL syntax
   - MySQL-specific optimizations can be added post-conversion

CONVERSION SCRIPT ADDITIONS NEEDED:
- Replace INTEGER PRIMARY KEY with INT AUTO_INCREMENT
- Add FULLTEXT indexes to search tables
- Convert FTS5 table to FULLTEXT indexes
- Adjust any SQLite-specific functions in triggers

MYSQL WORKBENCH BENEFITS:
- ER Diagrams for relationship visualization
- Query optimization tools
- Data modeling and validation
- Export to various formats
- Collaboration features
*/