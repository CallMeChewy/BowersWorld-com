-- MySQL Conversion Enhancement Script
-- Run this AFTER converting SQLite dump to MySQL
-- Standard: AIDEV-PascalCase-1.8
-- Author: Herb Bowers - Project Himalaya
-- Purpose: Optimize converted MySQL database with MySQL-specific features

-- ====================================
-- 1. AUTO_INCREMENT FIXES
-- ====================================
-- Add AUTO_INCREMENT to primary key columns

ALTER TABLE Categories MODIFY CategoryID INT NOT NULL AUTO_INCREMENT;
ALTER TABLE Subjects MODIFY SubjectID INT NOT NULL AUTO_INCREMENT;
ALTER TABLE Books MODIFY BookID INT NOT NULL AUTO_INCREMENT;
ALTER TABLE BookRelationships MODIFY RelationshipID INT NOT NULL AUTO_INCREMENT;
ALTER TABLE LLMClassifications MODIFY ClassificationID INT NOT NULL AUTO_INCREMENT;
ALTER TABLE BookAnalytics MODIFY AnalyticsID INT NOT NULL AUTO_INCREMENT;
ALTER TABLE SearchAnalytics MODIFY SearchID INT NOT NULL AUTO_INCREMENT;

-- ====================================
-- 2. MYSQL FULLTEXT SEARCH INDEXES
-- ====================================
-- Replace SQLite FTS5 with MySQL FULLTEXT

-- Drop the FTS5 table if converted (it won't work in MySQL)
DROP TABLE IF EXISTS BooksSearchFTS;

-- Add FULLTEXT indexes for search functionality
ALTER TABLE Books ADD FULLTEXT idx_books_fulltext (Title, Author, Publisher, PDFTitle, PDFAuthor);
ALTER TABLE BookContent ADD FULLTEXT idx_content_fulltext (FirstPageText, TitlePageText, CopyrightPageText);
ALTER TABLE BookSearchIndex ADD FULLTEXT idx_search_fulltext (SearchableContent);

-- ====================================
-- 3. MYSQL-SPECIFIC OPTIMIZATIONS
-- ====================================

-- Set proper MySQL storage engine and charset
ALTER TABLE Categories ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE Subjects ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE Books ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE BookContent ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE BookFullTextContent ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE BookSearchIndex ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE BookRelationships ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE LLMClassifications ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE BookAnalytics ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE SearchAnalytics ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE SystemConfig ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================
-- 4. MYSQL-ENHANCED STORED PROCEDURES
-- ====================================

DELIMITER //

-- Stored procedure for full-text search with ranking
CREATE PROCEDURE SearchBooks(
    IN search_query VARCHAR(500),
    IN search_type VARCHAR(20),
    IN limit_results INT
)
BEGIN
    DECLARE search_mode VARCHAR(20) DEFAULT 'IN NATURAL LANGUAGE MODE';
    
    -- Set search mode based on type
    IF search_type = 'boolean' THEN
        SET search_mode = 'IN BOOLEAN MODE';
    ELSEIF search_type = 'expansion' THEN
        SET search_mode = 'WITH QUERY EXPANSION';
    END IF;
    
    -- Execute search with ranking
    SET @sql = CONCAT(
        'SELECT b.BookID, b.Title, b.Author, c.CategoryName, ',
        'MATCH(b.Title, b.Author, b.Publisher, b.PDFTitle, b.PDFAuthor) ',
        'AGAINST (? ', search_mode, ') AS relevance_score ',
        'FROM Books b ',
        'LEFT JOIN Categories c ON b.CategoryID = c.CategoryID ',
        'WHERE MATCH(b.Title, b.Author, b.Publisher, b.PDFTitle, b.PDFAuthor) ',
        'AGAINST (? ', search_mode, ') ',
        'AND b.IsActive = 1 ',
        'ORDER BY relevance_score DESC ',
        'LIMIT ?'
    );
    
    PREPARE stmt FROM @sql;
    EXECUTE stmt USING search_query, search_query, limit_results;
    DEALLOCATE PREPARE stmt;
END //

-- Stored procedure for content search
CREATE PROCEDURE SearchBookContent(
    IN search_query VARCHAR(500),
    IN limit_results INT
)
BEGIN
    SELECT 
        b.BookID,
        b.Title,
        b.Author,
        c.CategoryName,
        MATCH(bc.FirstPageText, bc.TitlePageText, bc.CopyrightPageText) 
        AGAINST (search_query IN NATURAL LANGUAGE MODE) AS content_relevance,
        SUBSTRING(bc.FirstPageText, 1, 200) AS content_snippet
    FROM Books b
    JOIN BookContent bc ON b.BookID = bc.BookID
    LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
    WHERE MATCH(bc.FirstPageText, bc.TitlePageText, bc.CopyrightPageText) 
          AGAINST (search_query IN NATURAL LANGUAGE MODE)
    AND b.IsActive = 1
    ORDER BY content_relevance DESC
    LIMIT limit_results;
END //

-- Stored procedure for similar books recommendation
CREATE PROCEDURE GetSimilarBooks(
    IN book_id INT,
    IN limit_results INT
)
BEGIN
    -- Get similar books based on relationships and category/subject
    SELECT 
        b.BookID,
        b.Title,
        b.Author,
        c.CategoryName,
        s.SubjectName,
        br.Strength AS similarity_score,
        br.RelationshipType,
        'relationship' AS source
    FROM BookRelationships br
    JOIN Books b ON br.BookID2 = b.BookID
    LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
    LEFT JOIN Subjects s ON b.SubjectID = s.SubjectID
    WHERE br.BookID1 = book_id 
    AND br.IsActive = 1
    AND b.IsActive = 1
    
    UNION ALL
    
    -- Get books in same subject with high confidence
    SELECT 
        b2.BookID,
        b2.Title,
        b2.Author,
        c.CategoryName,
        s.SubjectName,
        (b2.OverallConfidence * 0.8) AS similarity_score,
        'same_subject' AS RelationshipType,
        'category_match' AS source
    FROM Books b1
    JOIN Books b2 ON b1.SubjectID = b2.SubjectID
    LEFT JOIN Categories c ON b2.CategoryID = c.CategoryID
    LEFT JOIN Subjects s ON b2.SubjectID = s.SubjectID
    WHERE b1.BookID = book_id
    AND b2.BookID != book_id
    AND b1.IsActive = 1
    AND b2.IsActive = 1
    AND b2.OverallConfidence >= 0.8
    
    ORDER BY similarity_score DESC
    LIMIT limit_results;
END //

-- Analytics procedure for category performance
CREATE PROCEDURE GetCategoryAnalytics(
    IN days_back INT
)
BEGIN
    SELECT 
        c.CategoryName,
        COUNT(DISTINCT b.BookID) AS total_books,
        COUNT(DISTINCT ba.BookID) AS accessed_books,
        SUM(ba.EventType = 'view') AS total_views,
        SUM(ba.EventType = 'download') AS total_downloads,
        AVG(b.Rating) AS avg_rating,
        AVG(b.OverallConfidence) AS avg_confidence
    FROM Categories c
    LEFT JOIN Books b ON c.CategoryID = b.CategoryID AND b.IsActive = 1
    LEFT JOIN BookAnalytics ba ON b.BookID = ba.BookID 
        AND ba.EventDate >= DATE_SUB(NOW(), INTERVAL days_back DAY)
    WHERE c.IsActive = 1
    GROUP BY c.CategoryID, c.CategoryName
    ORDER BY total_views DESC;
END //

DELIMITER ;

-- ====================================
-- 5. MYSQL-SPECIFIC FUNCTIONS
-- ====================================

DELIMITER //

-- Function to calculate book popularity score
CREATE FUNCTION CalculatePopularityScore(
    view_count INT,
    download_count INT,
    rating DECIMAL(3,2),
    rating_count INT,
    days_since_added INT
) RETURNS DECIMAL(8,4)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE popularity_score DECIMAL(8,4) DEFAULT 0.0000;
    DECLARE age_factor DECIMAL(4,4);
    DECLARE rating_factor DECIMAL(4,4);
    
    -- Age decay factor (newer books get slight boost)
    SET age_factor = CASE 
        WHEN days_since_added <= 30 THEN 1.2
        WHEN days_since_added <= 90 THEN 1.1
        WHEN days_since_added <= 365 THEN 1.0
        ELSE 0.9
    END;
    
    -- Rating factor (only count if enough ratings)
    SET rating_factor = CASE
        WHEN rating_count >= 5 THEN rating / 5.0
        WHEN rating_count >= 2 THEN (rating / 5.0) * 0.8
        ELSE 1.0
    END;
    
    -- Calculate weighted popularity score
    SET popularity_score = (
        (view_count * 1.0) + 
        (download_count * 3.0) + 
        (rating_factor * 10.0)
    ) * age_factor;
    
    RETURN popularity_score;
END //

DELIMITER ;

-- ====================================
-- 6. MYSQL-OPTIMIZED VIEWS
-- ====================================

-- Drop and recreate views with MySQL optimizations
DROP VIEW IF EXISTS BookDetails;
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
    b.DownloadCount,
    b.DateAdded,
    b.CoverPath,
    b.ThumbnailPath,
    b.IsActive,
    -- MySQL-specific calculated fields
    DATEDIFF(NOW(), b.DateAdded) AS days_since_added,
    CalculatePopularityScore(
        b.ViewCount, 
        b.DownloadCount, 
        b.Rating, 
        b.RatingCount, 
        DATEDIFF(NOW(), b.DateAdded)
    ) AS popularity_score
FROM Books b
LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
LEFT JOIN Subjects s ON b.SubjectID = s.SubjectID;

-- Enhanced search results view
CREATE VIEW SearchResultsEnhanced AS
SELECT 
    bd.*,
    bc.FirstPageText,
    bc.ExtractedKeywords,
    -- Search snippet helpers
    LEFT(bc.FirstPageText, 300) AS search_snippet,
    CASE 
        WHEN bd.OverallConfidence >= 0.9 THEN 'excellent'
        WHEN bd.OverallConfidence >= 0.8 THEN 'high'
        WHEN bd.OverallConfidence >= 0.7 THEN 'good'
        ELSE 'needs_review'
    END AS confidence_level
FROM BookDetails bd
LEFT JOIN BookContent bc ON bd.BookID = bc.BookID
WHERE bd.IsActive = 1;

-- ====================================
-- 7. MYSQL PERFORMANCE TUNING
-- ====================================

-- Additional MySQL-specific indexes for complex queries
CREATE INDEX idx_books_popularity ON Books(ViewCount, DownloadCount, Rating);
CREATE INDEX idx_books_date_confidence ON Books(DateAdded, OverallConfidence);
CREATE INDEX idx_analytics_date_type ON BookAnalytics(EventDate, EventType);
CREATE INDEX idx_llm_date_model ON LLMClassifications(ClassificationDate, ModelName);

-- Composite indexes for common query patterns
CREATE INDEX idx_books_category_confidence ON Books(CategoryID, OverallConfidence, IsActive);
CREATE INDEX idx_books_subject_rating ON Books(SubjectID, Rating, IsActive);
CREATE INDEX idx_relationships_strength_active ON BookRelationships(Strength, IsActive, RelationshipType);

-- ====================================
-- 8. MYSQL SPECIFIC TRIGGERS
-- ====================================

-- Trigger to populate search index automatically
DROP TRIGGER IF EXISTS trg_books_update_search_index;

DELIMITER //

CREATE TRIGGER trg_books_update_search_index
AFTER INSERT ON Books
FOR EACH ROW
BEGIN
    INSERT INTO BookSearchIndex (BookID, SearchableContent, IndexedDate)
    VALUES (
        NEW.BookID,
        CONCAT_WS(' ',
            IFNULL(NEW.Title, ''),
            IFNULL(NEW.Author, ''),
            IFNULL(NEW.Publisher, ''),
            IFNULL(NEW.PDFTitle, ''),
            IFNULL(NEW.PDFAuthor, ''),
            IFNULL(NEW.PDFSubject, ''),
            IFNULL(NEW.ContentTags, ''),
            IFNULL(NEW.ExtractedPublisher, '')
        ),
        NOW()
    );
END //

DELIMITER ;

-- ====================================
-- 9. MYSQL MAINTENANCE PROCEDURES
-- ====================================

DELIMITER //

-- Procedure to rebuild search indexes
CREATE PROCEDURE RebuildSearchIndexes()
BEGIN
    -- Truncate and rebuild search index
    TRUNCATE TABLE BookSearchIndex;
    
    INSERT INTO BookSearchIndex (BookID, SearchableContent, IndexedDate)
    SELECT 
        b.BookID,
        CONCAT_WS(' ',
            IFNULL(b.Title, ''),
            IFNULL(b.Author, ''),
            IFNULL(b.Publisher, ''),
            IFNULL(b.PDFTitle, ''),
            IFNULL(b.PDFAuthor, ''),
            IFNULL(b.PDFSubject, ''),
            IFNULL(b.ContentTags, ''),
            IFNULL(bc.FirstPageText, ''),
            IFNULL(bc.ExtractedKeywords, '')
        ),
        NOW()
    FROM Books b
    LEFT JOIN BookContent bc ON b.BookID = bc.BookID
    WHERE b.IsActive = 1;
    
    -- Repair and optimize fulltext indexes
    REPAIR TABLE Books;
    REPAIR TABLE BookContent;
    REPAIR TABLE BookSearchIndex;
    
    OPTIMIZE TABLE Books;
    OPTIMIZE TABLE BookContent;
    OPTIMIZE TABLE BookSearchIndex;
END //

-- Procedure to clean up old analytics data
CREATE PROCEDURE CleanupAnalytics(
    IN days_to_keep INT
)
BEGIN
    DELETE FROM BookAnalytics 
    WHERE EventDate < DATE_SUB(NOW(), INTERVAL days_to_keep DAY);
    
    DELETE FROM SearchAnalytics 
    WHERE SearchDate < DATE_SUB(NOW(), INTERVAL days_to_keep DAY);
    
    OPTIMIZE TABLE BookAnalytics;
    OPTIMIZE TABLE SearchAnalytics;
END //

DELIMITER ;

-- ====================================
-- 10. MYSQL WORKBENCH METADATA
-- ====================================

-- Add table comments for better documentation in MySQL Workbench
ALTER TABLE Categories COMMENT = 'Top-level book categories for classification hierarchy';
ALTER TABLE Subjects COMMENT = 'Subject classifications within categories';
ALTER TABLE Books COMMENT = 'Core book metadata with AI classification results';
ALTER TABLE BookContent COMMENT = 'Extracted text content for search and analysis';
ALTER TABLE BookFullTextContent COMMENT = 'Complete extracted text for full-content search';
ALTER TABLE BookSearchIndex COMMENT = 'Optimized search index for MySQL FULLTEXT';
ALTER TABLE BookRelationships COMMENT = 'Relationships between books (similarity, series, etc.)';
ALTER TABLE LLMClassifications COMMENT = 'AI/LLM classification attempts and results tracking';
ALTER TABLE BookAnalytics COMMENT = 'User interaction and usage analytics';
ALTER TABLE SearchAnalytics COMMENT = 'Search query analytics and click tracking';
ALTER TABLE SystemConfig COMMENT = 'System configuration and settings storage';

-- ====================================
-- CONVERSION COMPLETE MESSAGE
-- ====================================

SELECT 'MySQL conversion enhancement completed successfully!' AS status,
       'Database optimized for MySQL Workbench and production use' AS message,
       NOW() AS completed_at;