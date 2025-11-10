#!/usr/bin/env python3
"""
fopen - Fuzzy file opener
A cross-shell file picker with smart application selection
"""

import os
import sys
import subprocess
import argparse
import mimetypes
from pathlib import Path
import shutil
import signal

def check_command(cmd):
    """Check if a command exists in PATH"""
    return shutil.which(cmd) is not None

def get_file_mime_type(filepath):
    """Get MIME type of a file"""
    try:
        result = subprocess.run(['file', '--brief', '--mime-type', '--', filepath], 
                              capture_output=True, text=True)
        return result.stdout.strip()
    except:
        # Fallback to Python's mimetypes
        mime_type, _ = mimetypes.guess_type(filepath)
        return mime_type or 'application/octet-stream'

def build_find_command(show_hidden=False):
    """Build the find command based on available tools"""
    if check_command('fd'):
        if show_hidden:
            return [
                'fd', '-t', 'f', '-t', 'd', '--strip-cwd-prefix', '--color=never',
                '--hidden', '--follow', '--exclude', '.git', '--exclude', 'node_modules',
                '--exclude', '.vscode', '--exclude', '.idea', '--exclude', 'dist',
                '--exclude', 'build', '--exclude', 'target', '--exclude', '.cache', '-0'
            ]
        else:
            return [
                'fd', '-t', 'f', '-t', 'd', '--strip-cwd-prefix', '--color=never',
                '--exclude', 'node_modules', '--exclude', '.vscode', '--exclude', '.idea',
                '--exclude', 'dist', '--exclude', 'build', '--exclude', 'target',
                '--exclude', '.cache', '-0'
            ]
    else:
        # Fallback to find
        if show_hidden:
            return [
                'find', '.', '(', '-path', '*/.git', '-o', '-path', '*/node_modules',
                '-o', '-path', '*/.vscode', '-o', '-path', '*/.idea', '-o', '-path', '*/dist',
                '-o', '-path', '*/build', '-o', '-path', '*/target', '-o', '-path', '*/.cache',
                ')', '-prune', '-o', '-type', 'f', '-print0', '-o', '-type', 'd', '-print0'
            ]
        else:
            return [
                'find', '.', '(', '-path', '*/.git', '-o', '-path', '*/node_modules',
                '-o', '-path', '*/.vscode', '-o', '-path', '*/.idea', '-o', '-path', '*/dist',
                '-o', '-path', '*/build', '-o', '-path', '*/target', '-o', '-path', '*/.cache',
                '-o', '-path', '*/.*', ')', '-prune', '-o', '-type', 'f', '-print0',
                '-o', '-type', 'd', '-print0'
            ]

def create_preview_command(filepath):
    """Create preview command for fzf"""
    return f"""test -d "{filepath}" && {{ ls -A "{filepath}" | head -n 50; }} || {{ file --mime-type -b "{filepath}" | grep -qiF -e 'text' -e 'json' -e 'javascript' && bat --style=numbers --color=always --paging=never "{filepath}" || file --brief "{filepath}"; }}"""

def choose_app_option(options):
    """Interactive option selection"""
    if not options:
        print("No options provided", file=sys.stderr)
        return None
    
    # Try fzf first
    if check_command('fzf'):
        try:
            options_str = '\n'.join([f"{opt[0]} :: {opt[1]}" for opt in options])
            result = subprocess.run(['fzf', '--prompt=Open with: ', '--height=40%', '--reverse'],
                                  input=options_str, text=True, capture_output=True)
            if result.returncode == 0:
                selected = result.stdout.strip()
                if selected:
                    return selected.split(' :: ')[0]
            return None
        except:
            pass
    
    # Fallback to manual selection
    print("Choose the best option:")
    for i, (cmd, label) in enumerate(options, 1):
        print(f"  {i}) {label}")
    
    try:
        choice = input(f"Number [1-{len(options)}]: ").strip()
        if choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(options):
                return options[idx][0]
    except (KeyboardInterrupt, EOFError):
        return None
    
    return None

def run_detached(cmd):
    """Run command detached from terminal"""
    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                        preexec_fn=os.setpgrp)
    except:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def handle_directory(dirpath):
    """Handle directory selection"""
    options = [
        ("cd", "Open in terminal"),
        ("nautilus", "GTK File Manager"),
        ("code", "Visual Studio Code"),
        ("nvim", "NeoVim")
    ]
    
    # Filter available options
    available_options = []
    for cmd, label in options:
        if cmd == "cd" or check_command(cmd):
            available_options.append((cmd, label))
    
    editor = choose_app_option(available_options)
    if not editor:
        return
    
    if editor == "cd":
        # For cd, we need to change to the directory in the current shell
        # This is tricky from a subprocess, so we'll print the command
        print(f"cd '{dirpath}'")
    elif editor == "code":
        run_detached(['code', dirpath])
    elif editor == "nautilus":
        run_detached(['nautilus', dirpath])
    elif editor == "nvim":
        subprocess.run(['nvim', dirpath])

def handle_file(filepath):
    """Handle file selection based on MIME type"""
    mime_type = get_file_mime_type(filepath)
    
    # Text files
    if (mime_type.startswith('text/') or 
        mime_type in ['application/json', 'application/xml', 'application/javascript',
                     'application/x-yaml', 'application/x-shellscript', 'inode/x-empty']):
        
        options = [
            ("nvim", "Open in terminal"),
            ("code", "Visual Studio Code"),
            ("gedit", "Simple text editor (GTK)"),
            ("kate", "KDE Editor")
        ]
        
        # Filter available options
        available_options = []
        for cmd, label in options:
            if cmd in ["nvim", "vim"] or check_command(cmd):
                available_options.append((cmd, label))
        
        editor = choose_app_option(available_options)
        if not editor:
            print("Cancelled.")
            return
        
        if editor == "nvim":
            subprocess.run(['nvim', '--', filepath])
        elif editor == "code":
            run_detached(['code', '--reuse-window', '--', filepath])
        elif editor == "gedit":
            run_detached(['gedit', '--', filepath])
        elif editor == "kate":
            run_detached(['kate', '--', filepath])
        else:
            # Fallback to vim
            subprocess.run(['vim', '--', filepath])
    
    # Image files
    elif mime_type.startswith('image/'):
        run_detached(['loupe', '--', filepath])
    
    # PDF files
    elif mime_type == 'application/pdf':
        run_detached(['okular', '--', filepath])
    
    # Fallback to xdg-open
    else:
        run_detached(['xdg-open', '--', filepath])

def main():
    parser = argparse.ArgumentParser(description='Fuzzy file opener', add_help=False)
    parser.add_argument('--hidden', action='store_true',
                       help='Show hidden files')
    parser.add_argument('--help', action='help',
                       help='Show this help message and exit')
    
    # Check for -h or --hidden manually
    show_hidden = False
    if len(sys.argv) > 1:
        if sys.argv[1] in ['-h', '--hidden']:
            show_hidden = True
        elif sys.argv[1] == '--help':
            parser.print_help()
            return
    
    if not check_command('fzf'):
        print("Error: fzf is required but not found in PATH", file=sys.stderr)
        sys.exit(1)
    
    # Build find command
    find_cmd = build_find_command(show_hidden)
    hidden_find_cmd = build_find_command(True)
    base_find_cmd = build_find_command(False)
    
    # Set up headers and commands
    header = 'Hidden: ON   (Alt-h on / Alt-H off)' if show_hidden else 'Hidden: OFF  (Alt-h on / Alt-H off)'
    
    # Create fzf command
    fzf_cmd = [
        'fzf',
        '--read0',
        '--height=90%',
        '--border',
        f'--header={header}',
        '--preview=' + 'test -d {} && { ls -A {} | head -n 50; } || { file --mime-type -b {} | grep -qiF -e "text" -e "json" -e "javascript" && bat --style=numbers --color=always --paging=never {} || file --brief {}; }',
        '--bind=alt-h:reload(' + ' '.join(hidden_find_cmd) + ')+change-header(Hidden: ON   (Alt-h on / Alt-H off))',
        '--bind=alt-H:reload(' + ' '.join(base_find_cmd) + ')+change-header(Hidden: OFF  (Alt-h on / Alt-H off))'
    ]
    
    try:
        # Run find command and pipe to fzf
        find_process = subprocess.Popen(find_cmd, stdout=subprocess.PIPE)
        fzf_process = subprocess.Popen(fzf_cmd, stdin=find_process.stdout, 
                                     stdout=subprocess.PIPE, text=True)
        find_process.stdout.close()
        
        selected_file, _ = fzf_process.communicate()
        selected_file = selected_file.strip()
        
        if not selected_file:
            return
        
        # Handle selection
        if os.path.isdir(selected_file):
            handle_directory(selected_file)
        else:
            handle_file(selected_file)
            
    except KeyboardInterrupt:
        print("\nCancelled.")
        sys.exit(130)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()