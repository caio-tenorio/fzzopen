# Usage Example - fopen

This file demonstrates how to use the compiled `fopen`.

## Quick Installation

```bash
# 1. Build
make build

# 2. Install (optional)
make install

# 3. Test
make test
```

## Usage Examples

### Basic usage
```bash
# Navigate and open files in current directory
./dist/fopen

# Include hidden files
./dist/fopen -h
```

### Shell compatibility

#### In Fish Shell (original)
```fish
# Original fish function
fopen

# Compiled binary
./dist/fopen
```

#### In Bash
```bash
# Use the binary
./dist/fopen

# Useful alias
alias fopen='/home/caio/fopen/dist/fopen'
```

#### In Zsh
```zsh
# Use the binary
./dist/fopen

# Add to .zshrc
echo 'alias fopen="/home/caio/dist/fopen"' >> ~/.zshrc
```

#### In Shell Script (sh)
```sh
#!/bin/sh
# Use in scripts
/home/caio/dist/fopen
```

## Workflow

1. **Run fopen**: `./dist/fopen`
2. **Navigate**: Use arrow keys or type to filter
3. **Toggle hidden files**: Alt+h (show) / Alt+H (hide)
4. **Select**: Press Enter on desired file
5. **Choose application**: If there are multiple options, use fzf again

## Supported file types

### Directories
- **cd**: Change to directory
- **code**: Open in VS Code
- **nautilus**: Open in file manager

### Text/code files
- **nvim**: Terminal editor
- **code**: VS Code
- **gedit**: Simple graphical editor
- **kate**: KDE editor

### Other formats
- **Images**: loupe
- **PDFs**: okular
- **Others**: xdg-open (system default application)

## Advantages over Fish version

1. **Portability**: Works in any shell
2. **Standalone**: Doesn't need Python on the final system
3. **Performance**: Optimized binary
4. **Distribution**: Single executable file
5. **Compatibility**: Same functionality in all environments