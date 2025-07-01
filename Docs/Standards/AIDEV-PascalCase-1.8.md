# Standard: AIDEV-PascalCase-1.8

## Author & Project

**Author:** Herb Bowers  
**Project:** Project Himalaya  
**Contact:** HimalayaProject1@gmail.com

---

## Table of Contents

1. [Purpose & Philosophy](#purpose--philosophy)
2. [Header Format](#header-format)
3. [Naming Conventions](#naming-conventions)
4. [Design Standards](#design-standards)
5. [File & Directory Structure](#file--directory-structure)
6. [Project Setup Standards](#project-setup-standards)
7. [Development Environment](#development-environment)
8. [Imports & Dependencies](#imports--dependencies)
9. [Coding Style & Documentation](#coding-style--documentation)
10. [Testing & Quality](#testing--quality)
11. [SQL and Data Access](#sql-and-data-access)
12. [Third-Party Libraries & Ecosystem Exceptions](#third-party-libraries--ecosystem-exceptions)
13. [AI Collaboration Practices](#ai-collaboration-practices)
14. [Attribution & License](#attribution--license)
15. [Revision History](#revision-history)

---

## Purpose & Philosophy

This standard documents the unique code style, structure, and best practices for the Project Himalaya codebase.  

- **Philosophy:** My code, my way—clarity, maintainability, and personality matter.  
- **COD (Compulsive Order Disorder)** is a feature: consistent formatting, headers, and naming make the codebase navigable for humans, AI, and any future inheritors (post-apocalypse included).
- Where required, ecosystem and framework conventions are respected, but all other code follows these personal standards.

---

## Header Format

**ALL FILES** in the project must begin with a standardized header **immediately after the shebang** (for executable scripts). This includes Python (`.py`), shell scripts (`.sh`), markdown (`.md`), text files (`.txt`), configuration files, and any other project documents.

### Python Files (.py)
```python
# File: <FileName.py>
# Path: <Full/Path/From/ProjectRoot/FileName.py>
# Standard: AIDEV-PascalCase-1.8
# Created: YYYY-MM-DD
# Last Modified: YYYY-MM-DD  HH:MM[AM|PM]
"""
Description: <Short module/class/function description>
Extended details as needed.
"""
```

### Shell Scripts (.sh)
```bash
#!/bin/bash
# File: <ScriptName.sh>
# Path: <Full/Path/From/ProjectRoot/ScriptName.sh>
# Standard: AIDEV-PascalCase-1.8
# Created: YYYY-MM-DD
# Last Modified: YYYY-MM-DD  HH:MM[AM|PM]
# Description: <Short script description>
# Extended details as needed.
```

### Markdown/Documentation Files (.md, .txt, etc.)
```markdown
<!-- File: <DocumentName.md> -->
<!-- Path: <Full/Path/From/ProjectRoot/DocumentName.md> -->
<!-- Standard: AIDEV-PascalCase-1.8 -->
<!-- Created: YYYY-MM-DD -->
<!-- Last Modified: YYYY-MM-DD  HH:MM[AM|PM] -->
<!-- Description: <Short document description> -->
<!-- Extended details as needed. -->
```

### Configuration Files (JSON, YAML, etc.)
```json
// File: <ConfigName.json>
// Path: <Full/Path/From/ProjectRoot/ConfigName.json>
// Standard: AIDEV-PascalCase-1.8
// Created: YYYY-MM-DD
// Last Modified: YYYY-MM-DD  HH:MM[AM|PM]
// Description: <Short configuration description>
```

**CRITICAL:** The "Last Modified" timestamp **MUST** be updated every time the file is changed. This is not optional.

- **Timestamps:** Double space between date and time.
- **Path:** Always matches repo structure.
- **Format adaptation:** Use appropriate comment syntax for each file type.

---

## Naming Conventions

- **Files & Modules:** `PascalCase.py` (exceptions listed below)
- **Classes:** `PascalCase`
- **Functions & Methods:** `PascalCase`
- **Variables:** `PascalCase` (exceptions for globals: `g_VariableName`)
- **Constants:** `ALL_CAPS_WITH_UNDERSCORES`
- **Private:** Prefix with single underscore (`_PrivateVar`)
- **Database Names:** `PascalCase` (e.g., `ProjectHimalaya`, `UserData`)
- **Table Names:** `PascalCase` (e.g., `UserProfiles`, `DocumentMetadata`)
- **Column Names:** `PascalCase` (e.g., `FirstName`, `CreatedDate`, `UserId`)

### Filename Exceptions
Files should use `PascalCase` **unless** they would violate:
- **Long-standing Python conventions:** `__init__.py`, `setup.py`
- **Web/HTML standards:** `index.html`, `style.css` (if lowercase is required)
- **Third-party package requirements:** `test_*.py` (if required by pytest), `requirements.txt`
- **System conventions:** `.gitignore`, `Dockerfile`
- **Framework requirements:** When specific frameworks mandate particular naming patterns

When exceptions are used, document the reason in the file header.

---

## Design Standards

**Note:** These standards apply to all production code. Exception: 1-shot down and dirty scripts may deviate from these requirements when documented.

### Code Organization
- **Module size limit:** No module should exceed 300 lines of code
- **Single responsibility:** Modules should address unique sets of design elements
- **Cohesion:** Related functionality should be grouped together
- **Coupling:** Minimize dependencies between modules

### Database Design Principles
- **Normalization:** Databases should be normalized but not at excessive levels (typically 3NF, avoid over-normalization)
- **Change tracking:** Primary tables should track user changes (CreatedBy, CreatedDate, LastModifiedBy, LastModifiedDate)
- **Portability:** Build with consideration of porting to more sophisticated database engines (PostgreSQL, SQL Server)
- **Performance:** Maximize the use of tables and proper indexing to enhance access times
- **Audit trail:** Maintain comprehensive logging of data modifications

### Development Practices
- **Modularity:** Design for reusability and maintainability
- **Documentation:** Every design decision should be documented
- **Testing:** Design with testability in mind from the start
- **Scalability:** Consider future growth and performance requirements

---

## File & Directory Structure

- **Directory tree** documented at project root; updated as project evolves.
- **Directory names:** `PascalCase` unless system conventions require otherwise (e.g., `.git`, `node_modules`)
- Each directory can have a `README.md` summarizing its contents and purpose.
- Test files in `/Tests` directory, following header and naming conventions.

### Standard Project Directory Structure
```
.
├── ./Assets                    # Static assets (images, icons, etc.)
├── ./Config                    # Configuration files
├── ./Data/Database            # Database files and schemas
├── ./Legacy                   # Legacy code and deprecated files
├── ./library                  # Library/framework specific code
│   ├── ./library/admin        # Administrative interfaces
│   ├── ./library/app          # Application core
│   ├── ./library/assets       # Library-specific assets
│   ├── ./library/auth         # Authentication modules
│   ├── ./library/css          # Library stylesheets
│   ├── ./library/js           # Library JavaScript
│   └── ./library/setup        # Library setup and initialization
├── ./README.md                # Project documentation
├── ./requirements.txt         # Python dependencies
├── ./Scripts                  # Utility and maintenance scripts
│   ├── ./Scripts/Deployment   # Deployment automation
│   ├── ./Scripts/Development  # Development helpers
│   ├── ./Scripts/Maintenance  # Maintenance utilities
│   ├── ./Scripts/Migration    # Database migration scripts
│   └── ./Scripts/System       # System administration scripts
├── ./shared                   # Shared resources across modules
│   ├── ./shared/css          # Shared stylesheets
│   └── ./shared/js           # Shared JavaScript
├── ./Source                   # Main source code
│   ├── ./Source/AI           # AI/ML related modules
│   ├── ./Source/Core         # Core application logic
│   ├── ./Source/Interface    # User interface components
│   └── ./Source/Plugins      # Plugin architecture
├── ./Tests                   # Test suites and test data
├── ./Updates                 # Update scripts and changelogs
└── ./WebPages               # Web interface files
```

---

## Project Setup Standards

For new projects, provide a setup Python script that can be run inside a new project folder. The project name is derived from the base folder name. The setup script must:

### Setup Script Requirements (`SetupProject.py`)
1. **Create and activate a .venv environment**
2. **Create the standard file system structure** (see Directory Structure above)
3. **Create a .gitignore file** (see template below)
4. **Initialize git repository**
5. **Install any required pip libraries** from requirements.txt
6. **Create an attractive README for the project**

### Standard .gitignore Template
```gitignore
# [ProjectName] - .gitignore

# Python
**__pycache__**/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual Environments
venv/
env/
ENV/
.venv/
.env/

# IDEs
.vscode/
.idea/
*.swp
*.swo
*~

# [ProjectName] Specific (Digital Alexandria Architecture)
Data/Database/*.db
Data/Database/*.db-*
Data/Cache/
Data/Backups/
Logs/
*.log

# Sensitive Configuration
Config/Production/secrets.json
Config/Production/api_keys.json
.env
.env.local
.env.production

# AI Models (large files)
Source/AI/Models/*.bin
Source/AI/Models/*.pt
Source/AI/Models/*.h5
Source/AI/Training/

# Temporary Files
tmp/
temp/
*.tmp
*.temp

# OS Generated
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Coverage Reports
htmlcov/
.coverage
.coverage.*
coverage.xml
*.cover

# Testing
.pytest_cache/
.tox/

# Special exclusion for directories starting with '..'
..*/

# Project-specific exclusions
*.json
anderson-library-service-key.json
config/
secrets/

# Directories to ignore
Books/
Covers/
Thumbs/
node_modules/
```

---

## Development Environment

### Current Standard Development Environment
- **Laptop:** i7-13620H, 64GB RAM, RTX 4070, 4TB Multiple SSD
- **IDE:** Visual Studio Code
- **OS:** Ubuntu Desktop 25.04
- **Python:** Latest stable version with virtual environments
- **Version Control:** Git with standardized commit message format

### Environment Setup Requirements
- All development must use virtual environments (.venv)
- IDE configuration should support PascalCase conventions
- Linting and formatting tools should be configured to respect these standards
- GPU acceleration available for AI/ML workloads

---

## Imports & Dependencies

- **Import order:** standard library, third-party, project, local.
- **Grouped alphabetically.**
- **Multi-line imports:** Each import on its own line.
- **Use `isort`** (optional) for automation.
- **Dependencies:** Centralized in `requirements.txt` or `pyproject.toml`.

---

## Coding Style & Documentation

- **PEP8** is respected where it does not conflict with these standards.
- **Type hints** are strongly encouraged for all public functions.
- **All functions/classes** must have docstrings.
- **Minimum comment level:** All non-trivial logic is commented for intent.
- **Error handling:** Use `try/except` with clear logging, fail early if possible. Custom exceptions as needed.
- **Logging:** Prefer Python's `logging` module over print statements.

---

## Testing & Quality

- **All code must be covered by `pytest` unit tests.**
- **Test coverage goal:** 80%+
- **Test files follow header standard.**
- **Test data** (e.g., sample PDFs) stored in `/Tests/Data` with README as needed.
- **Performance/benchmark tests** included for GPU/CPU code as appropriate.

---

## SQL and Data Access

- **NO SQLAlchemy.**  
  - Use raw SQL and parameterized queries only.
  - SQLite is default.
- **ALL database elements follow PascalCase:**
  - **Database names:** `ProjectHimalaya`, `UserDataStore`
  - **Table names:** `UserProfiles`, `DocumentMetadata`, `SessionLogs`
  - **Column names:** `UserId`, `FirstName`, `LastModified`, `DocumentPath`
  - **Index names:** `Idx_UserProfiles_UserId`, `Idx_Documents_CreatedDate`
  - **Constraint names:** `FK_UserProfiles_UserId`, `UK_Users_Email`
- **Schema and migration scripts** have standard headers and live in `/Database` or `/Schema`.
- **SQL file naming:** `CreateUserProfilesTable.sql`, `UpdateSchema_v1_2.sql`

**Note:** While this deviates from traditional SQL lowercase conventions, maintaining PascalCase throughout the entire codebase provides visual consistency and reinforces the project's unified style philosophy.

---

## Third-Party Libraries & Ecosystem Exceptions

- **Where frameworks require specific conventions** (pytest, Flask, Django, etc.), those are followed and noted in file header with justification.
- **Special files** like `__init__.py`, `setup.py`, and `test_*.py` are exempt from PascalCase rule when tools explicitly require snake_case.
- **Web standards** that require lowercase (e.g., certain HTML/CSS files) are exempt when technical requirements mandate it.
- **Other third-party quirks** are documented inline and in module README if needed.
- **All exceptions must be justified** in the file header under "Exception Reason."

---

## AI Collaboration Practices

- Major changes generated or reviewed by AI (ChatGPT, Claude, etc.) are noted in the header or docstring.
- AI-generated refactoring/design is tracked via comments or commit messages for transparency.
- All contributors (human or AI) are acknowledged in the attribution section.

---

## Attribution & License

- Attribution and contact are included at the head of the standard and in each major module as needed.
- **License:** (insert your preferred open source license here, e.g., MIT, Apache 2.0)
- Special thanks to the open-source community and the AI models that help build and document this project.

---

## Revision History

- **1.6:** Original AIDEV-PascalCase Standards (Herb Bowers)
- **1.7:**  
  - Clarified ecosystem exceptions (special files, third-party libs)
  - Formalized "No SQLAlchemy" policy
  - Added sections on project structure, testing, and attribution
  - Baked in session-based clarifications and "Himalaya Addenda"
  - Updated header example and philosophy notes
- **1.8:**
  - **Extended PascalCase to ALL database elements** (databases, tables, columns, indexes, constraints)
  - **Mandated standardized headers for ALL file types** (.py, .sh, .md, .txt, config files, etc.)
  - **Emphasized critical importance of updating "Last Modified" timestamps**
  - **Clarified filename PascalCase rules with specific exceptions**
  - **Added comprehensive Design Standards section** (300-line module limit, database design principles)
  - **Defined standard project directory structure** (Assets, Source, Scripts, Tests, etc.)
  - **Added Project Setup Standards** (automated setup script requirements)
  - **Documented standard development environment** (Ubuntu 25.04, VS Code, hardware specs)
  - **Provided standard .gitignore template** with project-specific exclusions
  - Updated directory naming to PascalCase (`/Tests` instead of `/tests`)
  - Added comprehensive examples for different file type headers

---

*This standard is a living document. Updates are versioned, and the latest version governs all code, docs, and scripts for Project Himalaya. For changes, contact the author.*