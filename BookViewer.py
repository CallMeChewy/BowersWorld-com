# File: BookViewer.py
# Path: Scripts/Database/BookViewer.py
# Standard: AIDEV-PascalCase-1.8
# Created: 2025-07-03
# Last Modified: 2025-07-03  08:45PM
"""
Description: Enhanced Book Viewer - Special focus on Keywords, Category, Thumbnail
Clean, reliable solution for Anderson's Library book display with enhanced
classification and asset analysis capabilities.

Author: Herb Bowers - Project Himalaya
Contact: HimalayaProject1@gmail.com
"""

import mysql.connector
import sys

# MySQL Configuration
MYSQL_CONFIG = {
    'host': 'localhost',
    'port': 3306,
    'user': 'workbench',
    'password': 'Workbench123!',
    'database': 'MyLibraryMaster',
    'charset': 'utf8mb4'
}

def ViewBook(BookId: int) -> None:
    """
    Display a single book in maintenance format with special focus on
    Keywords, Category, and Thumbnail information
    
    Args:
        BookId: Book ID to display
    """
    try:
        Connection = mysql.connector.connect(**MYSQL_CONFIG)
        Cursor = Connection.cursor()
        
        # Enhanced query with subject, category, and thumbnail focus
        # Note: Removed database_subject as column doesn't exist
        Cursor.execute("""
            SELECT 
                B.BookID,
                B.FileName,
                B.Title,
                A.AuthorName,
                P.PublisherName,
                C.CategoryName,
                B.ExtractedKeywords,
                B.PublicationYear,
                B.PageCount,
                B.FileSizeMB,
                B.Language,
                B.PrimaryISBN,
                B.HasCover,
                B.HasThumbnail,
                B.AccessLevel
            FROM Books B
            LEFT JOIN Authors A ON B.AuthorID = A.AuthorID
            LEFT JOIN Publishers P ON B.PublisherID = P.PublisherID
            LEFT JOIN Categories C ON B.CategoryID = C.CategoryID
            WHERE B.BookID = %s
        """, (BookId,))
        
        Result = Cursor.fetchone()
        
        if not Result:
            print(f"❌ Book with ID {BookId} not found")
            return
        
        # Unpack results with enhanced fields
        (BookID, FileName, Title, AuthorName, PublisherName, 
         CategoryName, ExtractedKeywords, PublicationYear, PageCount, 
         FileSizeMB, Language, PrimaryISBN, HasCover, HasThumbnail, AccessLevel) = Result
        
        # Display in TRUE maintenance format - Field Name: Value
        # SPECIAL FOCUS: Subject, Category, Thumbnail
        print("="*70)
        print(f"📚 ANDERSON'S LIBRARY - BOOK RECORD #{BookID}")
        print("="*70)
        print()
        
        # === SPECIAL INTEREST FIELDS FIRST ===
        print("🔍 CLASSIFICATION & ASSETS:")
        print(f"Category: {CategoryName or 'Uncategorized'}")
        print(f"Keywords: {ExtractedKeywords or 'Not Specified'}")
        print(f"Has Thumbnail: {'Yes' if HasThumbnail else 'No'}")
        print(f"Has Cover: {'Yes' if HasCover else 'No'}")
        print()
        
        print("📖 BIBLIOGRAPHIC DETAILS:")
        print(f"Book ID: {BookID}")
        print(f"Title: {Title or 'Unknown'}")
        print(f"Author: {AuthorName or 'Unknown'}")
        print(f"Publisher: {PublisherName or 'Unknown'}")
        print(f"Publication Year: {PublicationYear or 'Unknown'}")
        print()
        
        print("📁 FILE INFORMATION:")
        print(f"File Name: {FileName or 'Unknown'}")
        print(f"Page Count: {PageCount or 'Unknown'}")
        print(f"File Size (MB): {f'{FileSizeMB:.2f}' if FileSizeMB else 'Unknown'}")
        print(f"Language: {Language or 'Unknown'}")
        print(f"Primary ISBN: {PrimaryISBN or 'Not Available'}")
        print(f"Access Level: {AccessLevel or 'Unknown'}")
        
        print()
        print("="*70)
        
        Cursor.close()
        Connection.close()
        
    except Exception as ViewError:
        print(f"❌ Error viewing book: {ViewError}")

def ListBooks() -> None:
    """List available books with category and thumbnail information"""
    try:
        Connection = mysql.connector.connect(**MYSQL_CONFIG)
        Cursor = Connection.cursor()
        
        # Enhanced query to show category and thumbnail in listing
        Cursor.execute("""
            SELECT BookID, Title, AuthorName, CategoryName, HasThumbnail
            FROM Books B
            LEFT JOIN Authors A ON B.AuthorID = A.AuthorID
            LEFT JOIN Categories C ON B.CategoryID = C.CategoryID
            ORDER BY BookID 
            LIMIT 60
        """)
        
        print("📚 Available Books with Category & Thumbnail Info:")
        print("-" * 75)
        print("ID   | Title                          | Author         | Category      | Thumb")
        print("-" * 75)
        
        for BookID, Title, AuthorName, CategoryName, HasThumbnail in Cursor.fetchall():
            TitleShort = (Title[:28] + "..") if Title and len(Title) > 28 else (Title or "Unknown")
            AuthorShort = (AuthorName[:12] + "..") if AuthorName and len(AuthorName) > 12 else (AuthorName or "Unknown")
            CategoryShort = (CategoryName[:12] + "..") if CategoryName and len(CategoryName) > 12 else (CategoryName or "None")
            ThumbStatus = "✓" if HasThumbnail else "✗"
            
            print(f"{BookID:4d} | {TitleShort:<30} | {AuthorShort:<14} | {CategoryShort:<13} | {ThumbStatus}")
        
        print("-" * 75)
        print("💡 Usage: python BookViewer.py <BookID> (focus on Category, Keywords, Thumbnail)")
        print("📁 ✓ = Has Thumbnail, ✗ = No Thumbnail")
        
        Cursor.close()
        Connection.close()
        
    except Exception as ListError:
        print(f"❌ Error listing books: {ListError}")

def SearchByCategory() -> None:
    """Show books grouped by category"""
    try:
        Connection = mysql.connector.connect(**MYSQL_CONFIG)
        Cursor = Connection.cursor()
        
        Cursor.execute("""
            SELECT 
                COALESCE(C.CategoryName, 'Uncategorized') AS Category,
                COUNT(*) AS BookCount,
                GROUP_CONCAT(CONCAT(B.BookID, ':', LEFT(B.Title, 30)) SEPARATOR ' | ') AS BookSample
            FROM Books B
            LEFT JOIN Categories C ON B.CategoryID = C.CategoryID
            GROUP BY C.CategoryName
            ORDER BY BookCount DESC
        """)
        
        print("📂 BOOKS BY CATEGORY:")
        print("=" * 80)
        
        for Category, BookCount, BookSample in Cursor.fetchall():
            print(f"\n📁 {Category} ({BookCount} books)")
            if BookSample:
                Samples = BookSample.split(' | ')[:3]  # Show first 3 books
                for Sample in Samples:
                    if ':' in Sample:
                        BookId, BookTitle = Sample.split(':', 1)
                        print(f"   • ID {BookId}: {BookTitle}")
        
        Cursor.close()
        Connection.close()
        
    except Exception as SearchError:
        print(f"❌ Error searching categories: {SearchError}")

def SearchThumbnails() -> None:
    """Show books with/without thumbnails"""
    try:
        Connection = mysql.connector.connect(**MYSQL_CONFIG)
        Cursor = Connection.cursor()
        
        print("🖼️ THUMBNAIL STATUS SUMMARY:")
        print("=" * 50)
        
        # Count books with thumbnails
        Cursor.execute("SELECT COUNT(*) FROM Books WHERE HasThumbnail = 1")
        WithThumbs = Cursor.fetchone()[0]
        
        Cursor.execute("SELECT COUNT(*) FROM Books WHERE HasThumbnail = 0")
        WithoutThumbs = Cursor.fetchone()[0]
        
        print(f"✅ Books WITH thumbnails: {WithThumbs}")
        print(f"❌ Books WITHOUT thumbnails: {WithoutThumbs}")
        print()
        
        # Show some books with thumbnails
        Cursor.execute("""
            SELECT BookID, Title 
            FROM Books 
            WHERE HasThumbnail = 1 
            ORDER BY BookID 
            LIMIT 10
        """)
        
        print("📋 Sample books WITH thumbnails:")
        for BookID, Title in Cursor.fetchall():
            TitleShort = (Title[:50] + "...") if Title and len(Title) > 50 else (Title or "Unknown")
            print(f"   ID {BookID}: {TitleShort}")
        
        Cursor.close()
        Connection.close()
        
    except Exception as ThumbError:
        print(f"❌ Error checking thumbnails: {ThumbError}")

def Main() -> None:
    """Main function with enhanced category/subject/thumbnail focus"""
    print("🏔️ PROJECT HIMALAYA - BOOK VIEWER")
    print("Special Focus: Category, Keywords, Thumbnail Analysis")
    print("="*50)
    
    if len(sys.argv) == 1:
        print("Usage: python BookViewer.py <BookID>")
        print("   or: python BookViewer.py list")
        print("   or: python BookViewer.py categories")
        print("   or: python BookViewer.py thumbnails")
        print()
        ListBooks()
        return
    
    Command = sys.argv[1].lower()
    
    if Command == 'list':
        ListBooks()
    elif Command == 'categories':
        SearchByCategory()
    elif Command == 'thumbnails':
        SearchThumbnails()
    else:
        try:
            BookId = int(sys.argv[1])
            ViewBook(BookId)
        except ValueError:
            print("❌ Please provide a valid book ID or command")
            print("📋 Commands: list, categories, thumbnails")
            print("🔍 Focus: Category, Keywords, Thumbnail analysis")
            ListBooks()

if __name__ == "__main__":
    Main()
