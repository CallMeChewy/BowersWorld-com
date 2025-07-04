-- Create a comprehensive Books view with all related data
CREATE VIEW BooksDisplay AS
SELECT 
    b.BookID,
    b.FileName,
    b.Title,
    b.Subtitle,
    
    -- Author information
    a.AuthorName,
    
    -- Publisher information  
    p.PublisherName,
    
    -- Category information
    c.CategoryName,
    
    -- Publication details
    b.PublicationYear,
    b.CopyrightYear,
    b.Edition,
    b.Language,
    
    -- Identifiers
    b.PrimaryISBN,
    b.ExtractedISBN,
    b.ExtractedLCCN,
    b.ExtractedDOI,
    
    -- File details
    b.PageCount,
    b.FileSizeMB,
    b.FileSize,
    
    -- Content snippets (truncated for display)
    LEFT(b.FirstPageText, 200) AS FirstPagePreview,
    LEFT(b.ExtractedKeywords, 100) AS Keywords,
    
    -- Processing information
    b.ExtractionMethod,
    b.QualityScore,
    
    -- Asset availability
    b.HasCover,
    b.HasThumbnail,
    
    -- Access control
    b.AccessLevel,
    
    -- Timestamps
    b.CreatedDate,
    b.UpdatedDate

FROM Books b
LEFT JOIN Authors a ON b.AuthorID = a.AuthorID
LEFT JOIN Publishers p ON b.PublisherID = p.PublisherID  
LEFT JOIN Categories c ON b.CategoryID = c.CategoryID

ORDER BY b.Title;