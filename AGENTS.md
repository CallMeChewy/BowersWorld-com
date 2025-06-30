# AGENTS.md - BowersWorld-com Development Guide

## Build/Test Commands
```bash
# Install dependencies
pip install -r requirements.txt

# Start development server
python DigitalAlexandria.py

# Run tests (when implemented)
pytest Tests/

# Run single test file
pytest Tests/test_specific.py

# Database operations
python DigitalAlexandria.py admin --optimize
python DigitalAlexandria.py setup --sample-data
```

## Code Style Guidelines (AIDEV-PascalCase-1.7)
- **Files/Modules**: PascalCase.py
- **Classes**: PascalCase
- **Functions/Methods**: PascalCase  
- **Variables**: PascalCase
- **Constants**: ALLCAPSWITHUNDERSCORES
- **Imports**: Standard library first, then third-party, then local imports
- **Type hints**: Required for all function parameters and returns
- **Docstrings**: Required for all classes and functions
- **Error handling**: Use try/except blocks with specific exception types

## File Headers
All Python files must include standardized headers with file path, dates, author (Herb Bowers - Project Himalaya), purpose, and AIDEV-PascalCase-1.7 compliance notation.