#!/usr/bin/env python3
"""
fopen - Fuzzy file opener (configurable version)
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
import json

class FopenConfig:
    """Fopen configuration manager"""
    
    def __init__(self):
        self.config_path = self._get_config_path()
        self.config = self._load_config()
        
    def _get_config_path(self):
        """Get configuration file path"""
        # Try XDG_CONFIG_HOME first
        config_home = os.environ.get('XDG_CONFIG_HOME')
        if config_home:
            return Path(config_home) / 'fopen' / 'config.json'
        
        # Fallback to ~/.config
        home = Path.home()
        return home / '.config' / 'fopen' / 'config.json'
    
    def _get_default_config(self):
        """Default configuration"""
        return {
            "applications": {
                "text_editors": [
                    {"command": "nvim", "label": "NeoVim", "terminal": True, "priority": 1},
                    {"command": "vim", "label": "Vim", "terminal": True, "priority": 2},
                    {"command": "code", "label": "Visual Studio Code", "terminal": False, "priority": 3},
                    {"command": "gedit", "label": "Text Editor (GTK)", "terminal": False, "priority": 4},
                    {"command": "kate", "label": "Kate Editor", "terminal": False, "priority": 5}
                ],
                "file_managers": [
                    {"command": "nautilus", "label": "Files (GNOME)", "terminal": False, "priority": 1},
                    {"command": "dolphin", "label": "Dolphin (KDE)", "terminal": False, "priority": 2},
                    {"command": "thunar", "label": "Thunar (XFCE)", "terminal": False, "priority": 3}
                ],
                "image_viewers": [
                    {"command": "loupe", "label": "Loupe", "terminal": False, "priority": 1},
                    {"command": "eog", "label": "Eye of GNOME", "terminal": False, "priority": 2},
                    {"command": "feh", "label": "Feh", "terminal": False, "priority": 3}
                ],
                "pdf_viewers": [
                    {"command": "okular", "label": "Okular", "terminal": False, "priority": 1},
                    {"command": "evince", "label": "Evince", "terminal": False, "priority": 2},
                    {"command": "zathura", "label": "Zathura", "terminal": True, "priority": 3}
                ]
            },
            "file_types": {
                "text": ["text/", "application/json", "application/xml", "application/javascript", "application/x-yaml", "application/x-shellscript", "inode/x-empty"],
                "images": ["image/"],
                "pdf": ["application/pdf"]
            },
            "search": {
                "excluded_dirs": [".git", "node_modules", ".vscode", ".idea", "dist", "build", "target", ".cache"],
                "use_fd_if_available": True,
                "follow_symlinks": True
            },
            "interface": {
                "use_fzf_for_app_selection": True,
                "fzf_height": "90%",
                "preview_enabled": True
            }
        }
    
    def _load_config(self):
        """Load configuration from file"""
        config = self._get_default_config()
        
        # Apply environment variable overrides
        self._apply_env_overrides(config)
        
        # Load from file if it exists
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    file_config = json.load(f)
                    self._merge_config(config, file_config)
            except Exception as e:
                print(f"Warning: Could not load config file: {e}", file=sys.stderr)
        
        return config
    
    def _apply_env_overrides(self, config):
        """Apply environment variable overrides"""
        env_mappings = {
            'FOPEN_TEXT_EDITOR': ('applications', 'text_editors'),
            'FOPEN_FILE_MANAGER': ('applications', 'file_managers'),
            'FOPEN_IMAGE_VIEWER': ('applications', 'image_viewers'),
            'FOPEN_PDF_VIEWER': ('applications', 'pdf_viewers'),
            'FOPEN_FZF_HEIGHT': ('interface', 'fzf_height'),
        }
        
        for env_var, (section, key) in env_mappings.items():
            value = os.environ.get(env_var)
            if value and section == 'applications':
                # For applications, add it to the top of the list
                app_entry = {"command": value, "label": f"Custom {value}", "terminal": False, "priority": 0}
                config[section][key].insert(0, app_entry)
            elif value:
                config[section][key] = value
        
        # Excluded directories
        exclude_dirs = os.environ.get('FOPEN_EXCLUDE_DIRS')
        if exclude_dirs:
            config['search']['excluded_dirs'] = exclude_dirs.split(':')
    
    def _merge_config(self, base, override):
        """Merge configurations recursively"""
        for key, value in override.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                self._merge_config(base[key], value)
            else:
                base[key] = value
    
    def get_available_apps(self, category):
        """Get available applications for a category"""
        apps = self.config['applications'].get(category, [])
        available = []
        
        for app in apps:
            if check_command(app['command']):
                available.append(app)
        
        # Sort by priority
        available.sort(key=lambda x: x.get('priority', 999))
        return available
    
    def get_excluded_dirs(self):
        """Get list of excluded directories"""
        return self.config['search']['excluded_dirs']
    
    def should_use_fd(self):
        """Check if should use fd"""
        return self.config['search']['use_fd_if_available']
    
    def get_fzf_height(self):
        """Get fzf height"""
        return self.config['interface']['fzf_height']
    
    def create_default_config_file(self):
        """Create default configuration file"""
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.config_path, 'w') as f:
            json.dump(self._get_default_config(), f, indent=2)
        print(f"Created default config at: {self.config_path}")

# Global configuration instance
config_manager = FopenConfig()

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
    excluded_dirs = config_manager.get_excluded_dirs()
    
    if config_manager.should_use_fd() and check_command('fd'):
        cmd = ['fd', '-t', 'f', '-t', 'd', '--strip-cwd-prefix', '--color=never']
        
        if show_hidden:
            cmd.extend(['--hidden', '--follow'])
        
        for exclude_dir in excluded_dirs:
            cmd.extend(['--exclude', exclude_dir])
        
        cmd.append('-0')
        return cmd
    else:
        # Fallback to find
        cmd = ['find', '.']
        
        # Build exclusion patterns
        if excluded_dirs:
            exclude_patterns = []
            for exclude_dir in excluded_dirs:
                exclude_patterns.extend(['-path', f'*/{exclude_dir}'])
                if exclude_patterns:
                    exclude_patterns.append('-o')
            
            # Remove trailing '-o'
            if exclude_patterns and exclude_patterns[-1] == '-o':
                exclude_patterns.pop()
            
            if exclude_patterns:
                cmd.extend(['('] + exclude_patterns + [')', '-prune', '-o'])
        
        if not show_hidden:
            cmd.extend(['-path', '*/.*', '-prune', '-o'])
        
        cmd.extend(['-type', 'f', '-print0', '-o', '-type', 'd', '-print0'])
        return cmd

def choose_app_option(options):
    """Interactive option selection"""
    if not options:
        print("No options provided", file=sys.stderr)
        return None
    
    # Convert to a compatible format
    formatted_options = [(app['command'], app['label']) for app in options]
    
    # Try fzf first if configured
    if config_manager.config['interface']['use_fzf_for_app_selection'] and check_command('fzf'):
        try:
            options_str = '\n'.join([f"{opt[0]} :: {opt[1]}" for opt in formatted_options])
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
    for i, (cmd, label) in enumerate(formatted_options, 1):
        print(f"  {i}) {label}")
    
    try:
        choice = input(f"Number [1-{len(formatted_options)}]: ").strip()
        if choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(formatted_options):
                return formatted_options[idx][0]
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
    # Special option for cd
    cd_option = {"command": "cd", "label": "Open in terminal", "terminal": True, "priority": 0}
    
    # Obtain available file managers
    file_managers = config_manager.get_available_apps('file_managers')
    text_editors = config_manager.get_available_apps('text_editors')
    
    # Combine options
    all_options = [cd_option] + file_managers + text_editors
    
    app_choice = choose_app_option(all_options)
    if not app_choice:
        return
    
    if app_choice == "cd":
        print(f"cd '{dirpath}'")
    elif app_choice == "code":
        run_detached(['code', dirpath])
    else:
        # Find the application configuration
        for app in all_options:
            if app['command'] == app_choice:
                if app.get('terminal', False):
                    subprocess.run([app_choice, dirpath])
                else:
                    run_detached([app_choice, dirpath])
                break

def handle_file(filepath):
    """Handle file selection based on MIME type"""
    mime_type = get_file_mime_type(filepath)
    
    # Determine category based on the MIME type
    file_types = config_manager.config['file_types']
    
    if any(mime_type.startswith(prefix) or mime_type in file_types['text'] 
           for prefix in file_types['text'] if prefix.endswith('/')):
        available_apps = config_manager.get_available_apps('text_editors')
        
    elif any(mime_type.startswith(prefix) for prefix in file_types['images']):
        available_apps = config_manager.get_available_apps('image_viewers')
        
    elif mime_type in file_types['pdf']:
        available_apps = config_manager.get_available_apps('pdf_viewers')
        
    else:
        # Fallback to xdg-open
        run_detached(['xdg-open', '--', filepath])
        return
    
    if not available_apps:
        run_detached(['xdg-open', '--', filepath])
        return
    
    app_choice = choose_app_option(available_apps)
    if not app_choice:
        print("Cancelled.")
        return
    
    # Find the application configuration
    for app in available_apps:
        if app['command'] == app_choice:
            if app.get('terminal', False):
                subprocess.run([app_choice, '--', filepath])
            else:
                if app_choice == "code":
                    run_detached([app_choice, '--reuse-window', '--', filepath])
                else:
                    run_detached([app_choice, '--', filepath])
            break

def main():
    parser = argparse.ArgumentParser(description='Fuzzy file opener', add_help=False)
    parser.add_argument('--hidden', action='store_true',
                       help='Show hidden files')
    parser.add_argument('--config', action='store_true',
                       help='Create default configuration file')
    parser.add_argument('--help', action='help',
                       help='Show this help message and exit')
    
    args = parser.parse_args()
    
    if args.config:
        config_manager.create_default_config_file()
        return
    
    if not check_command('fzf'):
        print("Error: fzf is required but not found in PATH", file=sys.stderr)
        sys.exit(1)
    
    # Build find command
    find_cmd = build_find_command(args.hidden)
    hidden_find_cmd = build_find_command(True)
    base_find_cmd = build_find_command(False)
    
    # Set up headers and commands
    header = 'Hidden: ON   (Alt-h on / Alt-H off)' if args.hidden else 'Hidden: OFF  (Alt-h on / Alt-H off)'
    
    # Create fzf command
    fzf_height = config_manager.get_fzf_height()
    fzf_cmd = [
        'fzf',
        '--read0',
        f'--height={fzf_height}',
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
