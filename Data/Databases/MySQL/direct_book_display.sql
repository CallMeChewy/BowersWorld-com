-- File: DirectBookDisplay.sql  
-- Path: Database/Queries/DirectBookDisplay.sql
-- Standard: AIDEV-PascalCase-1.8
-- Created: 2025-07-03
-- Last Modified: 2025-07-03  08:15PM
-- Description: Direct book display query without requiring BooksDisplay view
-- Author: Herb Bowers - Project Himalaya

-- Set the BookID you want to display
SET @BookID = 1;

-- Direct query using base tables
SELECT 'Field Name' AS Field, 'Value' AS Data
UNION ALL
SELECT 'Book ID', CAST(B.BookID AS CHAR)
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'File Name', B.FileName
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Title', B.Title
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Subtitle', COALESCE(B.Subtitle, 'Not Available')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Author', COALESCE(A.AuthorName, 'Unknown')
FROM Books B LEFT JOIN Authors A ON B.AuthorID = A.AuthorID WHERE B.BookID = @BookID
UNION ALL
SELECT 'Publisher', COALESCE(P.PublisherName, 'Unknown')
FROM Books B LEFT JOIN Publishers P ON B.PublisherID = P.PublisherID WHERE B.BookID = @BookID
UNION ALL
SELECT 'Category', COALESCE(C.CategoryName, 'Uncategorized')
FROM Books B LEFT JOIN Categories C ON B.CategoryID = C.CategoryID WHERE B.BookID = @BookID
UNION ALL
SELECT 'Publication Year', COALESCE(CAST(B.PublicationYear AS CHAR), 'Unknown')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Copyright Year', COALESCE(CAST(B.CopyrightYear AS CHAR), 'Unknown')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Edition', COALESCE(B.Edition, 'Not Specified')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Language', COALESCE(B.Language, 'Unknown')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Primary ISBN', COALESCE(B.PrimaryISBN, 'Not Available')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Extracted ISBN', COALESCE(B.ExtractedISBN, 'Not Available')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'LCCN', COALESCE(B.ExtractedLCCN, 'Not Available')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'DOI', COALESCE(B.ExtractedDOI, 'Not Available')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Page Count', COALESCE(CAST(B.PageCount AS CHAR), 'Unknown')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'File Size (MB)', COALESCE(CAST(B.FileSizeMB AS CHAR), 'Unknown')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Keywords', COALESCE(LEFT(B.ExtractedKeywords, 100), 'None')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Quality Score', COALESCE(CAST(B.QualityScore AS CHAR), 'Not Rated')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Has Cover', IF(B.HasCover, 'Yes', 'No')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Has Thumbnail', IF(B.HasThumbnail, 'Yes', 'No')
FROM Books B WHERE B.BookID = @BookID
UNION ALL
SELECT 'Access Level', COALESCE(B.AccessLevel, 'Unknown')
FROM Books B WHERE B.BookID = @BookID
-- Note: Removed CreatedDate and UpdatedDate - columns may not exist in table