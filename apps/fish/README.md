# Fish

[Fish](https://fishshell.com/) shell config, used by the session and Kitty.

| File | What |
|---|---|
| `config.fish` | Sets `$SHELL` to fish, bun, and `PATH` (`~/.local/bin`, bun) |
| `conf.d/aliases.fish` | `l`, `ll`, `la`; colored `grep`; `cp`/`mv`/`rm` ask before overwriting |
| `conf.d/abbreviations.fish` | Expand as you type: git (`gs`, `ga`, `gc`, ...), folders (`home`, `conf`, `proj`), bun (`buni`, `bund`, `bunb`, ...) |
| `conf.d/theme.fish` | Syntax colors |
| `conf.d/extract.fish` | `extract <file>`: unpack any archive format |
| `conf.d/mkcd.fish` | `mkcd <dir>`: make a directory and enter it |
| `conf.d/paru.fish` | `paru <query> <n>`: a trailing number limits the results |
| `functions/y.fish` | `y`: open Yazi and `cd` to where you quit it |
| `functions/br.fish` | `br`: [broot](https://dystroy.org/broot/) launcher; a link to the one broot installs, so it needs broot |
| `completions/bun.fish` | Bun completions |

`fish_variables` is rewritten by fish at runtime and not tracked.
