# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**BowersWorld-com** (codename: Digital Alexandria) is a comprehensive digital library management system built with Python. The system manages Anderson's Library Collection with AI-powered classification, full-text search, and modern web interfaces.

## Key Commands

### Starting the Application
```bash
python DigitalAlexandria.py
```
Main entry point that starts the FastAPI web server on localhost:8080

### Development Setup
```bash
pip install -r requirements.txt
```
Install all required dependencies including FastAPI, SQLAlchemy, spaCy, transformers, and other ML libraries

### Data Migration
```bash
python MigrateToEnhancedSchema.py
```
Migrates existing library data to the enhanced database schema with AI classification support

### Code Quality
```bash
python -m flake8 .
python -m black .
python -m pytest
```
Standard Python linting, formatting, and testing commands (configurations may exist in project)

## Architecture

### Core Structure
- **Source/**: Main application code (currently empty directories for Core/, AI/, Interface/, Plugins/)
- **Scripts/**: Utility scripts for deployment, development, maintenance, migration, and system tasks
- **CreateLibraryCSV/**: Data processing scripts for PDF metadata extraction and library analysis
- **Data/**: Library data including Books/, Covers/, and book metadata
- **Config/**: Configuration files
- **WebPages/**: Web interface files

### Technology Stack
- **Backend**: FastAPI with Python 3.11+
- **Database**: SQLite with full-text search capabilities
- **AI/ML**: spaCy, transformers, sentence-transformers for NLP and semantic search
- **Data Processing**: pandas, PyMuPDF for PDF handling
- **Web Framework**: FastAPI (backend), planned React frontend
- **Desktop Legacy**: PySide6 for desktop interface (Andy.py)

### Key Configuration Files
- `alexandria_config.json`: Main project configuration with architecture patterns and feature flags
- `search_engine_config.json`: API endpoints and search system configuration including Open Library, Google Books APIs
- `requirements.txt`: Python dependencies with ML/AI libraries

### Data Flow
1. PDF metadata extraction via `Resumable PDF Metadata Extractor.py`
2. Library analysis through `Complete Anderson's Library Collection Analysis.py`
3. Database migration using `MigrateToEnhancedSchema.py`
4. Web interface served through `DigitalAlexandria.py`

## Important Notes

- Uses AIDEV-PascalCase-1.7/1.8 coding standard
- Includes comprehensive book metadata from Anderson's Library Collection
- Supports multiple API integrations (Open Library, Google Books, Library of Congress)
- Features AI-powered book classification and semantic search
- Plugin system architecture with hook-based extensions planned
- Multi-user collaboration features planned

## Database Schema
The system uses an enhanced SQLite schema supporting:
- Full-text search capabilities
- AI classification metadata
- Book metadata with covers and thumbnails
- User management and collaboration features