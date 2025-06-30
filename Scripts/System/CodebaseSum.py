#!/usr/bin/env python3
"""
File: CodebaseSum.py
Path: BowersWorld-com/Scripts/CodebaseSum.py
Created: 2025-06-25
Description: Generate a comprehensive codebase snapshot in a structured format
"""

import os
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path
import shutil
import fnmatch
import PyPDF2
from PyPDF2 import PdfReader

def get_gitignore_patterns(gitignore_path=".gitignore"):
    patterns = set()
    if os.path.exists(gitignore_path):
        with open(gitignore_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    # Normalize patterns: remove leading / and trailing / if not needed
                    if line.startswith('/'):
                        line = line[1:]
                    patterns.add(line)
    return patterns

def is_ignored(path, gitignore_patterns):
    """
    Checks if a given path should be ignored based on .gitignore patterns.
    This is a simplified implementation and may not cover all gitignore complexities.
    """
    path_str = str(path)
    # Check if the path directly matches any pattern
    for pattern in gitignore_patterns:
        # Handle directory patterns (ending with /)
        if pattern.endswith('/'):
            if path.is_dir() and fnmatch.fnmatch(path_str + '/', pattern):
                return True
            elif path.is_file() and fnmatch.fnmatch(path_str, pattern[:-1]): # Match files within ignored dirs
                return True
        elif fnmatch.fnmatch(path_str, pattern):
            return True
        # Handle patterns that are just directory names without leading/trailing slashes
        if path.is_dir() and fnmatch.fnmatch(path.name, pattern):
            return True
    return False

def main():
    # Create timestamp for the output filename
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = f"CodebaseSummary_{timestamp}.txt"
    
    # Check if the tree command is available
    if not shutil.which('tree'):
        print("Error: The 'tree' command is required but not found. Please install it first.")
        return 1
    
    print(f"Generating codebase summary to {output_file}...")
    
    # Create temp directory for building the summary
    with tempfile.TemporaryDirectory() as temp_dir:
        header_file = os.path.join(temp_dir, "header.txt")
        structure_file = os.path.join(temp_dir, "structure.txt")
        files_list = os.path.join(temp_dir, "files_list.txt")
        files_content = os.path.join(temp_dir, "files_content.txt")
        
        # Create the header
        header_content = """This file is a comprehensive codebase snapshot for the BowersWorld-com project, generated to facilitate analysis and development.

================================================================
File Summary
================================================================

Purpose:
--------
This document provides a consolidated view of the project's source code, scripts,
HTML, and text files, excluding any files specified in the .gitignore file. 
It serves as a reference for developers, making it easier to understand the 
codebase structure and functionality in a single document.

File Format:
------------
The content is organized as follows:
1. This summary section
2. Repository information
3. Directory structure
4. Multiple file entries, each consisting of:
5. List of Program files
6. List of Documents

"""
        
        with open(header_file, 'w') as f:
            f.write(header_content)
        
        # Generate directory structure using tree
        print("Generating directory structure...")
        # Get exclusion patterns from .gitignore for tree command
        gitignore_patterns_for_tree = get_gitignore_patterns()
        # Convert patterns to a format suitable for tree's -I option
        # Tree's -I uses fnmatch, so we can directly use the patterns.
        # We need to explicitly include some common system-level ignores for tree
        common_tree_excludes = [
            '.git', '__pycache__', '.venv', 'venv', 'ENV', '.idea', '.vscode',
            'Temp', 'Logs', 'build', 'dist', 'env', 'lib', 'lib64', 'parts', 
            'sdist', 'var', 'downloads', 'eggs', '.eggs', 'develop-eggs',
            'Covers', 'Thumbs', 'Html', 'Docs', 'node_modules'
        ]
        tree_ignore_patterns = list(set(common_tree_excludes).union(gitignore_patterns_for_tree))
        
        tree_cmd = ['tree', '-f', '-I', '|'.join(tree_ignore_patterns), '.']
        with open(structure_file, 'w') as f:
            subprocess.run(tree_cmd, stdout=f)
        
        # Create the files section header
        with open(files_content, 'w') as f:
            f.write("================================================================\n")
            f.write("Files\n")
            f.write("================================================================\n")
            f.write("\n")
        
        # Get exclusion patterns from .gitignore for os.walk
        gitignore_patterns_for_walk = get_gitignore_patterns()

        # Define common directories to exclude for os.walk based on gitignore and common patterns
        # These are explicit directories that should always be skipped by os.walk,
        # in addition to those matched by gitignore patterns.
        explicit_exclude_dirs_walk = {
            '.git', '__pycache__', '.venv', 'venv', 'ENV', '.idea', '.vscode',
            'Temp', 'Logs', 'build', 'dist', 'env', 'lib', 'lib64', 'parts',
            'sdist', 'var', 'downloads', 'eggs', '.eggs', 'develop-eggs',
            'Covers', 'Thumbs', 'Html', 'Docs', 'node_modules'
        }

        # Find relevant project files
        print("Finding relevant project files (.py, .sh, .md, .html, .txt, .pdf)...")
        file_extensions = {'.py', '.sh', '.md', '.html', '.txt', '.pdf'}
        relevant_files = []

        for root, dirs, files in os.walk('.'):
            # Filter directories in-place to avoid walking into excluded ones
            dirs_to_keep = []
            for d in list(dirs): # Iterate over a copy because we modify 'dirs'
                current_dir_path = Path(root) / d
                rel_dir_path = current_dir_path.relative_to('.')
                
                # Check explicit excludes first
                if d in explicit_exclude_dirs_walk:
                    dirs.remove(d)
                    continue
                
                # Check against gitignore patterns
                if is_ignored(rel_dir_path, gitignore_patterns_for_walk):
                    dirs.remove(d)
                else:
                    dirs_to_keep.append(d)
            dirs[:] = dirs_to_keep # Update dirs for the current walk iteration

            for file in files:
                file_path = Path(root) / file
                rel_file_path = file_path.relative_to('.')
                
                # Skip .gitignore file itself
                if file == '.gitignore':
                    continue

                # Check if file has relevant extension
                if file_path.suffix in file_extensions:
                    # Check if the file path should be ignored by gitignore patterns
                    if is_ignored(rel_file_path, gitignore_patterns_for_walk):
                        continue
                    
                    relevant_files.append(rel_file_path)
        
        # Sort files for consistent output
        relevant_files.sort(key=str) # Sort Path objects by their string representation
        
        # Write files list
        with open(files_list, 'w') as f:
            for file_path in relevant_files:
                f.write(f"{file_path}\n")
        
        # Process each file found
        print("Processing files...")
        with open(files_content, 'a') as fc:
            for p_obj in relevant_files: # Iterate over Path objects
                file_path_str = str(p_obj) # Get string representation for os.path.isfile
                if os.path.isfile(file_path_str):
                    current_file_path = Path(file_path_str) # Convert back to Path object for .suffix
                    fc.write("================\n")
                    fc.write(f"File: {current_file_path}\n")
                    fc.write("================\n")
                    try:
                        if current_file_path.suffix == '.pdf':
                            pdf_content = ""
                            with open(current_file_path, 'rb') as pdf_file:
                                pdf_reader = PdfReader(pdf_file)
                                for page_num in range(len(pdf_reader.pages)):
                                    page = pdf_reader.pages[page_num]
                                    text = page.extract_text()
                                    if text: # Only add if text is extracted
                                        pdf_content += text + "\n"
                            if pdf_content:
                                fc.write(pdf_content)
                            else:
                                fc.write("[PDF file: No extractable text content]\n")
                        else:
                            with open(current_file_path, 'r', encoding='utf-8') as f:
                                fc.write(f.read())
                    except Exception as e: # Catch all exceptions for reading files, including PDFs
                        fc.write(f"[Error reading content: {e} - content not displayed]\n")
                    fc.write("\n")
        
        # Combine all parts into the final file
        with open(output_file, 'w') as output:
            # Write header
            with open(header_file, 'r') as f:
                output.write(f.read())
            
            # Write directory structure
            output.write("================================================================\n")
            output.write("Directory Structure\n")
            output.write("================================================================\n")
            with open(structure_file, 'r') as f:
                output.write(f.read())
            output.write("\n")
            
            # Write files content
            with open(files_content, 'r') as f:
                output.write(f.read())
            
            # Write file list
            output.write("\n")
            output.write("================================================================\n")
            output.write("List of Included Files\n")
            output.write("================================================================\n")
            output.write("\n")
            output.write("Files included:\n")
            with open(files_list, 'r') as f:
                output.write(f.read())
            
            num_files = len(relevant_files)
            output.write(f"\nThere are {num_files} files included in the Files section of the CodebaseSummary document.\n")
    
    print(f"Codebase summary generated: {output_file}")
    print(f"It contains {len(relevant_files)} files.")
    
    return 0

if __name__ == "__main__":
    exit(main())
