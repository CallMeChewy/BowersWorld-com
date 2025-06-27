#!/usr/bin/env python3
"""
Complete Anderson's Library Collection Analysis and LC Enhancement Preparation
"""

import pandas as pd
import numpy as np
from pathlib import Path
import matplotlib.pyplot as plt
import seaborn as sns

def analyze_complete_collection():
    """Analyze the complete 1,219 PDF collection"""
    
    csv_path = "/home/herb/Desktop/BowersWorld-com/AndersonLibrary_PDFMetadata.csv"
    
    print("📚 Anderson's Library - Complete Collection Analysis")
    print("=" * 70)
    
    # Load the complete dataset
    try:
        df = pd.read_csv(csv_path)
        print(f"✅ Loaded {len(df)} PDF records - COMPLETE COLLECTION!")
    except Exception as e:
        print(f"❌ Error loading CSV: {e}")
        return
    
    print()
    print("🎯 COLLECTION OVERVIEW:")
    print("-" * 50)
    print(f"📚 Total books: {len(df)}")
    
    # File statistics
    df['file_size_mb'] = pd.to_numeric(df['file_size_mb'], errors='coerce')
    df['page_count'] = pd.to_numeric(df['page_count'], errors='coerce')
    
    total_size_gb = df['file_size_mb'].sum() / 1024
    avg_size_mb = df['file_size_mb'].mean()
    total_pages = df['page_count'].sum()
    avg_pages = df['page_count'].mean()
    
    print(f"💾 Total collection size: {total_size_gb:.1f} GB")
    print(f"📄 Average file size: {avg_size_mb:.1f} MB")
    print(f"📖 Total pages: {total_pages:,} pages")
    print(f"📖 Average pages per book: {avg_pages:.0f} pages")
    
    print()
    print("📈 METADATA EXTRACTION SUCCESS RATES:")
    print("-" * 50)
    
    # Calculate success rates for the complete collection
    pdf_titles = df['pdf_title'].notna() & (df['pdf_title'].str.strip() != '')
    pdf_authors = df['pdf_author'].notna() & (df['pdf_author'].str.strip() != '')
    extracted_isbns = df['extracted_isbn'].notna() & (df['extracted_isbn'].str.strip() != '')
    extracted_years = df['extracted_year'].notna()
    extracted_publishers = df['extracted_publisher'].notna() & (df['extracted_publisher'].str.strip() != '')
    
    total = len(df)
    print(f"📖 PDF Titles: {pdf_titles.sum()}/{total} ({pdf_titles.sum()/total*100:.1f}%)")
    print(f"✍️ PDF Authors: {pdf_authors.sum()}/{total} ({pdf_authors.sum()/total*100:.1f}%)")
    print(f"🔢 ISBNs: {extracted_isbns.sum()}/{total} ({extracted_isbns.sum()/total*100:.1f}%)")
    print(f"📅 Years: {extracted_years.sum()}/{total} ({extracted_years.sum()/total*100:.1f}%)")
    print(f"🏢 Publishers: {extracted_publishers.sum()}/{total} ({extracted_publishers.sum()/total*100:.1f}%)")
    
    print()
    print("📅 PUBLICATION TIMELINE:")
    print("-" * 50)
    
    years = df['extracted_year'].dropna()
    # Filter to only numeric years (4-digit years between 1000-2100)
    numeric_years = pd.to_numeric(years, errors='coerce')
    valid_years = numeric_years[(numeric_years >= 1000) & (numeric_years <= 2100)]
    
    if len(valid_years) > 0:
        print(f"📊 Years extracted: {len(years)} books ({len(valid_years)} valid years)")
        print(f"📅 Earliest: {int(valid_years.min())}")
        print(f"📅 Latest: {int(valid_years.max())}")
        print(f"📅 Median year: {int(valid_years.median())}")
        
        # Decade breakdown
        print("\n📈 By decade:")
        decade_counts = ((valid_years // 10) * 10).value_counts().sort_index()
        for decade, count in decade_counts.tail(6).items():  # Last 6 decades
            print(f"  {int(decade)}s: {count} books")
    
    print()
    print("🎯 LIBRARY OF CONGRESS READINESS ASSESSMENT:")
    print("-" * 50)
    
    # Enhanced readiness assessment for complete collection
    # High confidence: Has title AND (author OR ISBN OR year)
    high_confidence = (
        pdf_titles & 
        (pdf_authors | extracted_isbns | extracted_years)
    )
    
    # Medium confidence: Has title OR (author AND year) OR ISBN
    medium_confidence = (
        ~high_confidence & 
        (pdf_titles | (pdf_authors & extracted_years) | extracted_isbns)
    )
    
    # Excellent confidence: Has title AND author AND (ISBN OR year)
    excellent_confidence = (
        pdf_titles & pdf_authors & (extracted_isbns | extracted_years)
    )
    
    low_confidence = ~(high_confidence | medium_confidence)
    
    print(f"🏆 EXCELLENT (Title + Author + ISBN/Year): {excellent_confidence.sum()} books")
    print(f"🟢 HIGH confidence: {high_confidence.sum()} books")
    print(f"🟡 MEDIUM confidence: {medium_confidence.sum()} books")
    print(f"🔴 LOW confidence: {low_confidence.sum()} books")
    
    print()
    print("📊 LC ENHANCEMENT STRATEGY:")
    print("-" * 50)
    
    # Calculate expected LC success rates
    isbn_books = extracted_isbns.sum()
    title_author_books = (pdf_titles & pdf_authors).sum()
    title_only_books = (pdf_titles & ~pdf_authors).sum()
    
    # Estimated LC success rates based on data quality
    estimated_isbn_success = isbn_books * 0.85  # 85% success for ISBN lookups
    estimated_title_author_success = title_author_books * 0.75  # 75% for title+author
    estimated_title_only_success = title_only_books * 0.50  # 50% for title only
    
    total_estimated_success = estimated_isbn_success + estimated_title_author_success + estimated_title_only_success
    
    print(f"📚 Books with ISBNs: {isbn_books} (expected 85% LC success)")
    print(f"📚 Books with Title+Author: {title_author_books} (expected 75% LC success)")
    print(f"📚 Books with Title only: {title_only_books} (expected 50% LC success)")
    print(f"🎯 ESTIMATED LC ENHANCEMENT: ~{total_estimated_success:.0f} books ({total_estimated_success/total*100:.1f}%)")
    
    print()
    print("📖 SAMPLE HIGH-QUALITY RECORDS:")
    print("-" * 50)
    
    # Show best examples
    excellent_samples = df[excellent_confidence].head(5)
    for idx, row in excellent_samples.iterrows():
        print(f"\n📚 {row['filename']}")
        if pd.notna(row['pdf_title']) and row['pdf_title'].strip():
            print(f"   📖 Title: {row['pdf_title']}")
        if pd.notna(row['pdf_author']) and row['pdf_author'].strip():
            print(f"   ✍️ Author: {row['pdf_author']}")
        if pd.notna(row['extracted_isbn']) and row['extracted_isbn'].strip():
            print(f"   🔢 ISBN: {row['extracted_isbn']}")
        if pd.notna(row['extracted_year']):
            print(f"   📅 Year: {int(row['extracted_year'])}")
        if pd.notna(row['extracted_publisher']) and row['extracted_publisher'].strip():
            print(f"   🏢 Publisher: {row['extracted_publisher']}")
    
    print()
    print("🚀 NEXT PHASE PREPARATION:")
    print("-" * 50)
    print("1. ✅ Complete PDF metadata extraction (DONE!)")
    print("2. 🔄 Library of Congress API integration")
    print("3. 🔄 Batch LC data enhancement")
    print("4. 🔄 Manual curation and verification")
    print("5. 🔄 Database schema enhancement")
    print("6. 🔄 Professional catalog integration")
    
    return df

def create_lc_enhancement_queue(df):
    """Create prioritized queue for LC enhancement"""
    
    output_path = "/home/herb/Desktop/BowersWorld-com/AndersonLibrary_LCEnhancementQueue.xlsx"
    
    print("\n🔧 Creating LC Enhancement Queue...")
    print("-" * 50)
    
    # Clean and prepare data
    df_clean = df.copy()
    
    # Clean text fields
    text_columns = ['pdf_title', 'pdf_author', 'pdf_subject', 'pdf_creator', 'pdf_producer', 
                   'extracted_publisher', 'first_page_text', 'title_page_text', 'copyright_page_text']
    
    for col in text_columns:
        if col in df_clean.columns:
            df_clean[col] = df_clean[col].fillna('').astype(str)
            # Remove problematic characters for Excel
            df_clean[col] = df_clean[col].str.replace(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]', '', regex=True)
            # Limit length
            df_clean[col] = df_clean[col].str[:32767]
    
    # Create priority scoring
    df_clean['lc_priority_score'] = 0
    
    # Add points for data quality
    df_clean.loc[df_clean['pdf_title'].str.len() > 0, 'lc_priority_score'] += 10
    df_clean.loc[df_clean['pdf_author'].str.len() > 0, 'lc_priority_score'] += 10  
    df_clean.loc[df_clean['extracted_isbn'].notna() & (df_clean['extracted_isbn'].str.len() > 0), 'lc_priority_score'] += 20
    df_clean.loc[df_clean['extracted_year'].notna(), 'lc_priority_score'] += 5
    df_clean.loc[df_clean['extracted_publisher'].str.len() > 0, 'lc_priority_score'] += 5
    
    # Sort by priority (highest first)
    df_sorted = df_clean.sort_values('lc_priority_score', ascending=False)
    
    # Add LC enhancement columns
    df_sorted['lc_search_query'] = ''
    df_sorted['lc_api_status'] = 'pending'
    df_sorted['lc_match_found'] = ''
    df_sorted['lc_confidence'] = ''
    df_sorted['lc_title'] = ''
    df_sorted['lc_author'] = ''
    df_sorted['lc_subjects'] = ''
    df_sorted['lc_classification'] = ''
    df_sorted['lc_isbn'] = ''
    df_sorted['lc_publisher'] = ''
    df_sorted['lc_year'] = ''
    df_sorted['lc_description'] = ''
    df_sorted['manual_notes'] = ''
    df_sorted['verification_status'] = 'pending'
    
    # Select and reorder columns for LC workflow
    lc_columns = [
        'filename', 'lc_priority_score',
        'pdf_title', 'pdf_author', 'extracted_isbn', 'extracted_year', 'extracted_publisher',
        'lc_search_query', 'lc_api_status', 'lc_match_found', 'lc_confidence',
        'lc_title', 'lc_author', 'lc_subjects', 'lc_classification', 
        'lc_isbn', 'lc_publisher', 'lc_year', 'lc_description',
        'manual_notes', 'verification_status',
        'file_size_mb', 'page_count', 'extraction_method'
    ]
    
    # Keep only available columns
    available_columns = [col for col in lc_columns if col in df_sorted.columns]
    lc_queue = df_sorted[available_columns]
    
    # Save the enhancement queue
    try:
        lc_queue.to_excel(output_path, index=False, engine='openpyxl')
        print(f"✅ LC Enhancement Queue saved: {output_path}")
        
        # Print priority breakdown
        high_priority = (lc_queue['lc_priority_score'] >= 30).sum()
        medium_priority = ((lc_queue['lc_priority_score'] >= 20) & (lc_queue['lc_priority_score'] < 30)).sum()
        low_priority = (lc_queue['lc_priority_score'] < 20).sum()
        
        print(f"\n📊 Priority Breakdown:")
        print(f"   🏆 High Priority (30+ points): {high_priority} books")
        print(f"   🟡 Medium Priority (20-29 points): {medium_priority} books")
        print(f"   ⚪ Low Priority (<20 points): {low_priority} books")
        
    except Exception as e:
        print(f"❌ Error saving Excel: {e}")
        # Fallback to CSV
        csv_path = output_path.replace('.xlsx', '.csv')
        lc_queue.to_csv(csv_path, index=False)
        print(f"✅ Saved as CSV instead: {csv_path}")
    
    return lc_queue

if __name__ == "__main__":
    # Analyze the complete collection
    df = analyze_complete_collection()
    
    if df is not None:
        # Create LC enhancement queue
        lc_queue = create_lc_enhancement_queue(df)
        
        print(f"\n🎉 ANALYSIS COMPLETE!")
        print(f"📊 Full metadata: AndersonLibrary_PDFMetadata.csv")
        print(f"🚀 LC queue ready: AndersonLibrary_LCEnhancementQueue.xlsx")
        print(f"\n🏛️ Ready to begin Library of Congress data enhancement!")