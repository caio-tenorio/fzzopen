# fopen - Fuzzy File Opener

A smart file selector that works in any shell (sh, bash, fish, zsh, dash).

## Features

- 🔍 **Fuzzy search** with `fzf` to quickly navigate through files
- 📁 **Smart filters** that automatically exclude folders like `node_modules`, `.git`, etc.
- 👀 **Real-time preview** of files with syntax highlighting
- 🎯 **Automatic MIME type detection** to open files with the correct application
- 🔄 **Hidden files toggle** with Alt+h/Alt+H
- 🖥️ **Cross-shell** - works in any shell

## Dependencies

### Required
- `fzf` - for the selection interface
- `file` - for MIME type detection

### Optional (improve experience)
- `fd` - faster search than `find`
- `bat` - syntax highlighting in preview
- Editors: `nvim`, `code`, `gedit`, `kate`
- Viewers: `loupe` (images), `okular` (PDF)
- `nautilus` - file manager

### Installing dependencies on Ubuntu/Debian:
```bash
# Required
sudo apt install fzf file

# Optional recommended
sudo apt install fd-find bat neovim

# Editors and viewers
sudo apt install code gedit kate loupe okular nautilus
```

## Build

### Option 1: Using Make (recommended)
```bash
# Install Python dependencies
make deps

# Build
make build

# Install on system
make install

# Test
make test
```

### Option 2: Build script
```bash
# Make executable
chmod +x build_fopen.sh

# Build
./build_fopen.sh
```

### Option 3: Manual
```bash
# Install PyInstaller
pip install pyinstaller

# Build
pyinstaller --onefile --name fopen --console --strip --optimize 2 fopen.py

# Binary will be in dist/fopen
```

## Installation

After building, you can install the binary:

```bash
# System-wide (requires sudo)
sudo cp dist/fopen /usr/local/bin/

# Current user
cp dist/fopen ~/.local/bin/
```

Make sure the directory is in your PATH.

## Usage

```bash
# Normal search (without hidden files)
fopen

# Search including hidden files
fopen -h
# or
fopen --hidden

# Help
fopen --help
```

### fzf controls:
- **Enter**: Select file/folder
- **Alt+h**: Show hidden files
- **Alt+H**: Hide hidden files
- **Ctrl+C**: Cancel

## Behavior

### For directories:
- **cd**: Navigate to directory (prints cd command)
- **code**: Open in VS Code
- **nautilus**: Open in file manager

### For text files:
- **nvim**: Open in terminal
- **code**: Open in VS Code
- **gedit**: Simple editor
- **kate**: KDE editor

### For other types:
- **Images**: Open with `loupe`
- **PDFs**: Open with `okular`
- **Others**: Use `xdg-open`

## Differences from original Fish version

1. **Compatibility**: Works in any shell
2. **Standalone binary**: Doesn't need Fish or Python installed on the final system
3. **Simple installation**: Single executable file
4. **Same functionality**: Maintains all features from the original version

## Project structure

```
.
├── fopen.py           # Python source code
├── build_fopen.sh     # Build script
├── Makefile          # Makefile for automation
└── README.md         # This documentation
```

## Troubleshooting

### "fzf not found"
```bash
sudo apt install fzf  # Ubuntu/Debian
brew install fzf      # macOS
```

### "PyInstaller not found"
```bash
pip install pyinstaller
```

### Binary doesn't execute
- Check if it has execution permission: `chmod +x dist/fopen`
- Check if it's in PATH: `echo $PATH`

### Preview doesn't work
- Install `bat`: `sudo apt install bat`
- Install `file`: `sudo apt install file`