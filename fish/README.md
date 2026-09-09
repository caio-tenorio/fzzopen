# fzzopen (fish)

A native fish function for fuzzy file and directory selection, with application
selection based on MIME type. This is the active implementation. It runs in the
current shell process, so `cd` changes the shell's working directory.

## Installation

From this directory:

```sh
mkdir -p ~/.config/fish/functions
cp fzzo.fish ~/.config/fish/functions/fzzo.fish
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

## Configuration

By default, no configuration is needed — the picker uses system MIME
associations plus the built-in catalog described above, exactly as before.

To customize which applications appear, create
`$XDG_CONFIG_HOME/fzzopen/config.toml` (defaults to
`~/.config/fzzopen/config.toml`). See [fish/config.example.toml](config.example.toml)
for a full example. The file is a restricted subset of TOML — only
`[[include]]`/`[[exclude]]` array-of-tables with scalar or string-array
values — parsed by `fzzo.fish` itself, so no extra dependency is required.

Each `[[exclude]]` or `[[include]]` block describes **one application**.
To exclude or include several applications, repeat the block — there is no
`apps = [...]` list; `mime` is the only field that takes a list, and it still
describes MIME types for that single application:

```toml
# Hide these two applications everywhere they'd otherwise show up.
[[exclude]]
mime = "inode/directory"   # exact type, "type/*" wildcard, or "*" for all
app = "vim"                # matches the resolved executable name

[[exclude]]
mime = "*"
app = "libreoffice-writer"

# Add these two applications on top of what's already offered.
[[include]]
mime = ["text/*", "application/json", "inode/directory"]
label = "Visual Studio Code"
command = "code"
args = ["--reuse-window"]  # optional, defaults to none
terminal = false           # optional, defaults to false

[[include]]
mime = "image/*"
label = "GIMP"
command = "gimp"
```

Folders are represented by the MIME type `inode/directory`, so the same
rules apply to the directory picker and the file picker.

- **Exclusions** match by the resolved executable name — the same identity
  used to de-duplicate a desktop entry against the built-in catalog — so
  excluding `vim` hides it regardless of whether it was offered via a
  `.desktop` file or the catalog.
- **Inclusions** whose `command` matches an app already offered by the
  system or catalog replace that entry (its label/args/terminal mode), so
  you don't end up with duplicates; otherwise they're added as new options.
  A configured `command` is only offered if it's found in `PATH`.
- **Exclusions are applied last**, after inclusions, so they take priority.
- The "System default application" option is always shown, even if the
  application it would resolve to at launch time is separately excluded.
- Invalid entries (unknown keys, missing required fields, malformed lines)
  print a warning to stderr and are skipped — they never abort the picker.

## Usage

```fish
fzzo          # exclude hidden files
fzzo -h       # include hidden files
fzzo -k       # keep this shell open after launching a GUI app
```

Flags can be combined in any order, e.g. `fzzo -h -k`.

In fzf: `Alt+h` shows hidden files, `Alt+H` hides them, `Enter` selects an item,
and `Ctrl+C` cancels the search.

Applications with `Terminal=true` in their `.desktop` entry (such as nvim and
micro) run in the current terminal. Exiting the editor returns you to fish.
Graphical applications exit the shell after launching, including when opening
directories. The “Open in terminal” option only changes the working directory.
Whether the window closes when the shell exits depends on your terminal
emulator settings. Pass `-k`/`--stay` to skip that `exit` and keep working in
the same shell after launching a GUI app.

To test the local version over an already loaded function, run from the
repository root:

```fish
source fish/fzzo.fish
fzzo
```

Run automated launch tests with simulated applications from the repository root:

```sh
python3 fish/test_open.py
```
