-- ===============================================
-- MySQL Master Schema - Library Intelligence System
-- Comprehensive tracking, metrics, and contributor management
-- Standard: AIDEV-PascalCase-1.8
-- Author: Herb Bowers - Project Himalaya
-- ===============================================

-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS MyLibrary_Master 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE MyLibrary_Master;

-- =============================================
-- CONTRIBUTOR & SOURCE MANAGEMENT
-- =============================================

-- Contributors - People who add/improve library content
CREATE TABLE Contributors (
    ContributorID INTEGER NOT NULL AUTO_INCREMENT,
    ContributorName VARCHAR(200) NOT NULL,
    Email VARCHAR(255),
    ContributorType ENUM('admin', 'librarian', 'volunteer', 'ai_system', 'api_source') NOT NULL,
    
    -- Reputation & Stats
    BooksContributed INTEGER DEFAULT 0,
    MetadataContributed INTEGER DEFAULT 0,
    ClassificationsContributed INTEGER DEFAULT 0,
    AccuracyScore DECIMAL(4,3) DEFAULT 1.0,  -- 0.0 to 1.0
    ReputationPoints INTEGER DEFAULT 0,
    
    -- Access Control
    PermissionLevel ENUM('read', 'contribute', 'moderate', 'admin') DEFAULT 'contribute',
    IsActive BOOLEAN DEFAULT TRUE,
    JoinDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastActivity TIMESTAMP NULL,
    
    PRIMARY KEY (ContributorID),
    CONSTRAINT UK_Contributors_Email UNIQUE (Email),
    INDEX idx_contributors_type (ContributorType),
    INDEX idx_contributors_reputation (ReputationPoints),
    INDEX idx_contributors_accuracy (AccuracyScore)
);

-- Data Sources - External APIs, databases, manual entry
CREATE TABLE DataSources (
    SourceID INTEGER NOT NULL AUTO_INCREMENT,
    SourceName VARCHAR(100) NOT NULL,
    SourceType ENUM('api', 'database', 'manual', 'ai', 'web_scraping') NOT NULL,
    SourceURL VARCHAR(500),
    
    -- Reliability Metrics
    ReliabilityScore DECIMAL(4,3) DEFAULT 1.0,
    TotalRequests INTEGER DEFAULT 0,
    SuccessfulRequests INTEGER DEFAULT 0,
    LastAccessDate TIMESTAMP NULL,
    AverageResponseTime DECIMAL(8,3), -- milliseconds
    
    -- Configuration
    APIKey VARCHAR(255),
    RateLimit INTEGER, -- requests per hour
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (SourceID),
    INDEX idx_sources_type (SourceType),
    INDEX idx_sources_reliability (ReliabilityScore)
);

-- =============================================
-- COMPREHENSIVE BOOKS TABLE
-- =============================================

-- Master Books Table - Everything about each book
CREATE TABLE Books (
    BookID INTEGER NOT NULL AUTO_INCREMENT,
    
    -- File Information (Full details)
    FileName VARCHAR(255) NOT NULL,
    FilePath VARCHAR(1000), -- Full server path
    FileSize BIGINT,
    FileSizeMB DECIMAL(12,2),
    PageCount INTEGER,
    FileHash VARCHAR(128), -- SHA-256 hash for integrity
    FileFormat VARCHAR(20) DEFAULT 'PDF',
    
    -- Core Bibliographic Data
    Title VARCHAR(500) NOT NULL,
    TitleNormalized VARCHAR(500), -- For deduplication
    Subtitle VARCHAR(500),
    OriginalTitle VARCHAR(500), -- If translated
    Publisher VARCHAR(200),
    Imprint VARCHAR(200), -- Publisher's imprint/division
    CopyrightYear INTEGER,
    PublicationYear INTEGER, -- May differ from copyright
    Edition VARCHAR(100),
    PrintingNumber INTEGER,
    LanguageID INTEGER,
    CountryOfOrigin VARCHAR(100),
    
    -- Enhanced Metadata
    SeriesName VARCHAR(300),
    VolumeNumber INTEGER,
    Description TEXT,
    TableOfContents TEXT,
    
    -- Primary identifiers
    PrimaryISBN VARCHAR(20),
    PrimaryLCCN VARCHAR(30),
    PrimaryOCLC VARCHAR(30),
    
    -- Processing & Quality
    ProcessingDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ProcessingVersion VARCHAR(20),
    ProcessorID INTEGER, -- ContributorID who processed
    QualityScore DECIMAL(4,2) DEFAULT 0.0, -- 0 to 100
    ContentExtractable BOOLEAN DEFAULT TRUE,
    OCRRequired BOOLEAN DEFAULT FALSE,
    
    -- Analytics & Usage
    TotalDownloads INTEGER DEFAULT 0,
    UniqueDownloads INTEGER DEFAULT 0,
    LastDownloadDate TIMESTAMP NULL,
    SearchFrequency INTEGER DEFAULT 0, -- How often searched for
    ViewCount INTEGER DEFAULT 0,
    
    -- User Ratings (Aggregated)
    AverageRating DECIMAL(3,2) DEFAULT 0.0,
    RatingCount INTEGER DEFAULT 0,
    FiveStarCount INTEGER DEFAULT 0,
    FourStarCount INTEGER DEFAULT 0,
    ThreeStarCount INTEGER DEFAULT 0,
    TwoStarCount INTEGER DEFAULT 0,
    OneStarCount INTEGER DEFAULT 0,
    
    -- Access & Distribution
    AccessLevel ENUM('public', 'members', 'premium', 'restricted', 'admin') DEFAULT 'public',
    LicenseType VARCHAR(100),
    CopyrightStatus ENUM('public_domain', 'copyrighted', 'creative_commons', 'unknown') DEFAULT 'unknown',
    DistributionRestrictions TEXT,
    
    -- Assets
    HasCover BOOLEAN DEFAULT FALSE,
    HasThumbnail BOOLEAN DEFAULT FALSE,
    HasPreview BOOLEAN DEFAULT FALSE,
    CoverQuality ENUM('low', 'medium', 'high') NULL,
    
    -- System Tracking
    ContributorID INTEGER, -- Who added this book
    DateAdded TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    DateModified TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    LastAccessed TIMESTAMP NULL,
    LastQualityCheck TIMESTAMP NULL,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (BookID),
    FOREIGN KEY (ContributorID) REFERENCES Contributors(ContributorID),
    FOREIGN KEY (ProcessorID) REFERENCES Contributors(ContributorID),
    CONSTRAINT UK_Books_FileName UNIQUE (FileName),
    
    -- Comprehensive indexing
    INDEX idx_books_title (Title(191)),
    INDEX idx_books_title_norm (TitleNormalized(191)),
    INDEX idx_books_publisher (Publisher),
    INDEX idx_books_year (PublicationYear),
    INDEX idx_books_copyright (CopyrightYear),
    INDEX idx_books_isbn (PrimaryISBN),
    INDEX idx_books_quality (QualityScore),
    INDEX idx_books_downloads (TotalDownloads),
    INDEX idx_books_rating (AverageRating),
    INDEX idx_books_access (AccessLevel),
    INDEX idx_books_contributor (ContributorID),
    INDEX idx_books_active (IsActive),
    INDEX idx_books_hash (FileHash)
);

-- =============================================
-- DETAILED TRACKING TABLES
-- =============================================

-- Book Contribution History - Who did what to each book
CREATE TABLE BookContributions (
    ContributionID INTEGER NOT NULL AUTO_INCREMENT,
    BookID INTEGER NOT NULL,
    ContributorID INTEGER NOT NULL,
    ContributionType ENUM('added', 'metadata_updated', 'classified', 'cover_added', 'quality_checked', 'error_fixed') NOT NULL,
    ContributionDetails JSON, -- What specifically was changed
    ContributionDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    QualityImpact DECIMAL(3,2), -- How much this improved quality (-1.0 to +1.0)
    
    PRIMARY KEY (ContributionID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (ContributorID) REFERENCES Contributors(ContributorID),
    
    INDEX idx_contributions_book (BookID),
    INDEX idx_contributions_contributor (ContributorID),
    INDEX idx_contributions_type (ContributionType),
    INDEX idx_contributions_date (ContributionDate)
);

-- Download Analytics - Track every download
CREATE TABLE DownloadLogs (
    DownloadID INTEGER NOT NULL AUTO_INCREMENT,
    BookID INTEGER NOT NULL,
    UserID VARCHAR(100), -- Anonymous or user identifier
    IPAddress VARCHAR(45),
    UserAgent VARCHAR(500),
    ReferrerURL VARCHAR(500),
    DownloadDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CompletedSuccessfully BOOLEAN DEFAULT TRUE,
    BytesTransferred BIGINT,
    DownloadDuration INTEGER, -- seconds
    
    PRIMARY KEY (DownloadID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    INDEX idx_downloads_book (BookID),
    INDEX idx_downloads_date (DownloadDate),
    INDEX idx_downloads_user (UserID),
    INDEX idx_downloads_success (CompletedSuccessfully)
);

-- Search Analytics - Track what people search for
CREATE TABLE SearchLogs (
    SearchID INTEGER NOT NULL AUTO_INCREMENT,
    SearchTerm VARCHAR(500) NOT NULL,
    SearchType ENUM('title', 'author', 'category', 'fulltext', 'isbn', 'advanced') NOT NULL,
    ResultCount INTEGER,
    UserID VARCHAR(100),
    IPAddress VARCHAR(45),
    SearchDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ClickedBookID INTEGER NULL, -- Which book they clicked on
    ClickPosition INTEGER NULL, -- Position in search results
    
    PRIMARY KEY (SearchID),
    FOREIGN KEY (ClickedBookID) REFERENCES Books(BookID) ON DELETE SET NULL,
    
    INDEX idx_searches_term (SearchTerm(100)),
    INDEX idx_searches_type (SearchType),
    INDEX idx_searches_date (SearchDate),
    INDEX idx_searches_results (ResultCount)
);

-- External API Usage - Track API calls and costs
CREATE TABLE APIUsageLogs (
    UsageID INTEGER NOT NULL AUTO_INCREMENT,
    SourceID INTEGER NOT NULL,
    BookID INTEGER NULL, -- Which book this was for
    APIEndpoint VARCHAR(200),
    RequestType ENUM('metadata', 'cover', 'validation', 'search') NOT NULL,
    RequestCost DECIMAL(8,4), -- Cost in dollars/credits
    ResponseTime INTEGER, -- milliseconds
    ResponseStatus VARCHAR(20), -- 'success', 'error', 'timeout'
    ResponseSize INTEGER, -- bytes
    RequestDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (UsageID),
    FOREIGN KEY (SourceID) REFERENCES DataSources(SourceID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE SET NULL,
    
    INDEX idx_api_source (SourceID),
    INDEX idx_api_book (BookID),
    INDEX idx_api_date (RequestDate),
    INDEX idx_api_cost (RequestCost),
    INDEX idx_api_status (ResponseStatus)
);

-- =============================================
-- QUALITY & VALIDATION TRACKING
-- =============================================

-- Data Quality Issues - Track problems found
CREATE TABLE QualityIssues (
    IssueID INTEGER NOT NULL AUTO_INCREMENT,
    BookID INTEGER NOT NULL,
    IssueType ENUM('missing_metadata', 'incorrect_metadata', 'duplicate_entry', 'file_corruption', 'classification_error', 'poor_ocr') NOT NULL,
    IssueSeverity ENUM('low', 'medium', 'high', 'critical') NOT NULL,
    IssueDescription TEXT,
    DetectedBy ENUM('automated', 'user_report', 'quality_check', 'ai_validation') NOT NULL,
    DetectedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ResolvedDate TIMESTAMP NULL,
    ResolvedBy INTEGER NULL, -- ContributorID
    ResolutionNotes TEXT,
    IsResolved BOOLEAN DEFAULT FALSE,
    
    PRIMARY KEY (IssueID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (ResolvedBy) REFERENCES Contributors(ContributorID),
    
    INDEX idx_issues_book (BookID),
    INDEX idx_issues_type (IssueType),
    INDEX idx_issues_severity (IssueSeverity),
    INDEX idx_issues_resolved (IsResolved),
    INDEX idx_issues_date (DetectedDate)
);

-- Metadata Validation Results
CREATE TABLE ValidationResults (
    ValidationID INTEGER NOT NULL AUTO_INCREMENT,
    BookID INTEGER NOT NULL,
    SourceID INTEGER NOT NULL, -- Which source validated against
    FieldName VARCHAR(100) NOT NULL, -- title, author, isbn, etc.
    OurValue TEXT,
    SourceValue TEXT,
    MatchStatus ENUM('exact_match', 'partial_match', 'no_match', 'conflicting') NOT NULL,
    ConfidenceScore DECIMAL(4,3),
    ValidationDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (ValidationID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (SourceID) REFERENCES DataSources(SourceID),
    
    INDEX idx_validation_book (BookID),
    INDEX idx_validation_source (SourceID),
    INDEX idx_validation_field (FieldName),
    INDEX idx_validation_status (MatchStatus)
);

-- =============================================
-- SYSTEM METRICS & HEALTH
-- =============================================

-- System Performance Metrics
CREATE TABLE SystemMetrics (
    MetricID INTEGER NOT NULL AUTO_INCREMENT,
    MetricName VARCHAR(100) NOT NULL,
    MetricValue DECIMAL(15,4),
    MetricUnit VARCHAR(20), -- 'count', 'seconds', 'bytes', 'percentage'
    MetricCategory ENUM('performance', 'usage', 'quality', 'errors', 'storage') NOT NULL,
    RecordedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (MetricID),
    INDEX idx_metrics_name (MetricName),
    INDEX idx_metrics_category (MetricCategory),
    INDEX idx_metrics_date (RecordedDate)
);

-- Database Sync Status - Track SQLite generation
CREATE TABLE SyncStatus (
    SyncID INTEGER NOT NULL AUTO_INCREMENT,
    SyncType ENUM('full_export', 'incremental_update', 'user_specific') NOT NULL,
    TotalBooks INTEGER,
    BooksExported INTEGER,
    ExportStarted TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ExportCompleted TIMESTAMP NULL,
    ExportDuration INTEGER, -- seconds
    ExportFileSize BIGINT, -- bytes
    ErrorCount INTEGER DEFAULT 0,
    ErrorDetails TEXT,
    IsSuccessful BOOLEAN DEFAULT FALSE,
    
    PRIMARY KEY (SyncID),
    INDEX idx_sync_type (SyncType),
    INDEX idx_sync_date (ExportStarted),
    INDEX idx_sync_success (IsSuccessful)
);

-- =============================================
-- ANALYTICS VIEWS & REPORTS
-- =============================================

-- Top Contributors View
CREATE VIEW TopContributors AS
SELECT 
    c.ContributorName,
    c.ContributorType,
    c.BooksContributed,
    c.MetadataContributed,
    c.AccuracyScore,
    c.ReputationPoints,
    COUNT(bc.ContributionID) AS RecentContributions
FROM Contributors c
LEFT JOIN BookContributions bc ON c.ContributorID = bc.ContributorID 
    AND bc.ContributionDate >= DATE_SUB(NOW(), INTERVAL 30 DAY)
WHERE c.IsActive = TRUE
GROUP BY c.ContributorID, c.ContributorName, c.ContributorType, 
         c.BooksContributed, c.MetadataContributed, c.AccuracyScore, c.ReputationPoints
ORDER BY c.ReputationPoints DESC;

-- Popular Books Report
CREATE VIEW PopularBooks AS
SELECT 
    b.BookID,
    b.Title,
    b.AverageRating,
    b.RatingCount,
    b.TotalDownloads,
    b.SearchFrequency,
    (b.TotalDownloads * 0.4 + b.SearchFrequency * 0.3 + b.AverageRating * b.RatingCount * 0.3) AS PopularityScore
FROM Books b
WHERE b.IsActive = TRUE
ORDER BY PopularityScore DESC;

-- Quality Dashboard
CREATE VIEW QualityDashboard AS
SELECT 
    COUNT(*) AS TotalBooks,
    AVG(QualityScore) AS AvgQualityScore,
    COUNT(CASE WHEN QualityScore >= 80 THEN 1 END) AS HighQualityBooks,
    COUNT(CASE WHEN QualityScore < 50 THEN 1 END) AS LowQualityBooks,
    COUNT(CASE WHEN HasCover = FALSE THEN 1 END) AS BooksWithoutCovers,
    (SELECT COUNT(*) FROM QualityIssues WHERE IsResolved = FALSE) AS UnresolvedIssues
FROM Books 
WHERE IsActive = TRUE;

-- API Efficiency Report
CREATE VIEW APIEfficiencyReport AS
SELECT 
    ds.SourceName,
    ds.SourceType,
    ds.ReliabilityScore,
    COUNT(aul.UsageID) AS TotalCalls,
    SUM(aul.RequestCost) AS TotalCost,
    AVG(aul.ResponseTime) AS AvgResponseTime,
    (COUNT(CASE WHEN aul.ResponseStatus = 'success' THEN 1 END) * 100.0 / COUNT(*)) AS SuccessRate
FROM DataSources ds
LEFT JOIN APIUsageLogs aul ON ds.SourceID = aul.SourceID
    AND aul.RequestDate >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY ds.SourceID, ds.SourceName, ds.SourceType, ds.ReliabilityScore
ORDER BY TotalCost DESC;

-- =============================================
-- STORED PROCEDURES FOR METRICS
-- =============================================

DELIMITER //

-- Update Book Quality Score
CREATE PROCEDURE UpdateBookQualityScore(IN p_BookID INTEGER)
BEGIN
    DECLARE quality_score DECIMAL(4,2) DEFAULT 0.0;
    
    -- Calculate quality based on various factors
    SELECT 
        (CASE WHEN Title IS NOT NULL AND LENGTH(Title) > 0 THEN 20 ELSE 0 END) +
        (CASE WHEN PrimaryISBN IS NOT NULL THEN 15 ELSE 0 END) +
        (CASE WHEN Publisher IS NOT NULL THEN 10 ELSE 0 END) +
        (CASE WHEN CopyrightYear IS NOT NULL THEN 10 ELSE 0 END) +
        (CASE WHEN HasCover = TRUE THEN 15 ELSE 0 END) +
        (CASE WHEN HasThumbnail = TRUE THEN 10 ELSE 0 END) +
        (CASE WHEN PageCount > 0 THEN 10 ELSE 0 END) +
        (CASE WHEN Description IS NOT NULL AND LENGTH(Description) > 100 THEN 10 ELSE 0 END)
    INTO quality_score
    FROM Books 
    WHERE BookID = p_BookID;
    
    -- Update the quality score
    UPDATE Books 
    SET QualityScore = quality_score, 
        LastQualityCheck = NOW() 
    WHERE BookID = p_BookID;
END //

-- Record System Metric
CREATE PROCEDURE RecordSystemMetric(
    IN p_MetricName VARCHAR(100),
    IN p_MetricValue DECIMAL(15,4),
    IN p_MetricUnit VARCHAR(20),
    IN p_MetricCategory ENUM('performance', 'usage', 'quality', 'errors', 'storage')
)
BEGIN
    INSERT INTO SystemMetrics (MetricName, MetricValue, MetricUnit, MetricCategory)
    VALUES (p_MetricName, p_MetricValue, p_MetricUnit, p_MetricCategory);
END //

DELIMITER ;

-- =============================================
-- SCHEMA TRANSFORMATION & SYNC MANAGEMENT
-- =============================================

-- Client Schema Definitions - Define different SQLite schemas
CREATE TABLE ClientSchemaVersions (
    SchemaVersionID INTEGER NOT NULL AUTO_INCREMENT,
    VersionName VARCHAR(50) NOT NULL, -- 'lite_v1', 'premium_v1', 'mobile_v1'
    VersionNumber VARCHAR(20) NOT NULL,
    TargetAudience ENUM('public', 'members', 'premium', 'admin') NOT NULL,
    Description TEXT,
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (SchemaVersionID),
    CONSTRAINT UK_Schema_Version UNIQUE (VersionName, VersionNumber)
);

-- Table Transformation Rules - How to transform each table
CREATE TABLE TableTransformations (
    TransformationID INTEGER NOT NULL AUTO_INCREMENT,
    SchemaVersionID INTEGER NOT NULL,
    SourceTable VARCHAR(100) NOT NULL, -- MySQL table name
    TargetTable VARCHAR(100) NOT NULL, -- SQLite table name (can be same)
    TransformationType ENUM('include', 'exclude', 'subset', 'aggregate') NOT NULL,
    FilterCondition TEXT, -- WHERE clause for subsetting
    SortOrder INTEGER DEFAULT 0,
    
    PRIMARY KEY (TransformationID),
    FOREIGN KEY (SchemaVersionID) REFERENCES ClientSchemaVersions(SchemaVersionID) ON DELETE CASCADE,
    INDEX idx_transformations_schema (SchemaVersionID),
    INDEX idx_transformations_source (SourceTable)
);

-- Column Transformation Rules - How to transform each column
CREATE TABLE ColumnTransformations (
    ColumnTransformationID INTEGER NOT NULL AUTO_INCREMENT,
    TransformationID INTEGER NOT NULL,
    SourceColumn VARCHAR(100) NOT NULL, -- MySQL column name
    TargetColumn VARCHAR(100), -- SQLite column name (NULL = exclude)
    DataTypeTransformation VARCHAR(200), -- 'BIGINT->INTEGER', 'JSON->TEXT', etc.
    ValueTransformation TEXT, -- SQL expression for value conversion
    DefaultValue TEXT, -- Default if source is NULL
    IncludeInOutput BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (ColumnTransformationID),
    FOREIGN KEY (TransformationID) REFERENCES TableTransformations(TransformationID) ON DELETE CASCADE,
    INDEX idx_column_transformations (TransformationID)
);

-- Client Database Instances - Track generated SQLite databases
CREATE TABLE ClientDatabases (
    ClientDatabaseID INTEGER NOT NULL AUTO_INCREMENT,
    SchemaVersionID INTEGER NOT NULL,
    DatabaseName VARCHAR(100) NOT NULL,
    GenerationDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    RecordCount INTEGER,
    FileSizeBytes BIGINT,
    GenerationDuration INTEGER, -- seconds
    IsActive BOOLEAN DEFAULT TRUE,
    
    -- Sync tracking
    LastSyncDate TIMESTAMP NULL,
    SyncStatus ENUM('generated', 'distributed', 'outdated', 'error') DEFAULT 'generated',
    DistributionURL VARCHAR(500),
    
    PRIMARY KEY (ClientDatabaseID),
    FOREIGN KEY (SchemaVersionID) REFERENCES ClientSchemaVersions(SchemaVersionID),
    INDEX idx_client_db_schema (SchemaVersionID),
    INDEX idx_client_db_status (SyncStatus)
);

-- Bidirectional Sync Rules - Handle data coming back from clients
CREATE TABLE SyncRules (
    SyncRuleID INTEGER NOT NULL AUTO_INCREMENT,
    SchemaVersionID INTEGER NOT NULL,
    ClientTable VARCHAR(100) NOT NULL,
    ClientColumn VARCHAR(100) NOT NULL,
    MasterTable VARCHAR(100) NOT NULL,
    MasterColumn VARCHAR(100) NOT NULL,
    SyncDirection ENUM('client_to_master', 'master_to_client', 'bidirectional') NOT NULL,
    ConflictResolution ENUM('master_wins', 'client_wins', 'merge', 'manual') DEFAULT 'master_wins',
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (SyncRuleID),
    FOREIGN KEY (SchemaVersionID) REFERENCES ClientSchemaVersions(SchemaVersionID) ON DELETE CASCADE,
    INDEX idx_sync_rules_schema (SchemaVersionID),
    INDEX idx_sync_rules_direction (SyncDirection)
);

-- Sync Transaction Log - Track all data sync operations
CREATE TABLE SyncTransactions (
    SyncTransactionID INTEGER NOT NULL AUTO_INCREMENT,
    ClientDatabaseID INTEGER NOT NULL,
    SyncDirection ENUM('download', 'upload', 'bidirectional') NOT NULL,
    RecordsAffected INTEGER DEFAULT 0,
    ConflictsDetected INTEGER DEFAULT 0,
    ConflictsResolved INTEGER DEFAULT 0,
    SyncStartDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    SyncEndDate TIMESTAMP NULL,
    SyncStatus ENUM('in_progress', 'completed', 'failed', 'partial') DEFAULT 'in_progress',
    ErrorDetails TEXT,
    
    PRIMARY KEY (SyncTransactionID),
    FOREIGN KEY (ClientDatabaseID) REFERENCES ClientDatabases(ClientDatabaseID),
    INDEX idx_sync_transactions_client (ClientDatabaseID),
    INDEX idx_sync_transactions_date (SyncStartDate),
    INDEX idx_sync_transactions_status (SyncStatus)
);

-- Data Conflicts - Track sync conflicts for manual resolution
CREATE TABLE DataConflicts (
    ConflictID INTEGER NOT NULL AUTO_INCREMENT,
    SyncTransactionID INTEGER NOT NULL,
    TableName VARCHAR(100) NOT NULL,
    RecordID VARCHAR(100) NOT NULL, -- Primary key of conflicting record
    ColumnName VARCHAR(100) NOT NULL,
    MasterValue TEXT,
    ClientValue TEXT,
    ConflictType ENUM('update_conflict', 'delete_conflict', 'constraint_violation') NOT NULL,
    ResolutionStatus ENUM('pending', 'resolved_master', 'resolved_client', 'resolved_merge') DEFAULT 'pending',
    ResolvedBy INTEGER NULL, -- ContributorID
    ResolvedDate TIMESTAMP NULL,
    
    PRIMARY KEY (ConflictID),
    FOREIGN KEY (SyncTransactionID) REFERENCES SyncTransactions(SyncTransactionID) ON DELETE CASCADE,
    FOREIGN KEY (ResolvedBy) REFERENCES Contributors(ContributorID),
    INDEX idx_conflicts_transaction (SyncTransactionID),
    INDEX idx_conflicts_status (ResolutionStatus),
    INDEX idx_conflicts_table (TableName)
);

-- =============================================
-- STORED PROCEDURES FOR SCHEMA TRANSFORMATION
-- =============================================

DELIMITER //

-- Generate SQLite Schema DDL
CREATE PROCEDURE GenerateClientSchemaDDL(
    IN p_SchemaVersionID INTEGER,
    OUT p_DDLScript TEXT
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_source_table VARCHAR(100);
    DECLARE v_target_table VARCHAR(100);
    DECLARE v_transformation_type ENUM('include', 'exclude', 'subset', 'aggregate');
    DECLARE ddl_statement TEXT DEFAULT '';
    
    -- Cursor for table transformations
    DECLARE table_cursor CURSOR FOR
        SELECT SourceTable, TargetTable, TransformationType
        FROM TableTransformations
        WHERE SchemaVersionID = p_SchemaVersionID
        AND TransformationType != 'exclude'
        ORDER BY SortOrder;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    SET p_DDLScript = '-- Generated SQLite Schema\n-- Version: ';
    
    -- Add version info
    SELECT CONCAT(p_DDLScript, VersionName, ' ', VersionNumber, '\n\n')
    INTO p_DDLScript
    FROM ClientSchemaVersions
    WHERE SchemaVersionID = p_SchemaVersionID;
    
    -- Generate CREATE TABLE statements
    OPEN table_cursor;
    
    read_loop: LOOP
        FETCH table_cursor INTO v_source_table, v_target_table, v_transformation_type;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Build CREATE TABLE statement for this table
        CALL BuildCreateTableStatement(p_SchemaVersionID, v_source_table, v_target_table, ddl_statement);
        SET p_DDLScript = CONCAT(p_DDLScript, ddl_statement, '\n\n');
        
    END LOOP;
    
    CLOSE table_cursor;
    
    -- Add indexes and views
    SET p_DDLScript = CONCAT(p_DDLScript, '-- Indexes and Views\n');
    CALL AddClientIndexes(p_SchemaVersionID, ddl_statement);
    SET p_DDLScript = CONCAT(p_DDLScript, ddl_statement);
    
END //

-- Build individual CREATE TABLE statement
CREATE PROCEDURE BuildCreateTableStatement(
    IN p_SchemaVersionID INTEGER,
    IN p_SourceTable VARCHAR(100),
    IN p_TargetTable VARCHAR(100),
    OUT p_CreateStatement TEXT
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_source_column VARCHAR(100);
    DECLARE v_target_column VARCHAR(100);
    DECLARE v_data_type VARCHAR(200);
    DECLARE column_def TEXT DEFAULT '';
    DECLARE columns_list TEXT DEFAULT '';
    
    -- Cursor for column transformations
    DECLARE column_cursor CURSOR FOR
        SELECT ct.SourceColumn, ct.TargetColumn, ct.DataTypeTransformation
        FROM TableTransformations tt
        JOIN ColumnTransformations ct ON tt.TransformationID = ct.TransformationID
        WHERE tt.SchemaVersionID = p_SchemaVersionID
        AND tt.SourceTable = p_SourceTable
        AND ct.IncludeInOutput = TRUE;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Start CREATE TABLE statement
    SET p_CreateStatement = CONCAT('CREATE TABLE ', p_TargetTable, ' (\n');
    
    -- Add columns
    OPEN column_cursor;
    
    column_loop: LOOP
        FETCH column_cursor INTO v_source_column, v_target_column, v_data_type;
        IF done THEN
            LEAVE column_loop;
        END IF;
        
        IF columns_list != '' THEN
            SET columns_list = CONCAT(columns_list, ',\n');
        END IF;
        
        SET columns_list = CONCAT(columns_list, '    ', 
                                 COALESCE(v_target_column, v_source_column), 
                                 ' ', v_data_type);
        
    END LOOP;
    
    CLOSE column_cursor;
    
    -- Complete CREATE TABLE statement
    SET p_CreateStatement = CONCAT(p_CreateStatement, columns_list, '\n);');
    
END //

-- Execute Data Export for Client Database
CREATE PROCEDURE ExportClientData(
    IN p_SchemaVersionID INTEGER,
    IN p_OutputFormat ENUM('sql_inserts', 'csv', 'json') DEFAULT 'sql_inserts'
)
BEGIN
    DECLARE v_client_db_id INTEGER;
    
    -- Create new client database record
    INSERT INTO ClientDatabases (SchemaVersionID, DatabaseName, SyncStatus)
    VALUES (p_SchemaVersionID, 
            CONCAT('client_db_', p_SchemaVersionID, '_', UNIX_TIMESTAMP()),
            'generated');
    
    SET v_client_db_id = LAST_INSERT_ID();
    
    -- Execute transformation logic here
    -- (Implementation would generate actual data export)
    
    -- Update completion status
    UPDATE ClientDatabases 
    SET SyncStatus = 'distributed',
        LastSyncDate = NOW()
    WHERE ClientDatabaseID = v_client_db_id;
    
END //

DELIMITER ;

-- =============================================
-- INITIALIZATION DATA
-- =============================================

-- Insert system contributor for automated processes
INSERT INTO Contributors (ContributorName, Email, ContributorType, PermissionLevel) 
VALUES ('System', 'system@bowersworld.com', 'ai_system', 'admin');

-- Insert common data sources
INSERT INTO DataSources (SourceName, SourceType, SourceURL, ReliabilityScore) VALUES
('Open Library', 'api', 'https://openlibrary.org/api/', 0.85),
('Google Books', 'api', 'https://www.googleapis.com/books/v1/', 0.90),
('WorldCat', 'api', 'https://www.worldcat.org/webservices/', 0.95),
('Library of Congress', 'api', 'https://www.loc.gov/apis/', 0.98),
('Manual Entry', 'manual', NULL, 1.0);

-- =============================================
-- EXAMPLE CLIENT SCHEMA CONFIGURATIONS
-- =============================================

-- Define different client schema versions
INSERT INTO ClientSchemaVersions (VersionName, VersionNumber, TargetAudience, Description) VALUES
('lite_v1', '1.0', 'public', 'Basic public access - core book data only'),
('premium_v1', '1.0', 'premium', 'Premium users - includes ratings and enhanced metadata'),
('mobile_v1', '1.0', 'members', 'Mobile app optimized - smaller field sizes'),
('admin_v1', '1.0', 'admin', 'Administrative access - includes processing data');

-- Example: Lite Version (Public Access) - Books Table
INSERT INTO TableTransformations (SchemaVersionID, SourceTable, TargetTable, TransformationType, FilterCondition) 
VALUES 
(1, 'Books', 'Books', 'subset', 'IsActive = TRUE AND AccessLevel IN (''public'', ''members'')');

INSERT INTO ColumnTransformations (TransformationID, SourceColumn, TargetColumn, DataTypeTransformation, IncludeInOutput) VALUES
(1, 'BookID', 'BookID', 'INTEGER PRIMARY KEY', TRUE),
(1, 'FileName', 'FileName', 'VARCHAR(255) NOT NULL', TRUE),
(1, 'Title', 'Title', 'VARCHAR(500) NOT NULL', TRUE),
(1, 'Subtitle', 'Subtitle', 'VARCHAR(500)', TRUE),
(1, 'Publisher', 'Publisher', 'VARCHAR(200)', TRUE),
(1, 'CopyrightYear', 'CopyrightYear', 'INTEGER', TRUE),
(1, 'Edition', 'Edition', 'VARCHAR(100)', TRUE),
(1, 'LanguageID', 'LanguageID', 'INTEGER', TRUE),
(1, 'PrimaryISBN', 'PrimaryISBN', 'VARCHAR(20)', TRUE),
(1, 'PageCount', 'PageCount', 'INTEGER', TRUE),
(1, 'FileSize', 'FileSize', 'INTEGER', TRUE),
(1, 'HasCover', 'HasCover', 'BOOLEAN DEFAULT FALSE', TRUE),
(1, 'HasThumbnail', 'HasThumbnail', 'BOOLEAN DEFAULT FALSE', TRUE),
(1, 'AccessLevel', 'AccessLevel', 'VARCHAR(20) DEFAULT ''public''', TRUE),
(1, 'DateAdded', 'DateAdded', 'TEXT', TRUE),
(1, 'IsActive', 'IsActive', 'BOOLEAN DEFAULT TRUE', TRUE),
-- Exclude heavy fields for lite version
(1, 'FilePath', NULL, NULL, FALSE),
(1, 'FileHash', NULL, NULL, FALSE),
(1, 'ProcessingDate', NULL, NULL, FALSE),
(1, 'QualityScore', NULL, NULL, FALSE),
(1, 'TotalDownloads', NULL, NULL, FALSE);

-- Example sync rules for bidirectional data
INSERT INTO SyncRules (SchemaVersionID, ClientTable, ClientColumn, MasterTable, MasterColumn, SyncDirection, ConflictResolution) VALUES
(1, 'Books', 'ViewCount', 'Books', 'ViewCount', 'client_to_master', 'merge'),
(1, 'Books', 'LastAccessed', 'Books', 'LastAccessed', 'client_to_master', 'client_wins'),
(1, 'UserRatings', 'Rating', 'UserRatings', 'Rating', 'client_to_master', 'client_wins');

/*
SCHEMA TRANSFORMATION SYSTEM EXPLAINED:

1. **Multiple Client Versions**:
   - lite_v1: Public users - basic book data
   - premium_v1: Paying users - includes ratings, reviews
   - mobile_v1: Mobile apps - optimized field sizes
   - admin_v1: Admin tools - full access

2. **Transformation Types**:
   - include: Copy table as-is
   - exclude: Don't include in client schema
   - subset: Include with WHERE clause filtering
   - aggregate: Create summary/grouped data

3. **Column Transformations**:
   - Rename columns (SourceColumn -> TargetColumn)
   - Change data types (BIGINT -> INTEGER for SQLite)
   - Apply value transformations (JSON -> TEXT conversion)
   - Exclude sensitive fields (NULL TargetColumn)

4. **Bidirectional Sync**:
   - Track user interactions (ViewCount, LastAccessed)
   - Sync user-generated content (Ratings, Notes)
   - Handle conflicts with configurable resolution

5. **Example Workflow**:
   a. Admin defines new client schema version
   b. Sets transformation rules for each table/column
   c. System generates SQLite DDL script
   d. System exports data according to rules
   e. Clients download and use local SQLite
   f. Client data syncs back via defined rules

6. **Conflict Resolution Options**:
   - master_wins: Server data takes precedence
   - client_wins: User data takes precedence  
   - merge: Combine values (e.g., sum ViewCounts)
   - manual: Flag for human review

7. **Usage Examples**:
   
   -- Generate SQLite schema for lite version
   CALL GenerateClientSchemaDDL(1, @ddl_script);
   SELECT @ddl_script;
   
   -- Export data for premium users
   CALL ExportClientData(2, 'sql_inserts');
   
   -- Check sync conflicts
   SELECT * FROM DataConflicts WHERE ResolutionStatus = 'pending';
   
   -- Track schema performance
   SELECT sv.VersionName, COUNT(cd.ClientDatabaseID) as ActiveInstances,
          AVG(cd.FileSizeBytes) as AvgFileSize
   FROM ClientSchemaVersions sv
   LEFT JOIN ClientDatabases cd ON sv.SchemaVersionID = cd.SchemaVersionID
   GROUP BY sv.SchemaVersionID;

BENEFITS OF THIS APPROACH:
- Single source of truth (MySQL master)
- Flexible client schema generation
- Automatic conflict detection/resolution
- Version management for schema evolution
- Performance metrics and monitoring
- Clean separation of concerns
- Scalable to multiple client types
*/