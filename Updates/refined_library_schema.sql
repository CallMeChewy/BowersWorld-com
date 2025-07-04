-- ===============================================
-- Refined Library Schema v3.0 - Core + Metadata Strategy
-- Separates core database from metadata enrichment
-- Standard: AIDEV-PascalCase-1.8
-- Author: Herb Bowers - Project Himalaya
-- ===============================================

-- =============================================
-- CORE LIBRARY TABLES (Lean and Fast)
-- =============================================

-- Authors Table - Normalized author data
CREATE TABLE Authors (
    AuthorID INTEGER PRIMARY KEY AUTOINCREMENT,
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
    CreatedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    IsActive INTEGER DEFAULT 1,
    
    CONSTRAINT UK_Authors_Normalized UNIQUE (AuthorNameNormalized)
);

-- Hierarchical Categories (Categories + Sub-categories in one table)
CREATE TABLE Categories (
    CategoryID INTEGER PRIMARY KEY AUTOINCREMENT,
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
    CreatedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    IsActive INTEGER DEFAULT 1,
    
    FOREIGN KEY (ParentCategoryID) REFERENCES Categories(CategoryID) ON DELETE SET NULL,
    CONSTRAINT UK_Categories_Path UNIQUE (CategoryPath)
);

-- Core Books Table - Essential data only
CREATE TABLE Books (
    BookID INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- File Information
    FileName VARCHAR(255) NOT NULL,
    FilePath VARCHAR(500),
    FileSize INTEGER,
    FileSizeMB REAL,
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
    ProcessingDate TEXT DEFAULT CURRENT_TIMESTAMP,
    ProcessingVersion VARCHAR(20),
    QualityScore REAL DEFAULT 0.0,
    
    -- User Interaction
    ViewCount INTEGER DEFAULT 0,
    Rating REAL DEFAULT 0.0,
    RatingCount INTEGER DEFAULT 0,
    Notes TEXT,
    
    -- System Fields
    DateAdded TEXT DEFAULT CURRENT_TIMESTAMP,
    DateModified TEXT DEFAULT CURRENT_TIMESTAMP,
    LastAccessed TEXT,
    IsActive INTEGER DEFAULT 1,
    
    CONSTRAINT UK_Books_FileName UNIQUE (FileName)
);

-- =============================================
-- RELATIONSHIP TABLES (Many-to-Many)
-- =============================================

-- Book-Author Relationships (Many-to-Many)
CREATE TABLE BookAuthors (
    BookID INTEGER NOT NULL,
    AuthorID INTEGER NOT NULL,
    AuthorRole VARCHAR(50) DEFAULT 'author', -- 'author', 'editor', 'translator', 'contributor'
    AuthorOrder INTEGER DEFAULT 1,           -- First author, second author, etc.
    
    PRIMARY KEY (BookID, AuthorID, AuthorRole),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (AuthorID) REFERENCES Authors(AuthorID) ON DELETE CASCADE
);

-- Book-Category Relationships (Many-to-Many)
CREATE TABLE BookCategories (
    BookID INTEGER NOT NULL,
    CategoryID INTEGER NOT NULL,
    IsPrimary INTEGER DEFAULT 0,    -- 1 = primary category, 0 = secondary
    Confidence REAL DEFAULT 1.0,   -- 0.0 to 1.0 classification confidence
    Source VARCHAR(20) DEFAULT 'manual', -- 'manual', 'ai', 'api', 'metadata'
    AssignedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID, CategoryID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID) ON DELETE CASCADE
);

-- =============================================
-- METADATA ENRICHMENT TABLES
-- =============================================

-- External Identifiers - For validation and API lookups
CREATE TABLE BookIdentifiers (
    BookID INTEGER NOT NULL,
    IdentifierType VARCHAR(20) NOT NULL, -- 'isbn', 'lccn', 'issn', 'oclc', 'doi', 'asin'
    IdentifierValue VARCHAR(200) NOT NULL,
    IsPrimary INTEGER DEFAULT 0,
    Source VARCHAR(50), -- 'extracted', 'api', 'manual'
    VerificationStatus VARCHAR(20) DEFAULT 'unverified', -- 'verified', 'invalid', 'conflicting'
    
    PRIMARY KEY (BookID, IdentifierType, IdentifierValue),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- API Metadata Cache - Store enriched data from external sources
CREATE TABLE ExternalMetadata (
    BookID INTEGER NOT NULL,
    Source VARCHAR(50) NOT NULL,        -- 'openlibrary', 'googlebooks', 'worldcat'
    SourceIdentifier VARCHAR(100),      -- Their internal ID
    MetadataJSON TEXT,                  -- Full JSON response
    LastUpdated TEXT DEFAULT CURRENT_TIMESTAMP,
    ValidationStatus VARCHAR(20) DEFAULT 'pending',
    
    PRIMARY KEY (BookID, Source),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- Content Extraction - Text content for search
CREATE TABLE BookContent (
    BookID INTEGER PRIMARY KEY,
    FirstPageText TEXT,
    TableOfContents TEXT,
    ExtractedKeywords TEXT,
    ContentLanguage VARCHAR(20),
    ExtractionDate TEXT DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- =============================================
-- ASSET MANAGEMENT
-- =============================================

-- Book Assets - Covers, thumbnails (calculated paths)
CREATE TABLE BookAssets (
    AssetID INTEGER PRIMARY KEY AUTOINCREMENT,
    BookID INTEGER NOT NULL,
    AssetType VARCHAR(20) NOT NULL CHECK (AssetType IN ('cover', 'thumbnail', 'preview')),
    AssetFormat VARCHAR(10) NOT NULL,
    
    -- Calculated path: Covers/{filename}.png, Thumbs/{filename}.png
    -- No need to store path, just track existence
    Width INTEGER,
    Height INTEGER,
    FileSize INTEGER,
    Quality REAL,
    
    CreatedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    IsActive INTEGER DEFAULT 1,
    
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    CONSTRAINT UK_BookAssets_Type UNIQUE (BookID, AssetType)
);

-- =============================================
-- AI CLASSIFICATION SYSTEM
-- =============================================

-- Classification Attempts - Track AI suggestions
CREATE TABLE ClassificationAttempts (
    AttemptID INTEGER PRIMARY KEY AUTOINCREMENT,
    BookID INTEGER NOT NULL,
    ModelName VARCHAR(100) NOT NULL,
    InputData TEXT,              -- What we sent to the AI
    SuggestedCategories TEXT,    -- JSON array of suggested CategoryIDs with confidence
    RawResponse TEXT,
    ProcessingTime REAL,
    AttemptDate TEXT DEFAULT CURRENT_TIMESTAMP,
    WasAccepted INTEGER DEFAULT 0,
    
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- =============================================
-- SEARCH AND PERFORMANCE
-- =============================================

-- Search Index Table (fallback for no FTS5)
CREATE TABLE BookSearchIndex (
    BookID INTEGER PRIMARY KEY,
    SearchableTitle TEXT,
    SearchableAuthors TEXT,
    SearchableCategories TEXT,
    SearchableKeywords TEXT,
    IndexedDate TEXT DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE
);

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

-- Authors indexes
CREATE INDEX idx_authors_name ON Authors(AuthorName);
CREATE INDEX idx_authors_normalized ON Authors(AuthorNameNormalized);
CREATE INDEX idx_authors_last ON Authors(LastName);

-- Categories indexes
CREATE INDEX idx_categories_parent ON Categories(ParentCategoryID);
CREATE INDEX idx_categories_level ON Categories(CategoryLevel);
CREATE INDEX idx_categories_path ON Categories(CategoryPath);

-- Books indexes  
CREATE INDEX idx_books_title ON Books(Title);
CREATE INDEX idx_books_year ON Books(PublicationYear);
CREATE INDEX idx_books_isbn ON Books(PrimaryISBN);
CREATE INDEX idx_books_rating ON Books(Rating);

-- Relationship indexes
CREATE INDEX idx_bookauthors_author ON BookAuthors(AuthorID);
CREATE INDEX idx_bookauthors_role ON BookAuthors(AuthorRole);
CREATE INDEX idx_bookcategories_category ON BookCategories(CategoryID);
CREATE INDEX idx_bookcategories_primary ON BookCategories(IsPrimary);

-- Metadata indexes
CREATE INDEX idx_identifiers_type_value ON BookIdentifiers(IdentifierType, IdentifierValue);
CREATE INDEX idx_external_source ON ExternalMetadata(Source);

-- Search indexes
CREATE INDEX idx_search_title ON BookSearchIndex(SearchableTitle);
CREATE INDEX idx_search_authors ON BookSearchIndex(SearchableAuthors);

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
    
    -- Primary Author
    a.AuthorName AS PrimaryAuthor,
    
    -- Primary Category Path
    c.CategoryPath AS PrimaryCategory,
    
    -- Asset paths (calculated)
    CASE WHEN ca.AssetID IS NOT NULL 
         THEN 'Covers/' || REPLACE(b.FileName, '.pdf', '.png')
         ELSE NULL END AS CoverPath,
    CASE WHEN ta.AssetID IS NOT NULL 
         THEN 'Thumbs/' || REPLACE(b.FileName, '.pdf', '.png')
         ELSE NULL END AS ThumbnailPath,
         
    b.DateAdded,
    b.IsActive
    
FROM Books b
LEFT JOIN BookAuthors ba ON b.BookID = ba.BookID AND ba.AuthorOrder = 1
LEFT JOIN Authors a ON ba.AuthorID = a.AuthorID
LEFT JOIN BookCategories bc ON b.BookID = bc.BookID AND bc.IsPrimary = 1
LEFT JOIN Categories c ON bc.CategoryID = c.CategoryID
LEFT JOIN BookAssets ca ON b.BookID = ca.BookID AND ca.AssetType = 'cover'
LEFT JOIN BookAssets ta ON b.BookID = ta.BookID AND ta.AssetType = 'thumbnail';

-- All Authors for a Book
CREATE VIEW BookAuthorsView AS
SELECT 
    b.BookID,
    b.Title,
    GROUP_CONCAT(a.AuthorName, '; ') AS AllAuthors,
    COUNT(a.AuthorID) AS AuthorCount
FROM Books b
LEFT JOIN BookAuthors ba ON b.BookID = ba.BookID
LEFT JOIN Authors a ON ba.AuthorID = a.AuthorID
GROUP BY b.BookID, b.Title;

-- All Categories for a Book  
CREATE VIEW BookCategoriesView AS
SELECT 
    b.BookID,
    b.Title,
    GROUP_CONCAT(c.CategoryPath, '; ') AS AllCategories,
    COUNT(c.CategoryID) AS CategoryCount
FROM Books b
LEFT JOIN BookCategories bc ON b.BookID = bc.BookID
LEFT JOIN Categories c ON bc.CategoryID = c.CategoryID
GROUP BY b.BookID, b.Title;

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

-- Maintain CategoryPath when categories change
CREATE TRIGGER tr_categories_path_update
AFTER UPDATE ON Categories
FOR EACH ROW
WHEN NEW.CategoryName != OLD.CategoryName OR NEW.ParentCategoryID != OLD.ParentCategoryID
BEGIN
    -- Would need a function to rebuild CategoryPath
    UPDATE Categories SET ModifiedDate = CURRENT_TIMESTAMP WHERE CategoryID = NEW.CategoryID;
END;

-- =============================================
-- DATA STRATEGY NOTES
-- =============================================

/*
CORE DATABASE PHILOSOPHY:
- Store only what you query frequently
- Normalize for performance and integrity
- Many-to-many for flexible relationships
- Calculate paths dynamically

METADATA ENRICHMENT STRATEGY:
- Use CSV data for external validation
- Cache API responses in ExternalMetadata
- Track all identifiers for cross-referencing
- Verify data conflicts automatically

CLASSIFICATION APPROACH:
- Hierarchical categories (Programming > Python > Web)
- Multiple categories per book
- AI suggestions tracked but not auto-applied
- Manual override always possible

AUTHOR HANDLING:
- Normalized author table
- Handle multiple authors per book
- Support different roles (author, editor, etc.)
- Enable author-based searching

EXAMPLE CATEGORY HIERARCHY:
- Programming (Level 1)
  ├── Python (Level 2) 
  │   ├── Web Development (Level 3)
  │   └── Data Science (Level 3)
  └── JavaScript (Level 2)
      └── Frontend (Level 3)

EXAMPLE QUERIES:
-- Find all Python books
SELECT * FROM BookDetails bd
JOIN BookCategories bc ON bd.BookID = bc.BookID  
JOIN Categories c ON bc.CategoryID = c.CategoryID
WHERE c.CategoryPath LIKE '%Python%';

-- Find books by author
SELECT * FROM BookDetails bd
JOIN BookAuthors ba ON bd.BookID = ba.BookID
JOIN Authors a ON ba.AuthorID = a.AuthorID  
WHERE a.AuthorName LIKE '%O''Reilly%';

-- Validate ISBN against external sources
SELECT bi.IdentifierValue, em.Source, em.ValidationStatus
FROM BookIdentifiers bi
JOIN ExternalMetadata em ON bi.BookID = em.BookID
WHERE bi.IdentifierType = 'isbn';
*/