# fzzopen

A fuzzy file and directory picker powered by `fzf`, with application selection
based on the file's MIME type. The project is named **fzzopen**; run it with
the **`fzzo`** command.

## Structure

- **[fish/](fish/)** — the active implementation: a native fish function.
  It runs in the current shell process, so `cd` changes the shell's working
  directory. See [fish/README.md](fish/README.md) for installation and usage.
- **[python-binary/](python-binary/)** — an abandoned experiment to rewrite the
  tool in Python and distribute it as a standalone binary using PyInstaller
  for use with any shell. A subprocess cannot change its parent shell's working
  directory, which is why the native fish implementation replaced it.
  Kept for historical reference.

## Recommendation

Use [fish/fzzo.fish](fish/fzzo.fish). Future support for other shells such as
bash or zsh should follow the approach used by tools like `zoxide`, `direnv`,
and `broot`: a program that prints the selected path, wrapped in a small shell
function that runs `cd` in the current process.
