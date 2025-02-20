import os
import re
import sys

def replace_with_opacity(content):
    def repl(match):
        opacity_val = float(match.group(1))
        alpha = int(round(255 * opacity_val))
        return f'.withAlpha({alpha})'
    
    return re.sub(r'\.withOpacity\s*\(\s*([0-9.]+)\s*\)', repl, content)

def process_file(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        new_content = replace_with_opacity(content)
        if content != new_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated: {file_path}")
    except Exception as e:
        print(f"Error processing {file_path}: {e}")

def process_directory(root_dir):
    for dirpath, _, files in os.walk(root_dir):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(dirpath, file)
                process_file(file_path)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python replace_opacity_recursive.py <root_directory>")
    process_directory(sys.argv[1])