# File: DebugThumbnailMismatch.py
# Path: Scripts/Database/DebugThumbnailMismatch.py
# Standard: AIDEV-PascalCase-1.8
# Created: 2025-07-03
# Last Modified: 2025-07-03  09:25PM
"""
Description: Debug Thumbnail Filename Mismatch
Identifies why some books show missing thumbnails when thumbnails should exist.
Compares database filenames with actual thumbnail filenames.

Author: Herb Bowers - Project Himalaya
Contact: HimalayaProject1@gmail.com
"""

import mysql.connector
from pathlib import Path
import os

# MySQL Configuration
MYSQL_CONFIG = {
    'host': 'localhost',
    'port': 3306,
    'user': 'workbench',
    'password': 'Workbench123!',
    'database': 'MyLibraryMaster',
    'charset': 'utf8mb4'
}

def DebugMissingThumbnails():
    """Debug why some thumbnails appear missing"""
    print("🔍 DEBUGGING THUMBNAIL FILENAME MISMATCHES")
    print("="*60)
    
    try:
        Connection = mysql.connector.connect(**MYSQL_CONFIG)
        Cursor = Connection.cursor()
        
        # Get books without thumbnails
        Cursor.execute("""
            SELECT BookID, FileName 
            FROM Books 
            WHERE HasThumbnail = 0 
            ORDER BY BookID 
            LIMIT 10
        """)
        
        MissingBooks = Cursor.fetchall()
        ThumbDir = Path("Data/Thumbs")
        
        print(f"📋 Found {len(MissingBooks)} books marked as missing thumbnails")
        print()
        
        for BookID, FileName in MissingBooks:
            BaseName = Path(FileName).stem
            ExpectedThumb = ThumbDir / f"{BaseName}.png"
            
            print(f"📚 Book ID {BookID}:")
            print(f"   Database filename: {FileName}")
            print(f"   Base name: {BaseName}")
            print(f"   Expected thumbnail: {ExpectedThumb}")
            print(f"   Thumbnail exists: {ExpectedThumb.exists()}")
            
            if not ExpectedThumb.exists():
                # Look for similar filenames
                print(f"   🔍 Looking for similar thumbnails...")
                
                # Try different variations
                SimilarFiles = []
                
                for ThumbFile in ThumbDir.glob("*.png"):
                    ThumbStem = ThumbFile.stem
                    if BaseName.lower() in ThumbStem.lower() or ThumbStem.lower() in BaseName.lower():
                        SimilarFiles.append(ThumbFile.name)
                
                if SimilarFiles:
                    print(f"   📁 Similar thumbnails found:")
                    for SimilarFile in SimilarFiles[:3]:
                        print(f"      • {SimilarFile}")
                else:
                    print(f"   ❌ No similar thumbnails found")
            
            print()
        
        Cursor.close()
        Connection.close()
        
    except Exception as DebugError:
        print(f"❌ Error debugging: {DebugError}")

def CheckThumbnailCounts():
    """Compare database vs filesystem thumbnail counts"""
    print("📊 THUMBNAIL COUNT COMPARISON")
    print("="*50)
    
    try:
        Connection = mysql.connector.connect(**MYSQL_CONFIG)
        Cursor = Connection.cursor()
        
        # Database counts
        Cursor.execute("SELECT COUNT(*) FROM Books WHERE HasThumbnail = 1")
        DbWithThumbs = Cursor.fetchone()[0]
        
        Cursor.execute("SELECT COUNT(*) FROM Books WHERE HasThumbnail = 0")
        DbWithoutThumbs = Cursor.fetchone()[0]
        
        # Filesystem count
        ThumbDir = Path("Data/Thumbs")
        ThumbFiles = list(ThumbDir.glob("*.png"))
        FileSystemThumbs = len(ThumbFiles)
        
        print(f"📊 Database Statistics:")
        print(f"   ✅ Books with thumbnails: {DbWithThumbs}")
        print(f"   ❌ Books without thumbnails: {DbWithoutThumbs}")
        print(f"   📚 Total books in database: {DbWithThumbs + DbWithoutThumbs}")
        print()
        print(f"📁 Filesystem Statistics:")
        print(f"   🖼️ Thumbnail files found: {FileSystemThumbs}")
        print()
        print(f"🔍 Analysis:")
        print(f"   Expected match rate: {FileSystemThumbs} thumbnails for {DbWithThumbs + DbWithoutThumbs} books")
        
        if FileSystemThumbs > (DbWithThumbs + DbWithoutThumbs):
            print(f"   ✨ You have MORE thumbnails than books! Perfect coverage possible.")
        elif FileSystemThumbs >= DbWithThumbs:
            print(f"   💡 Enough thumbnails exist - this is a filename matching issue")
        
        Cursor.close()
        Connection.close()
        
    except Exception as CountError:
        print(f"❌ Error checking counts: {CountError}")

def Main():
    """Main debugging function"""
    print("🏔️ PROJECT HIMALAYA - THUMBNAIL MISMATCH DEBUGGER")
    print("="*70)
    
    CheckThumbnailCounts()
    print()
    DebugMissingThumbnails()

if __name__ == "__main__":
    Main()
