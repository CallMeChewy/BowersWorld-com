#!/usr/bin/env python3
"""
Project backup script that respects .gitignore files
"""

import os
import shutil
import sys
from datetime import datetime
from pathlib import Path
import fnmatch


def parse_gitignore(gitignore_path):
    """Parse .gitignore file and return patterns to ignore"""
    patterns = []
    if os.path.exists(gitignore_path):
        with open(gitignore_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    patterns.append(line)
    return patterns


def should_ignore(file_path, ignore_patterns, base_path):
    """Check if a file/directory should be ignored based on gitignore patterns"""
    relative_path = os.path.relpath(file_path, base_path)
    
    for pattern in ignore_patterns:
        # Handle directory patterns ending with /
        if pattern.endswith('/'):
            if os.path.isdir(file_path):
                dir_pattern = pattern.rstrip('/')
                if fnmatch.fnmatch(relative_path, dir_pattern) or fnmatch.fnmatch(os.path.basename(file_path), dir_pattern):
                    return True
        else:
            # Handle file patterns
            if fnmatch.fnmatch(relative_path, pattern) or fnmatch.fnmatch(os.path.basename(file_path), pattern):
                return True
            # Check if any parent directory matches the pattern
            path_parts = relative_path.split(os.sep)
            for part in path_parts[:-1]:  # Exclude the file itself
                if fnmatch.fnmatch(part, pattern):
                    return True
    
    return False


def copy_with_gitignore(src, dst, ignore_patterns):
    """Copy directory tree while respecting gitignore patterns"""
    if not os.path.exists(dst):
        os.makedirs(dst)
    
    for item in os.listdir(src):
        src_path = os.path.join(src, item)
        dst_path = os.path.join(dst, item)
        
        if should_ignore(src_path, ignore_patterns, src):
            print(f"Ignoring: {src_path}")
            continue
        
        if os.path.isdir(src_path):
            copy_with_gitignore(src_path, dst_path, ignore_patterns)
        else:
            shutil.copy2(src_path, dst_path)


def backup_project(project_name=None):
    """Backup the current project, respecting .gitignore if present"""
    # Get project name
    if not project_name:
        project_name = os.path.basename(os.getcwd())
    
    # Setup backup directory
    backup_dir = os.path.join(os.path.expanduser("~"), "Desktop", "Projects_Backup")
    date_stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_name = f"{project_name}_{date_stamp}"
    backup_path = os.path.join(backup_dir, backup_name)
    
    # Create backup directory
    os.makedirs(backup_dir, exist_ok=True)
    
    # Get source directory (current directory)
    src_dir = os.getcwd()
    
    # Parse .gitignore if it exists
    gitignore_path = os.path.join(src_dir, '.gitignore')
    ignore_patterns = parse_gitignore(gitignore_path)
    
    # Always ignore .git directory
    ignore_patterns.append('.git/')
    
    print(f"Backing up project: {project_name}")
    if ignore_patterns:
        print(f"Using .gitignore patterns: {len(ignore_patterns)} patterns found")
    
    # Copy project with gitignore filtering
    try:
        copy_with_gitignore(src_dir, backup_path, ignore_patterns)
        print(f"Project backed up to: {backup_path}")
        return backup_path
    except Exception as e:
        print(f"Error during backup: {e}")
        return None


def main():
    """Main entry point"""
    project_name = None
    if len(sys.argv) > 1:
        project_name = sys.argv[1]
    
    backup_project(project_name)


if __name__ == "__main__":
    main()