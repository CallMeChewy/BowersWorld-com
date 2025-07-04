-- File: SimpleDisplayBookProcedure.sql
-- Path: Database/StoredProcedures/SimpleDisplayBookProcedure.sql
-- Standard: AIDEV-PascalCase-1.8
-- Created: 2025-07-03
-- Last Modified: 2025-07-03  08:25PM
-- Description: Simple stored procedure to display book without collation issues
-- Author: Herb Bowers - Project Himalaya

DELIMITER //

CREATE PROCEDURE DisplayBookSimple(IN BookId INT)
BEGIN
    DECLARE BookExists INT DEFAULT 0;
    
    -- Check if book exists
    SELECT COUNT(*) INTO BookExists 
    FROM Books WHERE BookID = BookId;
    
    IF BookExists = 0 THEN
        SELECT 'ERROR: Book not found' AS Message;
    ELSE
        -- Display book information
        SELECT 
            CONCAT('Book ID: ', B.BookID) AS BookInfo
        FROM Books B WHERE B.BookID = BookId
        UNION ALL
        SELECT 
            CONCAT('File Name: ', B.FileName)
        FROM Books B WHERE B.BookID = BookId
        UNION ALL
        SELECT 
            CONCAT('Title: ', B.Title)
        FROM Books B WHERE B.BookID = BookId
        UNION ALL
        SELECT 
            CONCAT('Author: ', COALESCE(A.AuthorName, 'Unknown'))
        FROM Books B 
        LEFT JOIN Authors A ON B.AuthorID = A.AuthorID 
        WHERE B.BookID = BookId
        UNION ALL
        SELECT 
            CONCAT('Publisher: ', COALESCE(P.PublisherName, 'Unknown'))
        FROM Books B 
        LEFT JOIN Publishers P ON B.PublisherID = P.PublisherID 
        WHERE B.BookID = BookId
        UNION ALL
        SELECT 
            CONCAT('Page Count: ', COALESCE(CAST(B.PageCount AS CHAR), 'Unknown'))
        FROM Books B WHERE B.BookID = BookId
        UNION ALL
        SELECT 
            CONCAT('File Size (MB): ', COALESCE(CAST(B.FileSizeMB AS CHAR), 'Unknown'))
        FROM Books B WHERE B.BookID = BookId;
    END IF;
END //

DELIMITER ;