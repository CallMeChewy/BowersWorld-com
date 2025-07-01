-- Sample Queries for Enhanced MyLibrary.db
-- Demonstrates the power of the enhanced schema for AI-powered library management

-- ====================================
-- BASIC LIBRARY OPERATIONS
-- ====================================

-- Get all books with complete metadata
SELECT 
    b.Title,
    b.Author,
    c.CategoryName,
    s.SubjectName,
    b.OverallConfidence,
    b.Rating,
    b.ViewCount
FROM BookDetails b
LEFT JOIN Categories c ON b.CategoryID = c.CategoryID  
LEFT JOIN Subjects s ON b.SubjectID = s.SubjectID
ORDER BY b.OverallConfidence DESC, b.Title;

-- Find books needing AI re-classification (low confidence)
SELECT 
    FileName,
    Title,
    Author,
    CategoryName,
    SubjectName,
    OverallConfidence,
    ProcessingFlags
FROM BooksNeedingReview
ORDER BY OverallConfidence ASC;

-- ====================================
-- FULL-TEXT SEARCH EXAMPLES
-- ====================================

-- Search across all text content
SELECT 
    b.Title,
    b.Author,
    c.CategoryName,
    snippet(BooksFullText, 0, '<mark>', '</mark>', '...', 32) as Snippet
FROM BooksFullText fts
JOIN Books b ON fts.rowid = b.BookID
LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
WHERE BooksFullText MATCH 'python programming'
ORDER BY bm25(BooksFullText);

-- Find books by content keywords with ranking
SELECT 
    b.Title,
    b.Author,
    b.OverallConfidence,
    bm25(BooksFullText) as Relevance
FROM BooksFullText fts
JOIN Books b ON fts.rowid = b.BookID
WHERE BooksFullText MATCH '"machine learning" OR "artificial intelligence"'
ORDER BY Relevance;

-- ====================================
-- AI CLASSIFICATION ANALYTICS
-- ====================================

-- Classification confidence distribution
SELECT 
    CASE 
        WHEN OverallConfidence >= 0.9 THEN 'Excellent (90%+)'
        WHEN OverallConfidence >= 0.8 THEN 'High (80-89%)'
        WHEN OverallConfidence >= 0.7 THEN 'Good (70-79%)'
        WHEN OverallConfidence >= 0.6 THEN 'Fair (60-69%)'
        ELSE 'Needs Review (<60%)'
    END as ConfidenceLevel,
    COUNT(*) as BookCount,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Books WHERE IsActive = 1), 1) as Percentage
FROM Books 
WHERE IsActive = 1
GROUP BY 
    CASE 
        WHEN OverallConfidence >= 0.9 THEN 'Excellent (90%+)'
        WHEN OverallConfidence >= 0.8 THEN 'High (80-89%)'
        WHEN OverallConfidence >= 0.7 THEN 'Good (70-79%)'
        WHEN OverallConfidence >= 0.6 THEN 'Fair (60-69%)'
        ELSE 'Needs Review (<60%)'
    END
ORDER BY MIN(OverallConfidence) DESC;

-- LLM model performance comparison
SELECT 
    ModelName,
    ModelVersion,
    COUNT(*) as ClassificationsRun,
    AVG(ConfidenceScore) as AvgConfidence,
    AVG(ProcessingTime) as AvgProcessingTime,
    SUM(TokensUsed) as TotalTokens,
    SUM(CASE WHEN IsAccepted = 1 THEN 1 ELSE 0 END) as AcceptedCount,
    ROUND(SUM(CASE WHEN IsAccepted = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as AcceptanceRate
FROM LLMClassifications
GROUP BY ModelName, ModelVersion
ORDER BY AcceptanceRate DESC, AvgConfidence DESC;

-- ====================================
-- RELATIONSHIP & SIMILARITY ANALYSIS
-- ====================================

-- Find similar books to a specific title
WITH TargetBook AS (
    SELECT BookID FROM Books WHERE Title LIKE '%Python%' LIMIT 1
)
SELECT 
    b.Title,
    b.Author,
    c.CategoryName,
    br.RelationshipType,
    br.Strength,
    br.Source
FROM TargetBook tb
JOIN BookRelationships br ON tb.BookID = br.BookID1
JOIN Books b ON br.BookID2 = b.BookID
LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
WHERE br.IsActive = 1
ORDER BY br.Strength DESC;

-- Books that are frequently found together (co-occurrence analysis)
SELECT 
    b1.Title as Book1,
    b2.Title as Book2,
    COUNT(DISTINCT ba1.SessionID) as SharedSessions
FROM BookAnalytics ba1
JOIN BookAnalytics ba2 ON ba1.SessionID = ba2.SessionID 
    AND ba1.BookID < ba2.BookID
    AND ba1.EventType = 'view' 
    AND ba2.EventType = 'view'
JOIN Books b1 ON ba1.BookID = b1.BookID
JOIN Books b2 ON ba2.BookID = b2.BookID
WHERE ba1.SessionID IS NOT NULL
GROUP BY b1.BookID, b2.BookID
HAVING SharedSessions >= 3
ORDER BY SharedSessions DESC;

-- ====================================
-- USAGE ANALYTICS & INSIGHTS
-- ====================================

-- Most popular books by category
SELECT 
    c.CategoryName,
    b.Title,
    b.Author,
    b.ViewCount,
    b.DownloadCount,
    b.Rating,
    ROW_NUMBER() OVER (PARTITION BY c.CategoryName ORDER BY b.ViewCount DESC) as PopularityRank
FROM Books b
JOIN Categories c ON b.CategoryID = c.CategoryID
WHERE b.IsActive = 1
QUALIFY PopularityRank <= 3
ORDER BY c.CategoryName, PopularityRank;

-- Search trends analysis
SELECT 
    DATE(SearchDate) as SearchDay,
    SearchQuery,
    COUNT(*) as SearchCount,
    AVG(ResultsCount) as AvgResults,
    COUNT(DISTINCT ClickedBookID) as UniqueClicks
FROM SearchAnalytics
WHERE SearchDate >= DATE('now', '-30 days')
GROUP BY DATE(SearchDate), SearchQuery
HAVING SearchCount >= 2
ORDER BY SearchDay DESC, SearchCount DESC;

-- User engagement patterns
SELECT 
    EventType,
    COUNT(*) as EventCount,
    COUNT(DISTINCT BookID) as UniqueBooks,
    AVG(Duration) as AvgDuration
FROM BookAnalytics
WHERE EventDate >= DATE('now', '-7 days')
GROUP BY EventType
ORDER BY EventCount DESC;

-- ====================================
-- QUALITY CONTROL & CURATION
-- ====================================

-- Books with potential metadata issues
SELECT 
    b.FileName,
    b.Title,
    b.Author,
    CASE 
        WHEN b.Title IS NULL OR b.Title = '' THEN 'Missing Title'
        WHEN b.Author IS NULL OR b.Author = '' THEN 'Missing Author'
        WHEN b.CategoryID IS NULL THEN 'Unclassified'
        WHEN b.OverallConfidence < 0.5 THEN 'Low Confidence'
        WHEN b.FileHash IS NULL THEN 'Missing Hash'
        ELSE 'Unknown Issue'
    END as IssueType,
    b.ProcessingErrors,
    b.ProcessingFlags
FROM Books b
WHERE (b.Title IS NULL OR b.Title = ''
    OR b.Author IS NULL OR b.Author = ''
    OR b.CategoryID IS NULL
    OR b.OverallConfidence < 0.5
    OR b.FileHash IS NULL)
    AND b.IsActive = 1
ORDER BY b.OverallConfidence ASC;

-- Duplicate detection based on content similarity
SELECT 
    b1.Title as Title1,
    b2.Title as Title2,
    b1.Author as Author1,
    b2.Author as Author2,
    b1.FileHash,
    b2.FileHash,
    CASE 
        WHEN b1.FileHash = b2.FileHash THEN 'Identical Files'
        WHEN LOWER(b1.Title) = LOWER(b2.Title) AND LOWER(b1.Author) = LOWER(b2.Author) THEN 'Same Title+Author'
        ELSE 'Similar Content'
    END as DuplicateType
FROM Books b1
JOIN Books b2 ON b1.BookID < b2.BookID
WHERE (b1.FileHash = b2.FileHash
    OR (LOWER(b1.Title) = LOWER(b2.Title) AND LOWER(b1.Author) = LOWER(b2.Author)))
    AND b1.IsActive = 1 AND b2.IsActive = 1;

-- ====================================
-- RECOMMENDATION ENGINE QUERIES
-- ====================================

-- Content-based recommendations for a user's reading history
WITH UserHistory AS (
    -- Simulate user reading history
    SELECT DISTINCT BookID 
    FROM BookAnalytics 
    WHERE EventType = 'view' 
    AND SessionID = 'user_session_123'
),
UserCategories AS (
    SELECT CategoryID, COUNT(*) as CategoryScore
    FROM UserHistory uh
    JOIN Books b ON uh.BookID = b.BookID
    GROUP BY CategoryID
)
SELECT 
    b.Title,
    b.Author,
    c.CategoryName,
    b.Rating,
    b.OverallConfidence,
    uc.CategoryScore as UserCategoryAffinity
FROM Books b
JOIN Categories c ON b.CategoryID = c.CategoryID
JOIN UserCategories uc ON b.CategoryID = uc.CategoryID
WHERE b.BookID NOT IN (SELECT BookID FROM UserHistory)
    AND b.IsActive = 1
    AND b.OverallConfidence >= 0.8
ORDER BY uc.CategoryScore DESC, b.Rating DESC
LIMIT 10;

-- Find books that complete a user's knowledge gaps
SELECT 
    b.Title,
    b.Author,
    c.CategoryName,
    s.SubjectName,
    COUNT(br.BookID2) as RelatedBooksUserHas
FROM Books b
JOIN Categories c ON b.CategoryID = c.CategoryID
JOIN Subjects s ON b.SubjectID = s.SubjectID
LEFT JOIN BookRelationships br ON b.BookID = br.BookID1
    AND br.BookID2 IN (
        SELECT BookID FROM BookAnalytics 
        WHERE EventType = 'view' AND SessionID = 'user_session_123'
    )
WHERE b.BookID NOT IN (
    SELECT BookID FROM BookAnalytics 
    WHERE EventType = 'view' AND SessionID = 'user_session_123'
)
AND b.IsActive = 1
GROUP BY b.BookID
HAVING RelatedBooksUserHas >= 2
ORDER BY RelatedBooksUserHas DESC, b.Rating DESC;

-- ====================================
-- ADVANCED ANALYTICS
-- ====================================

-- Knowledge domain coverage analysis
SELECT 
    c.CategoryName,
    COUNT(DISTINCT s.SubjectID) as SubjectsCount,
    COUNT(DISTINCT b.BookID) as BooksCount,
    AVG(b.OverallConfidence) as AvgConfidence,
    SUM(b.ViewCount) as TotalViews,
    AVG(b.Rating) as AvgRating
FROM Categories c
LEFT JOIN Subjects s ON c.CategoryID = s.CategoryID AND s.IsActive = 1
LEFT JOIN Books b ON s.SubjectID = b.SubjectID AND b.IsActive = 1
WHERE c.IsActive = 1
GROUP BY c.CategoryID, c.CategoryName
ORDER BY BooksCount DESC;

-- Reading difficulty progression analysis
SELECT 
    c.CategoryName,
    ROUND(AVG(b.ReadingLevel), 1) as AvgReadingLevel,
    ROUND(AVG(b.ComplexityScore), 1) as AvgComplexity,
    COUNT(*) as BookCount,
    ROUND(AVG(b.PageCount), 0) as AvgPageCount
FROM Books b
JOIN Categories c ON b.CategoryID = c.CategoryID
WHERE b.IsActive = 1
    AND b.ReadingLevel IS NOT NULL
    AND b.ComplexityScore IS NOT NULL
GROUP BY c.CategoryID, c.CategoryName
ORDER BY AvgComplexity;

-- Collection growth over time
SELECT 
    DATE(DateAdded, 'start of month') as Month,
    COUNT(*) as BooksAdded,
    SUM(COUNT(*)) OVER (ORDER BY DATE(DateAdded, 'start of month')) as CumulativeBooks,
    AVG(OverallConfidence) as AvgConfidence
FROM Books
WHERE IsActive = 1
GROUP BY DATE(DateAdded, 'start of month')
ORDER BY Month;