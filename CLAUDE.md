# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BowersWorld-com is a digital library project implementing the "Digital Alexandria" architecture. This is a Python-based web application using FastAPI to serve a digital book collection with AI-powered features.

## Key Commands

### Development Server

```bash
# Start main application (FastAPI web server)
python DigitalAlexandria.py

# Start with development mode
python DigitalAlexandria.py web --dev

# Start API server
python DigitalAlexandria.py api --docs
```

### Setup and Dependencies

```bash
# Install dependencies
pip install -r requirements.txt

# Initialize system with sample data
python DigitalAlexandria.py setup --sample-data

# Create database backup
python DigitalAlexandria.py admin --backup
```

### Testing

```bash
# Run tests (when test framework is implemented)
pytest Tests/

# Run database optimization
python DigitalAlexandria.py admin --optimize
```

## Architecture Overview

### High-Level Structure

The project follows a layered architecture pattern:

- **Interface Layer**: Web interface (FastAPI), Desktop app integration, API endpoints
- **AI Intelligence Layer**: Book classification, semantic search, content analysis
- **Core Foundation Layer**: Database management, configuration, logging
- **Data Layer**: SQLite database with FTS5 full-text search, file storage

### Key Directories

- `Source/Core/`: Foundation components (Application.py, Database, Configuration)
- `Source/AI/`: AI-powered features (classification, discovery, analytics)
- `Source/Interface/`: User interfaces (Web, Desktop, API)
- `Data/`: Database files, book storage, covers, cache
- `Config/`: Environment-specific configuration files
- `Legacy/`: Integration with existing Andy.py desktop application

### Database Schema

The project uses SQLite with FTS5 for full-text search:

- **Books table**: Enhanced metadata with AI analysis fields
- **BookRelationships**: Knowledge graph connections between books  
- **Users, Annotations, Collections**: Multi-user collaboration features
- **BookAnalytics**: Usage tracking and metrics

## Development Standards

### Coding Convention

The project follows **AIDEV-PascalCase-1.7** standards:

- Files/Modules: PascalCase.py
- Classes: PascalCase
- Functions/Methods: PascalCase
- Variables: PascalCase
- Constants: ALLCAPSWITHUNDERSCORES

### File Headers

All Python files should include standardized headers with:

- File path and creation/modification dates
- Author information (Herb Bowers - Project Himalaya)
- Purpose and dependency information
- AIDEV-PascalCase-1.7 standard compliance

## Important Implementation Notes

### Entry Points

- `DigitalAlexandria.py`: Main application entry point with command-line interface
- `BowersWorldSetup.py`: Project foundation setup script (creates full structure)
- `index.html`: Static web page for GitHub Pages deployment

### Configuration

- `alexandria_config.json`: Main project configuration
- `Config/Development/` and `Config/Production/`: Environment-specific settings
- Environment variables supported for database path, logging level, etc.

### AI Features

The system is designed for AI-powered book management:

- Automatic classification and tagging
- Semantic similarity analysis
- Knowledge graph relationship mapping
- Content analysis and quality scoring

### Legacy Integration

The project includes integration pathways for existing Andy.py desktop library application, with migration tools planned for `Legacy/Migration/`.

## Development Workflow

1. Follow AIDEV-PascalCase-1.7 naming conventions
2. Add proper type hints and docstrings to all functions
3. Update configuration files when adding new features
4. Test database operations with the built-in admin commands
5. Use the layered architecture - avoid tight coupling between layers

## Notes for Future Development

This is a comprehensive digital library system designed for long-term knowledge preservation. The architecture prioritizes:

- Extensibility through plugin system
- Future-proof data formats (SQLite, JSON)
- Comprehensive documentation and standards
- AI-powered enhancement of traditional library functions