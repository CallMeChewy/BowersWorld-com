// Data Integration Script for Anderson's Library
// Converts AI processing report to web-compatible JSON format

// This script reads the AILibraryProcessing_Report Excel file and converts it
// to a format that can be used by the web interface

class LibraryDataProcessor {
    constructor() {
        this.processedBooks = [];
        this.statistics = {
            totalBooks: 0,
            categorizedBooks: 0,
            highConfidenceBooks: 0,
            totalSizeMB: 0,
            categories: new Set(),
            subjects: new Set(),
            averageConfidence: 0
        };
    }

    // Process the Excel data from the AI processing report
    async processExcelData(excelData) {
        console.log('📊 Processing AI Library Report...');
        
        // Skip header row and process each book
        for (let i = 1; i < excelData.length; i++) {
            const row = excelData[i];
            
            // Map Excel columns to book object
            const book = this.createBookObject(row);
            
            if (book) {
                this.processedBooks.push(book);
                this.updateStatistics(book);
            }
        }
        
        this.calculateAverageConfidence();
        
        console.log(`✅ Processed ${this.processedBooks.length} books`);
        console.log(`📊 Statistics:`, this.statistics);
        
        return {
            books: this.processedBooks,
            statistics: this.statistics,
            lastUpdated: new Date().toISOString()
        };
    }

    createBookObject(row) {
        try {
            // Map Excel columns based on the processing report structure
            const [
                originalFilename,           // A
                suggestedTitle,            // B
                pdfTitle,                  // C
                currentCategory,           // D
                predictedCategory,         // E
                categoryConfidence,        // F
                currentSubject,            // G
                predictedSubject,          // H
                subjectConfidence,         // I
                similarBooks,              // J
                processingFlags,           // K
                contentSample,             // L
                overallConfidence,         // M
                actionNeeded,              // N
                fileSizeMB,                // O
                pageCount                  // P
            ] = row;

            // Skip empty rows
            if (!originalFilename || originalFilename.trim() === '') {
                return null;
            }

            const book = {
                // Basic Information
                filename: originalFilename,
                title: this.cleanTitle(suggestedTitle || pdfTitle || originalFilename),
                pdfTitle: pdfTitle || '',
                
                // Classification
                category: predictedCategory || currentCategory || 'Uncategorized',
                subject: predictedSubject || currentSubject || 'General',
                
                // Confidence Scores
                categoryConfidence: this.parseConfidence(categoryConfidence),
                subjectConfidence: this.parseConfidence(subjectConfidence),
                overallConfidence: this.parseConfidence(overallConfidence),
                
                // Related Information
                similarBooks: this.parseSimilarBooks(similarBooks),
                contentSample: contentSample || '',
                
                // Processing Information
                flags: this.parseFlags(processingFlags),
                actionNeeded: actionNeeded || '',
                
                // File Information
                fileSize: this.parseFileSize(fileSizeMB),
                pageCount: this.parsePageCount(pageCount),
                
                // Metadata
                id: this.generateBookId(originalFilename),
                slug: this.generateSlug(suggestedTitle || pdfTitle || originalFilename),
                addedDate: new Date().toISOString(),
                lastUpdated: new Date().toISOString(),
                
                // Status
                status: this.determineStatus(processingFlags, overallConfidence),
                needsReview: this.needsReview(processingFlags, categoryConfidence, subjectConfidence)
            };

            return book;
        } catch (error) {
            console.error('Error processing book row:', error, row);
            return null;
        }
    }

    cleanTitle(title) {
        if (!title) return 'Unknown Title';
        
        return title
            .replace(/\.pdf$/i, '')                    // Remove .pdf extension
            .replace(/\s+/g, ' ')                      // Normalize whitespace
            .replace(/^[^\w]+|[^\w]+$/g, '')           // Remove leading/trailing non-word chars
            .trim();
    }

    parseConfidence(confidenceStr) {
        if (!confidenceStr) return 0;
        
        // Handle percentage strings like "95.3%" or just numbers
        const match = String(confidenceStr).match(/(\d+\.?\d*)/);
        return match ? Math.min(100, Math.max(0, parseFloat(match[1]))) : 0;
    }

    parseSimilarBooks(similarBooksStr) {
        if (!similarBooksStr) return [];
        
        return String(similarBooksStr)
            .split(/[;,]/)                             // Split on semicolon or comma
            .map(book => book.trim())                  // Trim whitespace
            .filter(book => book.length > 0)          // Remove empty strings
            .slice(0, 5);                             // Limit to 5 similar books
    }

    parseFlags(flagsStr) {
        if (!flagsStr) return [];
        
        return String(flagsStr)
            .split(/[;,]/)
            .map(flag => flag.trim().toLowerCase().replace(/\s+/g, '_'))
            .filter(flag => flag.length > 0);
    }

    parseFileSize(sizeStr) {
        if (!sizeStr) return 0;
        
        const match = String(sizeStr).match(/(\d+\.?\d*)/);
        return match ? parseFloat(match[1]) : 0;
    }

    parsePageCount(countStr) {
        if (!countStr) return 0;
        
        const match = String(countStr).match(/(\d+)/);
        return match ? parseInt(match[1]) : 0;
    }

    generateBookId(filename) {
        // Create a consistent ID based on filename
        return filename
            .toLowerCase()
            .replace(/[^a-z0-9]/g, '_')
            .replace(/_+/g, '_')
            .replace(/^_|_$/g, '');
    }

    generateSlug(title) {
        // Create URL-friendly slug
        return title
            .toLowerCase()
            .replace(/[^\w\s-]/g, '')
            .replace(/\s+/g, '-')
            .replace(/-+/g, '-')
            .replace(/^-|-$/g, '');
    }

    determineStatus(flags, confidence) {
        if (flags && flags.length > 0) {
            return 'needs_review';
        }
        
        const conf = this.parseConfidence(confidence);
        if (conf >= 80) return 'verified';
        if (conf >= 50) return 'probable';
        return 'uncertain';
    }

    needsReview(flags, categoryConf, subjectConf) {
        if (flags && flags.length > 0) return true;
        
        const catConf = this.parseConfidence(categoryConf);
        const subConf = this.parseConfidence(subjectConf);
        
        return catConf < 60 || subConf < 60;
    }

    updateStatistics(book) {
        this.statistics.totalBooks++;
        
        if (book.category && book.category !== 'Uncategorized') {
            this.statistics.categorizedBooks++;
            this.statistics.categories.add(book.category);
        }
        
        if (book.subject && book.subject !== 'General') {
            this.statistics.subjects.add(book.subject);
        }
        
        if (book.overallConfidence >= 80) {
            this.statistics.highConfidenceBooks++;
        }
        
        this.statistics.totalSizeMB += book.fileSize;
    }

    calculateAverageConfidence() {
        if (this.processedBooks.length === 0) return;
        
        const totalConfidence = this.processedBooks.reduce(
            (sum, book) => sum + book.overallConfidence, 0
        );
        
        this.statistics.averageConfidence = Math.round(
            totalConfidence / this.processedBooks.length
        );
    }

    // Generate JavaScript file for web interface
    generateWebData() {
        const webData = {
            metadata: {
                totalBooks: this.statistics.totalBooks,
                lastUpdated: new Date().toISOString(),
                version: '1.0.0',
                source: 'AI Library Processing Report',
                averageConfidence: this.statistics.averageConfidence
            },
            statistics: {
                ...this.statistics,
                categories: Array.from(this.statistics.categories).sort(),
                subjects: Array.from(this.statistics.subjects).sort()
            },
            books: this.processedBooks
        };

        return `// Anderson's Library - Auto-generated book data
// Generated: ${new Date().toISOString()}
// Source: AI Library Processing Report

const LIBRARY_DATA = ${JSON.stringify(webData, null, 2)};

// Export for use in web interface
if (typeof module !== 'undefined' && module.exports) {
    module.exports = LIBRARY_DATA;
}

// Global variable for browser use
if (typeof window !== 'undefined') {
    window.LIBRARY_DATA = LIBRARY_DATA;
}

console.log('📚 Anderson\\'s Library Data Loaded:', LIBRARY_DATA.metadata);
`;
    }

    // Generate summary report
    generateSummaryReport() {
        const categories = Array.from(this.statistics.categories);
        const subjects = Array.from(this.statistics.subjects);
        
        return `
📚 ANDERSON'S LIBRARY - PROCESSING SUMMARY
Generated: ${new Date().toLocaleString()}

📊 OVERALL STATISTICS
═══════════════════════
• Total Books: ${this.statistics.totalBooks.toLocaleString()}
• Successfully Categorized: ${this.statistics.categorizedBooks.toLocaleString()} (${Math.round(this.statistics.categorizedBooks / this.statistics.totalBooks * 100)}%)
• High Confidence (80%+): ${this.statistics.highConfidenceBooks.toLocaleString()} (${Math.round(this.statistics.highConfidenceBooks / this.statistics.totalBooks * 100)}%)
• Total Collection Size: ${(this.statistics.totalSizeMB / 1000).toFixed(1)} GB
• Average AI Confidence: ${this.statistics.averageConfidence}%

📂 CATEGORIES (${categories.length})
═══════════════════════
${categories.map(cat => {
    const count = this.processedBooks.filter(book => book.category === cat).length;
    return `• ${cat}: ${count} books`;
}).join('\n')}

🏷️ SUBJECTS (${subjects.length})
═══════════════════════
${subjects.slice(0, 20).map(sub => {
    const count = this.processedBooks.filter(book => book.subject === sub).length;
    return `• ${sub}: ${count} books`;
}).join('\n')}
${subjects.length > 20 ? `... and ${subjects.length - 20} more subjects` : ''}

⚠️ ITEMS NEEDING REVIEW
═══════════════════════
${this.processedBooks.filter(book => book.needsReview).length} books need manual review

🔄 NEXT STEPS
═══════════════════════
1. Review and validate low-confidence categorizations
2. Upload processed data to Google Drive
3. Configure Firebase authentication
4. Deploy web interface to GitHub Pages
5. Set up user access controls

✅ Data processing complete! Ready for web deployment.
`;
    }

    // Filter books by criteria for targeted processing
    filterBooks(criteria = {}) {
        return this.processedBooks.filter(book => {
            if (criteria.needsReview && !book.needsReview) return false;
            if (criteria.category && book.category !== criteria.category) return false;
            if (criteria.minConfidence && book.overallConfidence < criteria.minConfidence) return false;
            if (criteria.maxConfidence && book.overallConfidence > criteria.maxConfidence) return false;
            if (criteria.hasFlags && book.flags.length === 0) return false;
            return true;
        });
    }

    // Export specific formats
    exportToCSV() {
        const headers = [
            'ID', 'Title', 'Filename', 'Category', 'Subject',
            'Category Confidence', 'Subject Confidence', 'Overall Confidence',
            'File Size (MB)', 'Page Count', 'Status', 'Needs Review', 'Flags'
        ];

        const rows = this.processedBooks.map(book => [
            book.id,
            book.title,
            book.filename,
            book.category,
            book.subject,
            book.categoryConfidence,
            book.subjectConfidence,
            book.overallConfidence,
            book.fileSize,
            book.pageCount,
            book.status,
            book.needsReview,
            book.flags.join('; ')
        ]);

        return [headers, ...rows].map(row => 
            row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(',')
        ).join('\n');
    }
}

// Usage example:
// const processor = new LibraryDataProcessor();
// const result = await processor.processExcelData(excelDataArray);
// const webDataJS = processor.generateWebData();
// const summary = processor.generateSummaryReport();

// Export the class
if (typeof module !== 'undefined' && module.exports) {
    module.exports = LibraryDataProcessor;
}

if (typeof window !== 'undefined') {
    window.LibraryDataProcessor = LibraryDataProcessor;
}