-- ===============================================
-- Enhanced MyLibrary Schema v3.0 - MySQL Lean Design
-- Core + Metadata Strategy with Key Length Solutions
-- Standard: AIDEV-PascalCase-1.8
-- Author: Herb Bowers - Project Himalaya
-- ===============================================

-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS MyLibrary
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

-- Use the database
USE MyLibrary;

-- Set MySQL specific settings for optimal performance
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';
SET innodb_strict_mode = 1;

-- =============================================
-- CORE LIBRARY TABLES (Lean and Fast)
-- =============================================

-- Authors Table - Normalized author data
CREATE TABLE Authors (
    AuthorID INTEGER NOT NULL AUTO_INCREMENT,
    AuthorName VARCHAR(200) NOT NULL,
    AuthorNameNormalized VARCHAR(200), -- For matching/deduplication
    FirstName VARCHAR(100),
    LastName VARCHAR(100),
    MiddleNames VARCHAR(100),
    
    -- Author metadata (optional)
    Biography TEXT,
    BirthYear INTEGER,
    DeathYear INTEGER,
    Nationality VARCHAR(100),
    
    -- System fields
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (AuthorID),
    CONSTRAINT UK_Authors_Normalized UNIQUE (AuthorNameNormalized),
    
    -- Optimized indexes
    INDEX idx_authors_name (AuthorName(100)),        -- Prefix index for performance
    INDEX idx_authors_last (LastName),
    INDEX idx_authors_normalized (AuthorNameNormalized),
    INDEX idx_authors_active (IsActive)
);

-- Hierarchical Categories (Categories + Sub-categories in one table)
CREATE TABLE Categories (
    CategoryID INTEGER NOT NULL AUTO_INCREMENT,
    CategoryName VARCHAR(150) NOT NULL,
    ParentCategoryID INTEGER DEFAULT NULL,  -- NULL = top-level category
    CategoryLevel INTEGER DEFAULT 1,        -- 1=category, 2=subcategory, 3=sub-sub, etc.
    CategoryPath VARCHAR(500),              -- "Programming/Python/Web Development"
    
    -- Display attributes
    Description TEXT,
    Color VARCHAR(7) DEFAULT '#4285f4',
    IconName VARCHAR(50),
    SortOrder INTEGER DEFAULT 0,
    
    -- System fields
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (CategoryID),
    FOREIGN KEY (ParentCategoryID) REFERENCES Categories(CategoryID) ON DELETE SET NULL,
    CONSTRAINT UK_Categories_Path UNIQUE (CategoryPath),
    
    -- Optimized indexes
    INDEX idx_categories_parent (ParentCategoryID),
    INDEX idx_categories_level (CategoryLevel),
    INDEX idx_categories_path (CategoryPath(191)),   -- Prefix index for long paths
    INDEX idx_categories_name (CategoryName),
    INDEX idx_categories_active (IsActive),
    INDEX idx_categories_sort (ParentCategoryID, SortOrder)
);

-- Core Books Table - Essential data only
CREATE TABLE Books (
    BookID INTEGER NOT NULL AUTO_INCREMENT,
    
    -- File Information
    FileName VARCHAR(255) NOT NULL,
    FilePath VARCHAR(500),
    FileSize BIGINT,
    FileSizeMB DECIMAL(10,2),
    PageCount INTEGER,
    FileHash VARCHAR(64),
    
    -- Core Bibliographic Data
    Title VARCHAR(500) NOT NULL,
    Subtitle VARCHAR(500),
    Publisher VARCHAR(200),
    PublicationYear INTEGER,
    Edition VARCHAR(100),
    Language VARCHAR(50) DEFAULT 'English',
    
    -- Primary ISBN (most important one)
    PrimaryISBN VARCHAR(20),
    
    -- Quality and Processing
    ProcessingDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ProcessingVersion VARCHAR(20),
    QualityScore DECIMAL(4,2) DEFAULT 0.0,
    
    -- User Interaction
    ViewCount INTEGER DEFAULT 0,
    Rating DECIMAL(3,2) DEFAULT 0.0,
    RatingCount INTEGER DEFAULT 0,
    Notes TEXT,
    
    -- System Fields
    DateAdded TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    DateModified TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    LastAccessed TIMESTAMP NULL,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (BookID),
    CONSTRAINT UK_Books_FileName UNIQUE (FileName),
    
    -- Optimized indexes (MySQL key length compliant)
    INDEX idx_books_title (Title(191)),              -- Prefix index for long titles
    INDEX idx_books_publisher (Publisher),
    INDEX idx_books_year (PublicationYear),
    INDEX idx_books_isbn (PrimaryISBN),
    INDEX idx_books_language (Language),
    INDEX idx_books_rating (Rating),
    INDEX idx_books_active (IsActive),
    INDEX idx_books_quality (QualityScore),
    INDEX idx_books_date (DateAdded),
    
    -- Composite indexes (carefully sized)
    INDEX idx_books_year_rating (PublicationYear, Rating),
    INDEX idx_books_active_rating (IsActive, Rating),
    INDEX idx_books_language_year (Language, PublicationYear)
);

-- =============================================
-- RELATIONSHIP TABLES (Many-to-Many)
-- =============================================

-- Book-Author Relationships (Many-to-Many)
CREATE TABLE BookAuthors (
    BookID INTEGER NOT NULL,
    AuthorID INTEGER NOT NULL,
    AuthorRole ENUM('author', 'editor', 'translator', 'contributor', 'illustrator') DEFAULT 'author',
    AuthorOrder INTEGER DEFAULT 1,           -- First author, second author, etc.
    
    PRIMARY KEY (BookID, AuthorID, AuthorRole),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (AuthorID) REFERENCES Authors(AuthorID) ON DELETE CASCADE,
    
    INDEX idx_bookauthors_author (AuthorID),
    INDEX idx_bookauthors_role (AuthorRole),
    INDEX idx_bookauthors_order (BookID, AuthorOrder)
);

-- Book-Category Relationships (Many-to-Many)
CREATE TABLE BookCategories (
    BookID INTEGER NOT NULL,
    CategoryID INTEGER NOT NULL,
    IsPrimary BOOLEAN DEFAULT FALSE,        -- TRUE = primary category, FALSE = secondary
    Confidence DECIMAL(3,2) DEFAULT 1.0,   -- 0.0 to 1.0 classification confidence
    Source ENUM('manual', 'ai', 'api', 'metadata') DEFAULT 'manual',
    AssignedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID, CategoryID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID) ON DELETE CASCADE,
    
    INDEX idx_bookcategories_category (CategoryID),
    INDEX idx_bookcategories_primary (IsPrimary),
    INDEX idx_bookcategories_source (Source),
    INDEX idx_bookcategories_confidence (Confidence)
);

-- =============================================
-- METADATA ENRICHMENT TABLES
-- =============================================

-- External Identifiers - For validation and API lookups
CREATE TABLE BookIdentifiers (
    BookID INTEGER NOT NULL,
    IdentifierType ENUM('isbn', 'isbn13', 'lccn', 'issn', 'oclc', 'doi', 'asin', 'goodreads') NOT NULL,
    IdentifierValue VARCHAR(200) NOT NULL,
    IsPrimary BOOLEAN DEFAULT FALSE,
    Source VARCHAR(50), -- 'extracted', 'api', 'manual'
    VerificationStatus ENUM('unverified', 'verified', 'invalid', 'conflicting') DEFAULT 'unverified',
    
    PRIMARY KEY (BookID, IdentifierType, IdentifierValue),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    INDEX idx_identifiers_type_value (IdentifierType, IdentifierValue),
    INDEX idx_identifiers_primary (IsPrimary),
    INDEX idx_identifiers_status (VerificationStatus)
);

-- API Metadata Cache - Store enriched data from external sources
CREATE TABLE ExternalMetadata (
    BookID INTEGER NOT NULL,
    Source VARCHAR(50) NOT NULL,           -- 'openlibrary', 'googlebooks', 'worldcat'
    SourceIdentifier VARCHAR(100),         -- Their internal ID
    MetadataJSON JSON,                     -- Full JSON response (MySQL JSON type)
    LastUpdated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ValidationStatus ENUM('pending', 'validated', 'failed', 'conflicting') DEFAULT 'pending',
    
    PRIMARY KEY (BookID, Source),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    INDEX idx_external_source (Source),
    INDEX idx_external_status (ValidationStatus),
    INDEX idx_external_updated (LastUpdated)
);

-- Content Extraction - Text content for search
CREATE TABLE BookContent (
    BookID INTEGER NOT NULL,
    FirstPageText TEXT,
    TableOfContents TEXT,
    ExtractedKeywords TEXT,
    ContentLanguage VARCHAR(20),
    ExtractionDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- =============================================
-- ASSET MANAGEMENT
-- =============================================

-- Book Assets - Covers, thumbnails (calculated paths)
CREATE TABLE BookAssets (
    AssetID INTEGER NOT NULL AUTO_INCREMENT,
    BookID INTEGER NOT NULL,
    AssetType ENUM('cover', 'thumbnail', 'preview', 'excerpt') NOT NULL,
    AssetFormat VARCHAR(10) NOT NULL,       -- png, jpg, pdf, etc.
    
    -- Calculated path: Covers/{filename}.png, Thumbs/{filename}.png
    -- No need to store path, just track existence and metadata
    Width INTEGER,
    Height INTEGER,
    FileSize INTEGER,
    Quality DECIMAL(3,2),
    
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (AssetID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    CONSTRAINT UK_BookAssets_Type UNIQUE (BookID, AssetType),
    
    INDEX idx_assets_book (BookID),
    INDEX idx_assets_type (AssetType),
    INDEX idx_assets_active (IsActive)
);

-- =============================================
-- AI CLASSIFICATION SYSTEM
-- =============================================

-- Classification Attempts - Track AI suggestions
CREATE TABLE ClassificationAttempts (
    AttemptID INTEGER NOT NULL AUTO_INCREMENT,
    BookID INTEGER NOT NULL,
    ModelName VARCHAR(100) NOT NULL,
    ModelVersion VARCHAR(50),
    InputData TEXT,                         -- What we sent to the AI
    SuggestedCategories JSON,               -- Array of CategoryIDs with confidence scores
    RawResponse TEXT,
    ProcessingTime DECIMAL(8,3),
    TokensUsed INTEGER,
    AttemptDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    WasAccepted BOOLEAN DEFAULT FALSE,
    
    PRIMARY KEY (AttemptID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    INDEX idx_classification_book (BookID),
    INDEX idx_classification_model (ModelName, ModelVersion),
    INDEX idx_classification_accepted (WasAccepted),
    INDEX idx_classification_date (AttemptDate)
);

-- =============================================
-- SEARCH AND PERFORMANCE
-- =============================================

-- Full-Text Search Table (MySQL FULLTEXT compatible)
CREATE TABLE BookSearchIndex (
    BookID INTEGER NOT NULL,
    SearchableTitle TEXT,
    SearchableAuthors TEXT,
    SearchableCategories TEXT,
    SearchableKeywords TEXT,
    SearchableContent TEXT,
    IndexedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    -- MySQL FULLTEXT indexes (optimized for search performance)
    FULLTEXT INDEX ft_title (SearchableTitle),
    FULLTEXT INDEX ft_authors (SearchableAuthors),
    FULLTEXT INDEX ft_categories (SearchableCategories),
    FULLTEXT INDEX ft_keywords (SearchableKeywords),
    FULLTEXT INDEX ft_content (SearchableContent),
    FULLTEXT INDEX ft_all (SearchableTitle, SearchableAuthors, SearchableCategories, SearchableKeywords)
);

-- =============================================
-- ANALYTICS AND TRACKING
-- =============================================

-- Book Analytics - Track user interactions
CREATE TABLE BookAnalytics (
    AnalyticsID INTEGER NOT NULL AUTO_INCREMENT,
    BookID INTEGER NOT NULL,
    EventType VARCHAR(50) NOT NULL,        -- 'view', 'download', 'search', 'rate'
    EventData JSON,                        -- MySQL JSON data type
    UserAgent VARCHAR(500),
    IPAddress VARCHAR(45),
    EventDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (AnalyticsID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    INDEX idx_analytics_book (BookID),
    INDEX idx_analytics_event (EventType),
    INDEX idx_analytics_date (EventDate),
    INDEX idx_analytics_book_event (BookID, EventType)
);

-- =============================================
-- VIEWS FOR COMMON OPERATIONS
-- =============================================

-- Book Details with Primary Author and Category
CREATE VIEW BookDetails AS
SELECT 
    b.BookID,
    b.FileName,
    b.Title,
    b.Subtitle,
    b.Publisher,
    b.PublicationYear,
    b.PrimaryISBN,
    b.Language,
    b.PageCount,
    b.FileSizeMB,
    b.Rating,
    b.ViewCount,
    b.QualityScore,
    
    -- Primary Author (first author)
    a.AuthorName AS PrimaryAuthor,
    ba.AuthorRole AS PrimaryAuthorRole,
    
    -- Primary Category Path
    c.CategoryPath AS PrimaryCategory,
    c.CategoryLevel AS CategoryLevel,
    
    -- Asset paths (calculated dynamically)
    CASE WHEN ca.AssetID IS NOT NULL 
         THEN CONCAT('Covers/', REPLACE(b.FileName, '.pdf', '.png'))
         ELSE NULL END AS CoverPath,
    CASE WHEN ta.AssetID IS NOT NULL 
         THEN CONCAT('Thumbs/', REPLACE(b.FileName, '.pdf', '.png'))
         ELSE NULL END AS ThumbnailPath,
         
    b.DateAdded,
    b.IsActive
    
FROM Books b
LEFT JOIN BookAuthors ba ON b.BookID = ba.BookID AND ba.AuthorOrder = 1
LEFT JOIN Authors a ON ba.AuthorID = a.AuthorID
LEFT JOIN BookCategories bc ON b.BookID = bc.BookID AND bc.IsPrimary = TRUE
LEFT JOIN Categories c ON bc.CategoryID = c.CategoryID
LEFT JOIN BookAssets ca ON b.BookID = ca.BookID AND ca.AssetType = 'cover' AND ca.IsActive = TRUE
LEFT JOIN BookAssets ta ON b.BookID = ta.BookID AND ta.AssetType = 'thumbnail' AND ta.IsActive = TRUE;

-- All Authors for a Book (MySQL GROUP_CONCAT)
CREATE VIEW BookAuthorsView AS
SELECT 
    b.BookID,
    b.Title,
    GROUP_CONCAT(
        CONCAT(a.AuthorName, ' (', ba.AuthorRole, ')') 
        ORDER BY ba.AuthorOrder 
        SEPARATOR '; '
    ) AS AllAuthors,
    COUNT(a.AuthorID) AS AuthorCount
FROM Books b
LEFT JOIN BookAuthors ba ON b.BookID = ba.BookID
LEFT JOIN Authors a ON ba.AuthorID = a.AuthorID
WHERE b.IsActive = TRUE
GROUP BY b.BookID, b.Title;

-- All Categories for a Book
CREATE VIEW BookCategoriesView AS
SELECT 
    b.BookID,
    b.Title,
    GROUP_CONCAT(
        CONCAT(c.CategoryPath, IF(bc.IsPrimary, ' (Primary)', ''))
        ORDER BY bc.IsPrimary DESC, c.CategoryPath
        SEPARATOR '; '
    ) AS AllCategories,
    COUNT(c.CategoryID) AS CategoryCount
FROM Books b
LEFT JOIN BookCategories bc ON b.BookID = bc.BookID
LEFT JOIN Categories c ON bc.CategoryID = c.CategoryID
WHERE b.IsActive = TRUE
GROUP BY b.BookID, b.Title;

-- Category Hierarchy View
CREATE VIEW CategoryHierarchy AS
SELECT 
    c1.CategoryID,
    c1.CategoryName,
    c1.CategoryLevel,
    c1.CategoryPath,
    c1.ParentCategoryID,
    c2.CategoryName AS ParentCategoryName,
    (SELECT COUNT(*) FROM BookCategories bc WHERE bc.CategoryID = c1.CategoryID) AS BookCount
FROM Categories c1
LEFT JOIN Categories c2 ON c1.ParentCategoryID = c2.CategoryID
WHERE c1.IsActive = TRUE
ORDER BY c1.CategoryPath;

-- =============================================
-- STORED PROCEDURES FOR COMMON OPERATIONS
-- =============================================

DELIMITER //

-- Add or Update Author
CREATE PROCEDURE AddOrUpdateAuthor(
    IN p_AuthorName VARCHAR(200),
    IN p_FirstName VARCHAR(100),
    IN p_LastName VARCHAR(100),
    OUT p_AuthorID INTEGER
)
BEGIN
    DECLARE author_exists INT DEFAULT 0;
    DECLARE normalized_name VARCHAR(200);
    
    -- Normalize author name for matching
    SET normalized_name = UPPER(TRIM(p_AuthorName));
    
    -- Check if author exists
    SELECT AuthorID INTO p_AuthorID 
    FROM Authors 
    WHERE AuthorNameNormalized = normalized_name
    LIMIT 1;
    
    -- If not exists, create new author
    IF p_AuthorID IS NULL THEN
        INSERT INTO Authors (AuthorName, AuthorNameNormalized, FirstName, LastName)
        VALUES (p_AuthorName, normalized_name, p_FirstName, p_LastName);
        SET p_AuthorID = LAST_INSERT_ID();
    END IF;
END //

-- Add Category to Hierarchy
CREATE PROCEDURE AddCategoryToHierarchy(
    IN p_CategoryName VARCHAR(150),
    IN p_ParentCategoryID INTEGER,
    OUT p_CategoryID INTEGER
)
BEGIN
    DECLARE parent_path VARCHAR(500) DEFAULT '';
    DECLARE new_path VARCHAR(500);
    DECLARE new_level INTEGER DEFAULT 1;
    
    -- Get parent path and level if parent exists
    IF p_ParentCategoryID IS NOT NULL THEN
        SELECT CategoryPath, CategoryLevel + 1 
        INTO parent_path, new_level
        FROM Categories 
        WHERE CategoryID = p_ParentCategoryID;
        
        SET new_path = CONCAT(parent_path, '/', p_CategoryName);
    ELSE
        SET new_path = p_CategoryName;
    END IF;
    
    -- Insert new category
    INSERT INTO Categories (CategoryName, ParentCategoryID, CategoryLevel, CategoryPath)
    VALUES (p_CategoryName, p_ParentCategoryID, new_level, new_path);
    
    SET p_CategoryID = LAST_INSERT_ID();
END //

DELIMITER ;

-- =============================================
-- MYSQL OPTIMIZATION NOTES
-- =============================================

/*
KEY LENGTH SOLUTIONS IMPLEMENTED:
1. Prefix indexes: Title(191), CategoryPath(191), AuthorName(100)
2. Strategic use of ENUM instead of VARCHAR for constrained values
3. Separate indexes instead of large composite indexes
4. FULLTEXT indexes for advanced search capabilities

MYSQL-SPECIFIC FEATURES USED:
1. JSON data type for structured data (EventData, MetadataJSON, SuggestedCategories)
2. ENUM data types for constrained values (roles, statuses, types)
3. FULLTEXT indexes for advanced search
4. BOOLEAN data type
5. ON UPDATE CURRENT_TIMESTAMP triggers
6. AUTO_INCREMENT (MySQL syntax)
7. Stored procedures for complex operations

PERFORMANCE OPTIMIZATIONS:
1. Strategic indexing for common query patterns
2. Views for complex joins
3. Separate tables for heavy/infrequent data
4. Proper foreign key relationships with cascading

SEARCH CAPABILITIES:
1. FULLTEXT search: SELECT * FROM BookSearchIndex WHERE MATCH(SearchableTitle, SearchableAuthors) AGAINST('python programming' IN NATURAL LANGUAGE MODE)
2. Category hierarchy: Find all books in Python or sub-categories
3. Author search: Find all books by or edited by specific authors
4. Metadata validation: Cross-reference identifiers with external sources

PATH CALCULATION STRATEGY:
- Cover: CONCAT('Covers/', REPLACE(FileName, '.pdf', '.png'))
- Thumbnail: CONCAT('Thumbs/', REPLACE(FileName, '.pdf', '.png'))
- Book: CONCAT('Books/', FileName)

EXAMPLE QUERIES:
-- Find all Python books (any level in hierarchy)
SELECT bd.* FROM BookDetails bd
JOIN BookCategories bc ON bd.BookID = bc.BookID
JOIN Categories c ON bc.CategoryID = c.CategoryID
WHERE c.CategoryPath LIKE '%Python%';

-- Find books by O'Reilly (author or publisher)
SELECT bd.* FROM BookDetails bd
LEFT JOIN BookAuthorsView bav ON bd.BookID = bav.BookID
WHERE bav.AllAuthors LIKE '%O''Reilly%' OR bd.Publisher LIKE '%O''Reilly%';

-- Advanced search with ranking
SELECT bd.*, MATCH(bsi.SearchableTitle, bsi.SearchableAuthors) AGAINST('machine learning' IN NATURAL LANGUAGE MODE) as relevance
FROM BookDetails bd
JOIN BookSearchIndex bsi ON bd.BookID = bsi.BookID
WHERE MATCH(bsi.SearchableTitle, bsi.SearchableAuthors) AGAINST('machine learning' IN NATURAL LANGUAGE MODE)
ORDER BY relevance DESC;
*/
