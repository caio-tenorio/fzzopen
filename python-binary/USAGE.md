# Usage Example - fzzo

This file demonstrates how to use the compiled `fzzo`.

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
./dist/fzzo

# Include hidden files
./dist/fzzo -h
```

### Shell compatibility

#### In Fish Shell (original)
```fish
# Original fish function
fzzo

# Compiled binary
./dist/fzzo
```

#### In Bash
```bash
# Use the binary
./dist/fzzo

# Useful alias
alias fzzo='/home/caio/fzzopen/dist/fzzo'
```

#### In Zsh
```zsh
# Use the binary
./dist/fzzo

# Add to .zshrc
echo 'alias fzzo="/home/caio/dist/fzzo"' >> ~/.zshrc
```

#### In Shell Script (sh)
```sh
#!/bin/sh
# Use in scripts
/home/caio/dist/fzzo
```

## Workflow

1. **Run fzzo**: `./dist/fzzo`
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