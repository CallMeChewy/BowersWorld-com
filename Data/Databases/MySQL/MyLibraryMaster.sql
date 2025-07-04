-- ===============================================
-- POC MySQL Master Database - Production Ready
-- Core functionality for Anderson's Library
-- Standard: AIDEV-PascalCase-1.8
-- Author: Herb Bowers - Project Himalaya
-- ===============================================

-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS MyLibraryMaster
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE MyLibraryMaster;

-- =============================================
-- CORE TABLES - ESSENTIAL FUNCTIONALITY
-- =============================================

-- Authors Table - Normalized author management
CREATE TABLE Authors (
    AuthorID INTEGER NOT NULL AUTO_INCREMENT,
    AuthorName VARCHAR(300) NOT NULL,
    AuthorNameNormalized VARCHAR(300), -- For matching/deduplication
    
    -- Basic author info
    FirstName VARCHAR(100),
    LastName VARCHAR(100),
    
    -- Stats
    BookCount INTEGER DEFAULT 0,
    
    -- System fields
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (AuthorID),
    UNIQUE KEY UK_Authors_Normalized (AuthorNameNormalized),
    INDEX idx_authors_name (AuthorName(100)),
    INDEX idx_authors_active (IsActive)
);

-- Categories Table - Hierarchical organization
CREATE TABLE Categories (
    CategoryID INTEGER NOT NULL AUTO_INCREMENT,
    CategoryName VARCHAR(150) NOT NULL,
    ParentCategoryID INTEGER DEFAULT NULL,
    CategoryPath VARCHAR(500), -- "Programming/Python/Web Development"
    CategoryLevel INTEGER DEFAULT 1,
    
    -- Display
    Description TEXT,
    Color VARCHAR(7) DEFAULT '#4285f4',
    SortOrder INTEGER DEFAULT 0,
    
    -- Stats
    BookCount INTEGER DEFAULT 0,
    
    -- System fields
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (CategoryID),
    FOREIGN KEY (ParentCategoryID) REFERENCES Categories(CategoryID) ON DELETE SET NULL,
    UNIQUE KEY UK_Categories_Path (CategoryPath),
    INDEX idx_categories_parent (ParentCategoryID),
    INDEX idx_categories_level (CategoryLevel),
    INDEX idx_categories_active (IsActive)
);

-- Publishers Table - Normalize publishers
CREATE TABLE Publishers (
    PublisherID INTEGER NOT NULL AUTO_INCREMENT,
    PublisherName VARCHAR(200) NOT NULL,
    PublisherNameNormalized VARCHAR(200),
    
    -- Stats
    BookCount INTEGER DEFAULT 0,
    
    -- System fields
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (PublisherID),
    UNIQUE KEY UK_Publishers_Normalized (PublisherNameNormalized),
    INDEX idx_publishers_name (PublisherName),
    INDEX idx_publishers_active (IsActive)
);

-- Main Books Table - Core book data
CREATE TABLE Books (
    BookID INTEGER NOT NULL AUTO_INCREMENT,
    
    -- File Information
    FileName VARCHAR(255) NOT NULL,
    FilePath VARCHAR(1000), -- Full server path
    FileSize BIGINT,
    FileSizeMB DECIMAL(10,2),
    PageCount INTEGER,
    FileHash VARCHAR(128),
    
    -- Core Bibliographic Data
    Title VARCHAR(500) NOT NULL,
    Subtitle VARCHAR(500),
    AuthorID INTEGER,
    PublisherID INTEGER,
    CopyrightYear INTEGER,
    PublicationYear INTEGER,
    Edition VARCHAR(100),
    Language VARCHAR(50) DEFAULT 'English',
    
    -- Primary Category (single, for simplicity)
    CategoryID INTEGER,
    
    -- Identifiers (from Himalaya CSV)
    PrimaryISBN VARCHAR(20),
    ExtractedISBN VARCHAR(20),
    ExtractedLCCN VARCHAR(30),
    ExtractedISSN VARCHAR(20),
    ExtractedOCLC VARCHAR(30),
    ExtractedDOI VARCHAR(200),
    ExtractedPublisher VARCHAR(200),
    ExtractedYear INTEGER,
    
    -- Content Data (from Himalaya CSV)
    FirstPageText TEXT,
    TitlePageText TEXT,
    CopyrightPageText TEXT,
    ExtractedKeywords TEXT,
    
    -- Processing Info
    ProcessingDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ProcessingVersion VARCHAR(20),
    ExtractionMethod VARCHAR(50),
    QualityScore DECIMAL(4,2) DEFAULT 0.0,
    
    -- User Interaction (Aggregated)
    ViewCount INTEGER DEFAULT 0,
    DownloadCount INTEGER DEFAULT 0,
    AverageRating DECIMAL(3,2) DEFAULT 0.0,
    RatingCount INTEGER DEFAULT 0,
    
    -- Assets (Existence flags)
    HasCover BOOLEAN DEFAULT FALSE,
    HasThumbnail BOOLEAN DEFAULT FALSE,
    
    -- Access Control
    AccessLevel ENUM('public', 'members', 'premium', 'restricted') DEFAULT 'public',
    
    -- System Fields
    DateAdded TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    DateModified TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    LastAccessed TIMESTAMP NULL,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (BookID),
    FOREIGN KEY (AuthorID) REFERENCES Authors(AuthorID) ON DELETE SET NULL,
    FOREIGN KEY (PublisherID) REFERENCES Publishers(PublisherID) ON DELETE SET NULL,
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID) ON DELETE SET NULL,
    UNIQUE KEY UK_Books_FileName (FileName),
    
    -- Optimized indexes for common queries
    INDEX idx_books_title (Title(191)),
    INDEX idx_books_author (AuthorID),
    INDEX idx_books_publisher (PublisherID),
    INDEX idx_books_category (CategoryID),
    INDEX idx_books_year (PublicationYear),
    INDEX idx_books_isbn (PrimaryISBN),
    INDEX idx_books_rating (AverageRating),
    INDEX idx_books_downloads (DownloadCount),
    INDEX idx_books_access (AccessLevel),
    INDEX idx_books_active (IsActive),
    
    -- Search indexes
    INDEX idx_books_search_title (Title(100)),
    INDEX idx_books_search_keywords (ExtractedKeywords(100))
);

-- =============================================
-- SEARCH FUNCTIONALITY
-- =============================================

-- Full-Text Search Table
CREATE TABLE BookSearchIndex (
    BookID INTEGER NOT NULL,
    SearchableTitle TEXT,
    SearchableAuthor TEXT,
    SearchablePublisher TEXT,
    SearchableKeywords TEXT,
    SearchableContent TEXT,
    IndexedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    -- MySQL FULLTEXT indexes
    FULLTEXT INDEX ft_title (SearchableTitle),
    FULLTEXT INDEX ft_author (SearchableAuthor),
    FULLTEXT INDEX ft_keywords (SearchableKeywords),
    FULLTEXT INDEX ft_all_content (SearchableTitle, SearchableAuthor, SearchablePublisher, SearchableKeywords)
);

-- =============================================
-- BASIC USER SYSTEM
-- =============================================

-- Simple Users Table
CREATE TABLE Users (
    UserID VARCHAR(100) NOT NULL,
    Email VARCHAR(255) NOT NULL,
    DisplayName VARCHAR(100),
    
    -- Access Level
    AccessTier ENUM('basic', 'premium', 'admin') DEFAULT 'basic',
    DailyDownloadLimit INTEGER DEFAULT 3,
    
    -- Basic Stats
    TotalDownloads INTEGER DEFAULT 0,
    LastDownloadDate TIMESTAMP NULL,
    
    -- System Fields
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastLoginDate TIMESTAMP NULL,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (UserID),
    UNIQUE KEY UK_Users_Email (Email),
    INDEX idx_users_tier (AccessTier),
    INDEX idx_users_active (IsActive)
);

-- Simple Download Tracking
CREATE TABLE DownloadLogs (
    DownloadID INTEGER NOT NULL AUTO_INCREMENT,
    UserID VARCHAR(100) NULL, -- Can be anonymous
    BookID INTEGER NOT NULL,
    DownloadDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IPAddress VARCHAR(45),
    UserAgent VARCHAR(500),
    
    PRIMARY KEY (DownloadID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE SET NULL,
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    INDEX idx_downloads_book (BookID),
    INDEX idx_downloads_user (UserID),
    INDEX idx_downloads_date (DownloadDate)
);

-- =============================================
-- SQLITE GENERATION SYSTEM
-- =============================================

-- Schema Versions for SQLite Generation
CREATE TABLE SQLiteSchemaVersions (
    VersionID INTEGER NOT NULL AUTO_INCREMENT,
    VersionName VARCHAR(50) NOT NULL, -- 'public_v1', 'premium_v1'
    TargetAudience ENUM('public', 'members', 'premium') NOT NULL,
    Description TEXT,
    
    -- Generation settings
    IncludeFields JSON, -- Which fields to include
    FilterConditions TEXT, -- WHERE clause for data filtering
    
    -- Status
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (VersionID),
    UNIQUE KEY UK_Schema_Version (VersionName),
    INDEX idx_schema_audience (TargetAudience),
    INDEX idx_schema_active (IsActive)
);

-- Generated SQLite Database Tracking
CREATE TABLE SQLiteGeneration (
    GenerationID INTEGER NOT NULL AUTO_INCREMENT,
    VersionID INTEGER NOT NULL,
    GenerationDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Generation stats
    BooksIncluded INTEGER,
    FileSizeBytes BIGINT,
    GenerationDuration INTEGER, -- seconds
    
    -- File info
    OutputFileName VARCHAR(255),
    FileHash VARCHAR(128),
    
    -- Status
    GenerationStatus ENUM('processing', 'completed', 'failed') DEFAULT 'processing',
    ErrorMessage TEXT NULL,
    
    PRIMARY KEY (GenerationID),
    FOREIGN KEY (VersionID) REFERENCES SQLiteSchemaVersions(VersionID) ON DELETE CASCADE,
    INDEX idx_generation_version (VersionID),
    INDEX idx_generation_date (GenerationDate),
    INDEX idx_generation_status (GenerationStatus)
);

-- =============================================
-- ESSENTIAL VIEWS
-- =============================================

-- Book Details View - Primary view for displaying books
CREATE VIEW BookDetails AS
SELECT 
    b.BookID,
    b.FileName,
    b.Title,
    b.Subtitle,
    a.AuthorName,
    p.PublisherName,
    b.PublicationYear,
    b.CopyrightYear,
    b.Edition,
    b.Language,
    c.CategoryName,
    c.CategoryPath,
    b.PrimaryISBN,
    b.PageCount,
    b.FileSizeMB,
    b.AverageRating,
    b.RatingCount,
    b.DownloadCount,
    b.ViewCount,
    
    -- Asset paths (calculated)
    CASE WHEN b.HasCover = TRUE 
         THEN CONCAT('Covers/', REPLACE(b.FileName, '.pdf', '.png'))
         ELSE NULL END AS CoverPath,
    CASE WHEN b.HasThumbnail = TRUE 
         THEN CONCAT('Thumbs/', REPLACE(b.FileName, '.pdf', '.png'))
         ELSE NULL END AS ThumbnailPath,
         
    b.AccessLevel,
    b.DateAdded,
    b.IsActive
    
FROM Books b
LEFT JOIN Authors a ON b.AuthorID = a.AuthorID
LEFT JOIN Publishers p ON b.PublisherID = p.PublisherID
LEFT JOIN Categories c ON b.CategoryID = c.CategoryID;

-- Search View - Optimized for search operations
CREATE VIEW BookSearch AS
SELECT 
    bd.*,
    bsi.SearchableKeywords,
    MATCH(bsi.SearchableTitle, bsi.SearchableAuthor) AGAINST('') as SearchRelevance
FROM BookDetails bd
LEFT JOIN BookSearchIndex bsi ON bd.BookID = bsi.BookID
WHERE bd.IsActive = TRUE;

-- =============================================
-- STORED PROCEDURES
-- =============================================

DELIMITER //

-- Add or Find Author
CREATE PROCEDURE AddOrFindAuthor(
    IN p_AuthorName VARCHAR(300),
    OUT p_AuthorID INTEGER
)
BEGIN
    DECLARE normalized_name VARCHAR(300);
    
    -- Normalize author name
    SET normalized_name = UPPER(TRIM(REPLACE(p_AuthorName, '  ', ' ')));
    
    -- Try to find existing author
    SELECT AuthorID INTO p_AuthorID 
    FROM Authors 
    WHERE AuthorNameNormalized = normalized_name
    LIMIT 1;
    
    -- If not found, create new author
    IF p_AuthorID IS NULL THEN
        INSERT INTO Authors (AuthorName, AuthorNameNormalized)
        VALUES (p_AuthorName, normalized_name);
        SET p_AuthorID = LAST_INSERT_ID();
    END IF;
    
    -- Update book count
    UPDATE Authors 
    SET BookCount = (SELECT COUNT(*) FROM Books WHERE AuthorID = p_AuthorID)
    WHERE AuthorID = p_AuthorID;
    
END //

-- Add or Find Publisher
CREATE PROCEDURE AddOrFindPublisher(
    IN p_PublisherName VARCHAR(200),
    OUT p_PublisherID INTEGER
)
BEGIN
    DECLARE normalized_name VARCHAR(200);
    
    IF p_PublisherName IS NULL OR p_PublisherName = '' THEN
        SET p_PublisherID = NULL;
        LEAVE proc_exit;
    END IF;
    
    proc_exit: BEGIN END;
    
    -- Normalize publisher name
    SET normalized_name = UPPER(TRIM(p_PublisherName));
    
    -- Try to find existing publisher
    SELECT PublisherID INTO p_PublisherID 
    FROM Publishers 
    WHERE PublisherNameNormalized = normalized_name
    LIMIT 1;
    
    -- If not found, create new publisher
    IF p_PublisherID IS NULL THEN
        INSERT INTO Publishers (PublisherName, PublisherNameNormalized)
        VALUES (p_PublisherName, normalized_name);
        SET p_PublisherID = LAST_INSERT_ID();
    END IF;
    
    -- Update book count
    UPDATE Publishers 
    SET BookCount = (SELECT COUNT(*) FROM Books WHERE PublisherID = p_PublisherID)
    WHERE PublisherID = p_PublisherID;
    
END //

-- Add or Find Category by Path
CREATE PROCEDURE AddOrFindCategory(
    IN p_CategoryPath VARCHAR(500),
    OUT p_CategoryID INTEGER
)
BEGIN
    -- Try to find existing category
    SELECT CategoryID INTO p_CategoryID 
    FROM Categories 
    WHERE CategoryPath = p_CategoryPath
    LIMIT 1;
    
    -- If not found, create new category (simplified - assumes single level for POC)
    IF p_CategoryID IS NULL THEN
        INSERT INTO Categories (CategoryName, CategoryPath, CategoryLevel)
        VALUES (p_CategoryPath, p_CategoryPath, 1);
        SET p_CategoryID = LAST_INSERT_ID();
    END IF;
    
    -- Update book count
    UPDATE Categories 
    SET BookCount = (SELECT COUNT(*) FROM Books WHERE CategoryID = p_CategoryID)
    WHERE CategoryID = p_CategoryID;
    
END //

-- Update Search Index for Book
CREATE PROCEDURE UpdateBookSearchIndex(IN p_BookID INTEGER)
BEGIN
    DECLARE v_title TEXT;
    DECLARE v_author TEXT;
    DECLARE v_publisher TEXT;
    DECLARE v_keywords TEXT;
    DECLARE v_content TEXT;
    
    -- Get book data
    SELECT 
        b.Title,
        a.AuthorName,
        p.PublisherName,
        b.ExtractedKeywords,
        CONCAT_WS(' ', b.FirstPageText, b.TitlePageText, b.CopyrightPageText)
    INTO v_title, v_author, v_publisher, v_keywords, v_content
    FROM Books b
    LEFT JOIN Authors a ON b.AuthorID = a.AuthorID
    LEFT JOIN Publishers p ON b.PublisherID = p.PublisherID
    WHERE b.BookID = p_BookID;
    
    -- Update search index
    INSERT INTO BookSearchIndex (
        BookID, SearchableTitle, SearchableAuthor, SearchablePublisher, 
        SearchableKeywords, SearchableContent
    ) VALUES (
        p_BookID, v_title, v_author, v_publisher, v_keywords, v_content
    ) ON DUPLICATE KEY UPDATE
        SearchableTitle = v_title,
        SearchableAuthor = v_author,
        SearchablePublisher = v_publisher,
        SearchableKeywords = v_keywords,
        SearchableContent = v_content,
        IndexedDate = NOW();
        
END //

DELIMITER ;

-- =============================================
-- SAMPLE SQLITE SCHEMA VERSIONS
-- =============================================

-- Define SQLite schema versions
INSERT INTO SQLiteSchemaVersions (VersionName, TargetAudience, Description, IncludeFields, FilterConditions) VALUES
('public_lite_v1', 'public', 'Basic public access - essential book data only',
 '["BookID", "FileName", "Title", "AuthorName", "PublisherName", "PublicationYear", "CategoryName", "PrimaryISBN", "PageCount", "FileSizeMB", "HasCover", "HasThumbnail", "DateAdded"]',
 'AccessLevel IN (''public'') AND IsActive = TRUE'),

('members_v1', 'members', 'Member access - includes ratings and enhanced metadata',
 '["BookID", "FileName", "Title", "Subtitle", "AuthorName", "PublisherName", "PublicationYear", "Edition", "CategoryName", "PrimaryISBN", "PageCount", "FileSizeMB", "AverageRating", "RatingCount", "HasCover", "HasThumbnail", "ExtractedKeywords", "DateAdded"]',
 'AccessLevel IN (''public'', ''members'') AND IsActive = TRUE'),

('premium_v1', 'premium', 'Premium access - full metadata and analytics',
 '["BookID", "FileName", "Title", "Subtitle", "AuthorName", "PublisherName", "PublicationYear", "CopyrightYear", "Edition", "Language", "CategoryName", "PrimaryISBN", "ExtractedISBN", "ExtractedLCCN", "PageCount", "FileSizeMB", "AverageRating", "RatingCount", "DownloadCount", "HasCover", "HasThumbnail", "ExtractedKeywords", "FirstPageText", "DateAdded"]',
 'IsActive = TRUE');

/*
SIMPLIFIED POC FEATURES:

1. **Core Library Management**:
   - Books, Authors, Publishers, Categories
   - File management and metadata
   - Search functionality

2. **Basic User System**:
   - Simple user accounts
   - Download tracking
   - Access tiers (basic/premium/admin)

3. **SQLite Generation**:
   - Multiple schema versions for different user types
   - Automated generation and tracking
   - Configurable field inclusion/exclusion

4. **Search Capabilities**:
   - Full-text search with MySQL FULLTEXT
   - Keyword-based search
   - Category and author filtering

5. **Asset Management**:
   - Cover and thumbnail tracking
   - Calculated path generation
   - File existence flags

NEXT STEPS:
1. Create migration script from AndersonLibrary_Himalaya_GPU.csv
2. Build SQLite generation script
3. Create basic web interface
4. Test with your 1,219 books

This gives you a solid, working foundation that can be enhanced later with all the community features we brainstormed!
*/
