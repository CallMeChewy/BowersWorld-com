
-- Alexander's Library Database Schema - Future-Ready Edition
-- Standard: AIDEV-PascalCase-1.7

PRAGMA foreign_keys = ON;

-- Books table
CREATE TABLE IF NOT EXISTS Books (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL UNIQUE,
    suggested_title TEXT,
    pdf_title TEXT,
    pdf_author TEXT,
    pdf_subject TEXT,
    file_size_mb REAL,
    page_count INTEGER,
    extracted_isbn TEXT,
    extracted_year INTEGER,
    extracted_publisher TEXT,
    ai_confidence REAL,
    thumbnail BLOB,
    book_path TEXT,
    action_needed TEXT,
    flags TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Categories and Subjects
CREATE TABLE IF NOT EXISTS Categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS Subjects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL
);

-- Contributors
CREATE TABLE IF NOT EXISTS Contributors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    role TEXT DEFAULT 'author'
);

-- Many-to-Many Relationship Tables
CREATE TABLE IF NOT EXISTS BookCategories (
    book_id INTEGER,
    category_id INTEGER,
    FOREIGN KEY (book_id) REFERENCES Books(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES Categories(id) ON DELETE CASCADE,
    PRIMARY KEY (book_id, category_id)
);

CREATE TABLE IF NOT EXISTS BookSubjects (
    book_id INTEGER,
    subject_id INTEGER,
    FOREIGN KEY (book_id) REFERENCES Books(id) ON DELETE CASCADE,
    FOREIGN KEY (subject_id) REFERENCES Subjects(id) ON DELETE CASCADE,
    PRIMARY KEY (book_id, subject_id)
);

CREATE TABLE IF NOT EXISTS BookContributors (
    book_id INTEGER,
    contributor_id INTEGER,
    FOREIGN KEY (book_id) REFERENCES Books(id) ON DELETE CASCADE,
    FOREIGN KEY (contributor_id) REFERENCES Contributors(id) ON DELETE CASCADE,
    PRIMARY KEY (book_id, contributor_id)
);

-- Tags
CREATE TABLE IF NOT EXISTS Tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    source TEXT DEFAULT 'user'
);

CREATE TABLE IF NOT EXISTS BookTags (
    book_id INTEGER,
    tag_id INTEGER,
    FOREIGN KEY (book_id) REFERENCES Books(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES Tags(id) ON DELETE CASCADE,
    PRIMARY KEY (book_id, tag_id)
);

-- Usage Tracking
CREATE TABLE IF NOT EXISTS UsageStats (
    book_id INTEGER PRIMARY KEY,
    access_count INTEGER DEFAULT 0,
    first_accessed TEXT,
    last_accessed TEXT,
    FOREIGN KEY (book_id) REFERENCES Books(id) ON DELETE CASCADE
);

-- Full-Text Search
CREATE VIRTUAL TABLE IF NOT EXISTS FullText USING fts5(
    book_id UNINDEXED,
    content,
    content='',
    tokenize='porter'
);

-- System Info
CREATE TABLE IF NOT EXISTS SystemInfo (
    key TEXT PRIMARY KEY,
    value TEXT
);

-- Strategic Indexes
CREATE INDEX IF NOT EXISTS idx_books_suggested_title ON Books(suggested_title);
CREATE INDEX IF NOT EXISTS idx_books_extracted_isbn ON Books(extracted_isbn);
CREATE INDEX IF NOT EXISTS idx_books_action_needed ON Books(action_needed);
CREATE INDEX IF NOT EXISTS idx_books_created_at ON Books(created_at);
CREATE INDEX IF NOT EXISTS idx_booktags_tag_id ON BookTags(tag_id);
CREATE INDEX IF NOT EXISTS idx_usage_last_accessed ON UsageStats(last_accessed);
