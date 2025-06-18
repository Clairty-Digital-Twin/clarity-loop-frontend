#!/usr/bin/env python3

import os
import re

def fix_mark_comments(directory):
    """Fix MARK comments that are missing the hyphen after the colon."""
    fixed_files = []
    
    for root, dirs, files in os.walk(directory):
        # Skip hidden directories and common build directories
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['DerivedData', 'build']]
        
        for file in files:
            if file.endswith('.swift'):
                filepath = os.path.join(root, file)
                
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Replace "// MARK:" with "// MARK: -" when not followed by a hyphen
                # This regex looks for "// MARK:" followed by a space and a non-hyphen character
                new_content = re.sub(r'// MARK: (?!-)(\S)', r'// MARK: - \1', content)
                
                # Also handle cases where there's no space after the colon
                new_content = re.sub(r'// MARK:(?![ -])(\S)', r'// MARK: - \1', new_content)
                
                if new_content != content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    fixed_files.append(filepath)
                    print(f"Fixed MARK comments in: {filepath}")
    
    return fixed_files

if __name__ == "__main__":
    project_dir = "/Users/ray/Desktop/CLARITY-DIGITAL-TWIN/clarity-loop-frontend"
    fixed = fix_mark_comments(project_dir)
    print(f"\nTotal files fixed: {len(fixed)}")