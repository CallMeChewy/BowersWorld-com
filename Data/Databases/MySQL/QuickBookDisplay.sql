
-- File: QuickBookDisplay.sql
-- Path: Database/Queries/QuickBookDisplay.sql
-- Standard: AIDEV-PascalCase-1.8
-- Created: 2025-07-03
-- Last Modified: 2025-07-03  07:35PM
-- Description: Quick single book display query for maintenance view
-- Author: Herb Bowers - Project Himalaya

-- Quick Book Display Query - Set BookID and run
-- Replace @BookID with the actual book ID you want to view

SET @BookID = 1;  -- Change this to the BookID you want to display

SELECT 'Field Name' AS Field, 'Value' AS Data
UNION ALL
SELECT 'Book ID', CAST(BookID AS CHAR)
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'File Name', FileName
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Title', Title
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Subtitle', COALESCE(Subtitle, 'Not Available')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Author', COALESCE(AuthorName, 'Unknown')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Publisher', COALESCE(PublisherName, 'Unknown')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Category', COALESCE(CategoryName, 'Uncategorized')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Publication Year', COALESCE(CAST(PublicationYear AS CHAR), 'Unknown')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Copyright Year', COALESCE(CAST(CopyrightYear AS CHAR), 'Unknown')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Edition', COALESCE(Edition, 'Not Specified')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Language', COALESCE(Language, 'Unknown')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Primary ISBN', COALESCE(PrimaryISBN, 'Not Available')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Extracted ISBN', COALESCE(ExtractedISBN, 'Not Available')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'LCCN', COALESCE(ExtractedLCCN, 'Not Available')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'DOI', COALESCE(ExtractedDOI, 'Not Available')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Page Count', COALESCE(CAST(PageCount AS CHAR), 'Unknown')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'File Size (MB)', COALESCE(CAST(FileSizeMB AS CHAR), 'Unknown')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Keywords', COALESCE(LEFT(Keywords, 100), 'None')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Quality Score', COALESCE(CAST(QualityScore AS CHAR), 'Not Rated')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Has Cover', IF(HasCover, 'Yes', 'No')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Has Thumbnail', IF(HasThumbnail, 'Yes', 'No')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Access Level', COALESCE(AccessLevel, 'Unknown')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Created Date', COALESCE(DATE_FORMAT(CreatedDate, '%Y-%m-%d %H:%i:%s'), 'Unknown')
FROM BooksDisplay WHERE BookID = @BookID
UNION ALL
SELECT 'Updated Date', COALESCE(DATE_FORMAT(UpdatedDate, '%Y-%m-%d %H:%i:%s'), 'Unknown')
FROM BooksDisplay WHERE BookID = @BookID;