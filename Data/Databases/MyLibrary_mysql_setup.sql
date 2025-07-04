
-- MySQL Conversion Instructions
-- Generated: 2025-07-01T20:46:05.626926
-- Source: Data/Databases/MyLibrary.db

-- ===============================================
-- MYSQL CONVERSION WORKFLOW
-- ===============================================

-- 1. CONVERT SQLITE TO MYSQL
-- Use your SQLite-to-MySQL converter tool:
-- Input: Data/Databases/MyLibrary.db
-- Output: mylibrary_mysql.sql

-- 2. CREATE MYSQL DATABASE
CREATE DATABASE MyLibrary 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE anderson_library;

-- 3. IMPORT CONVERTED DATA
-- mysql -u username -p anderson_library < mylibrary_mysql.sql

-- 4. RUN ENHANCEMENTS
-- Execute the MySQL conversion enhancement script

-- ===============================================
-- POST-CONVERSION VERIFICATION QUERIES
-- ===============================================

-- Verify data integrity
SELECT 
    'Categories' as table_name, COUNT(*) as record_count 
FROM Categories WHERE IsActive = 1
UNION ALL
SELECT 
    'Subjects' as table_name, COUNT(*) as record_count 
FROM Subjects WHERE IsActive = 1
UNION ALL
SELECT 
    'Books' as table_name, COUNT(*) as record_count 
FROM Books WHERE IsActive = 1;

-- Test FULLTEXT search (after enhancement script)
-- SELECT Title, Author, 
--        MATCH(Title, Author, Publisher) AGAINST ('python') as relevance
-- FROM Books 
-- WHERE MATCH(Title, Author, Publisher) AGAINST ('python' IN NATURAL LANGUAGE MODE)
-- ORDER BY relevance DESC;

-- Verify foreign key relationships
SELECT 
    COUNT(DISTINCT b.CategoryID) as categories_used,
    COUNT(DISTINCT b.SubjectID) as subjects_used
FROM Books b 
WHERE b.IsActive = 1;

-- ===============================================
-- MYSQL WORKBENCH SETUP
-- ===============================================

-- 1. Connect to MySQL database
-- 2. Use "Database > Reverse Engineer" to create ER diagram
-- 3. Explore relationships visually
-- 4. Use Query tab for analysis
-- 5. Export documentation and diagrams

-- ===============================================
-- PERFORMANCE MONITORING
-- ===============================================

-- Monitor query performance
-- EXPLAIN SELECT * FROM Books WHERE Title LIKE '%python%';
-- EXPLAIN SELECT * FROM Books WHERE MATCH(Title) AGAINST ('python');

-- Check index usage
-- SHOW INDEX FROM Books;
-- SHOW INDEX FROM BookContent;

