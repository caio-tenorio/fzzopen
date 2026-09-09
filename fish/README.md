# fopen (fish)

A native fish function for fuzzy file and directory selection, with application
selection based on MIME type. This is the active implementation. It runs in the
current shell process, so `cd` changes the shell's working directory.

## Installation

From this directory:

```sh
mkdir -p ~/.config/fish/functions
cp fopen.fish ~/.config/fish/functions/fopen.fish
```

## Dependencies

- `fzf` (required) — selection interface
- `file` (required) — MIME type detection
- `fd` (optional) — faster searching than `find`
- `bat` (optional) — text previews with syntax highlighting
- `gio` + `gtk-launch` (optional) — discover and launch applications associated
  with the MIME type by the system
- `xdg-open` (optional) — enables the system default application option

The function supplements system MIME associations with a small built-in catalog
of common applications, such as Visual Studio Code, Neovim, and VLC. Catalog
entries appear only when their executable is found in `PATH` and matches the
file type. Applications already represented by a desktop entry with the same
executable name are omitted from the supplement. The catalog also works when
`gio` or `gtk-launch` is unavailable. No manual configuration is needed.

## Usage

```fish
fopen          # exclude hidden files
fopen -h       # include hidden files
```

In fzf: `Alt+h` shows hidden files, `Alt+H` hides them, `Enter` selects an item,
and `Ctrl+C` cancels the search.

Applications with `Terminal=true` in their `.desktop` entry (such as nvim and
micro) run in the current terminal. Exiting the editor returns you to fish.
Graphical applications exit the shell after launching, including when opening
directories. The “Open in terminal” option only changes the working directory.
Whether the window closes when the shell exits depends on your terminal
emulator settings.

To test the local version over an already loaded function, run from the
repository root:

```fish
source fish/fopen.fish
fopen
```

Run automated launch tests with simulated applications from the repository root:

```sh
python3 fish/test_open.py
```
