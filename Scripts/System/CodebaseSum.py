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
        tree_ignore_patterns = [
            '.git', '__pycache__', '.venv', 'venv', 'ENV', '.idea', '.vscode',
            'Temp', 'Logs', 'build', 'dist', 'env', 'lib', 'lib64', 'parts', 
            'sdist', 'var', 'downloads', 'eggs', '.eggs', 'develop-eggs',
            'Covers', 'Thumbs', 'Html', 'Docs'
        ]
        tree_cmd = ['tree', '-f', '-I', '|'.join(tree_ignore_patterns), '.']
        with open(structure_file, 'w') as f:
            subprocess.run(tree_cmd, stdout=f)
        
        # Create the files section header
        with open(files_content, 'w') as f:
            f.write("================================================================\n")
            f.write("Files\n")
            f.write("================================================================\n")
            f.write("\n")
        
        # Define directories to exclude (based on .gitignore and common patterns)
        exclude_dirs = {
            '.git', '__pycache__', '.venv', 'venv', 'ENV', '.idea', '.vscode',
            'Temp', 'Logs', 'build', 'dist', 'env', 'lib', 'lib64', 'parts',
            'sdist', 'var', 'downloads', 'eggs', '.eggs', 'develop-eggs',
            'Covers', 'Thumbs', 'Html', 'Docs'
        }
        
        # Find relevant project files
        print("Finding relevant project files (.py, .sh, .md, .html, .txt)...")
        file_extensions = {'.py', '.sh', '.md', '.html', '.txt'}
        relevant_files = []
        
        for root, dirs, files in os.walk('.'):
            # Remove excluded directories from dirs list to prevent walking into them
            dirs[:] = [d for d in dirs if d not in exclude_dirs and not d.startswith('..')]
            
            for file in files:
                file_path = Path(root) / file
                # Skip .gitignore files
                if file == '.gitignore':
                    continue
                    
                # Check if file has relevant extension
                if file_path.suffix in file_extensions:
                    # Check if any part of the path is in excluded directories
                    path_parts = file_path.parts
                    if not any(part in exclude_dirs for part in path_parts):
                        # Convert to relative path and remove leading ./
                        rel_path = str(file_path.relative_to('.'))
                        relevant_files.append(rel_path)
        
        # Sort files for consistent output
        relevant_files.sort()
        
        # Write files list
        with open(files_list, 'w') as f:
            for file_path in relevant_files:
                f.write(f"{file_path}\n")
        
        # Process each file found
        print("Processing files...")
        with open(files_content, 'a') as fc:
            for file_path in relevant_files:
                if os.path.isfile(file_path):
                    fc.write("================\n")
                    fc.write(f"File: {file_path}\n")
                    fc.write("================\n")
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            fc.write(f.read())
                    except UnicodeDecodeError:
                        fc.write(f"[Binary file - content not displayed]\n")
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