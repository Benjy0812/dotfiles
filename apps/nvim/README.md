# Neovim

A single `init.lua` with no plugins. It sets sane defaults and a few keymaps
so you can learn Neovim's built-in motions first. Add plugins once those feel
natural.

Look up any option or key inside Neovim with `:help <name>`, for example
`:help scrolloff` or `:help vim.keymap.set`.

## Install

Run `../../dotfiles.bash push nvim`. It
copies `init.lua` to `~/.config/nvim/init.lua`; `dotfiles.bash doctor` warns if `nvim` or a
clipboard tool (`wl-clipboard`) is missing. If a
different `init.lua` is already there (for example Omarchy's LazyVim one), it
is moved to the backup folder first
(`~/.local/state/dotfiles/backups/nvim/init.lua/`). Other LazyVim files in `~/.config/nvim/`
(`lua/`, `lazy-lock.json`) are left alone and go unused, and LazyVim's theme
hot-reload stops working. To go back, run `../../dotfiles.bash restore nvim/init.lua`. NixOS deploys
the file through home-manager ([../../nix](../../nix/README.md)).

Check what it would do with `../../dotfiles.bash push -n nvim`.

## How the file is built

Three short blocks, in this order:

1. **Leader key**: `vim.g.mapleader = " "` makes `Space` the prefix for custom
   commands. `<leader>w` means "press Space, then w". It is set first because
   mappings read the leader when they are defined.
2. **Options**: `local o = vim.opt` is a short name for the options table, so
   `o.number = true` is the same as `:set number`.
3. **Keymaps**: `local map = vim.keymap.set` is a short name for the function
   that defines a key. `map("n", "<C-h>", "<C-w>h")` means: in Normal mode,
   `Ctrl+h` runs `Ctrl+w h`.

## Options

### Display

| Option | What it does |
|---|---|
| `number = true` | Shows the line number at the left of every line. |
| `relativenumber = true` | Shows other lines as their distance from the cursor line. With `number` also on, the cursor line shows its real number and the rest show distance. You read "7 lines down" at a glance and type `7j` or `7dd`. |
| `cursorline = true` | Highlights the line the cursor is on, so you can find it quickly. |
| `scrolloff = 8` | Keeps at least 8 lines visible above and below the cursor when you scroll, so you always see context. |
| `signcolumn = "yes"` | Always reserves the narrow column left of the numbers (used for git marks and diagnostics). Without it the text jumps sideways whenever a sign appears. |
| `termguicolors = true` | Uses 24-bit colors in the terminal. Modern color schemes need it. |

### Indentation

| Option | What it does |
|---|---|
| `expandtab = true` | Pressing `Tab` inserts spaces, not a tab character. |
| `shiftwidth = 2` | One indent level is 2 columns. Used by `>>`, `<<`, `==` and auto-indent. |
| `tabstop = 2` | A tab character that is already in a file is drawn 2 columns wide. |
| `smartindent = true` | A new line copies the indent of the line above, and adds one level after a `{`. |

### Search

| Option | What it does |
|---|---|
| `ignorecase = true` | `/foo` matches `foo`, `Foo` and `FOO`. |
| `smartcase = true` | Overrides `ignorecase` when your search has a capital letter: `/Foo` matches only `Foo`. |
| `hlsearch = true` | Highlights every match after you search. Clear it with `Esc` (see keymaps). |
| `incsearch = true` | Jumps to the first match while you are still typing the search. |

### Windows, files and clipboard

| Option | What it does |
|---|---|
| `splitright = true` | `:vsplit` opens the new window on the right instead of the left. |
| `splitbelow = true` | `:split` opens the new window below instead of above. |
| `undofile = true` | Saves undo history to disk, so `u` still works after you close and reopen a file. |
| `clipboard = "unnamedplus"` | Yank (`y`), delete and paste (`p`) use the system clipboard, so you can copy between Neovim and other apps. It needs a clipboard tool such as `wl-clipboard` on Wayland or `xclip` on X11. |
| `updatetime = 250` | Waits 250 ms (default 4000) before writing the swap file and firing the idle event. Makes plugins that react to idle feel faster. |
| `timeoutlen = 400` | Waits 400 ms for the next key of a multi-key mapping such as `<leader>w` before giving up. |

## Keymaps

The first letter is the mode: `n` is Normal, `v` is Visual.

### Leader commands (Normal mode)

| Keys | What it does |
|---|---|
| `Space w` | Saves the file (`:write`). |
| `Space q` | Quits the window (`:quit`). Fails if the file has unsaved changes, which is the safe behavior. |
| `Space e` | Opens Neovim's built-in file explorer (`:Explore`) in the directory of the current file. Press `Enter` on a file to open it and `-` to go up a folder. |

### Search

| Keys | What it does |
|---|---|
| `Esc` | Clears the search highlight (`:nohlsearch`). Normal use of `Esc` is unchanged. |
| `n` / `N` | Jump to the next or previous match, then center the line on screen (`zz`) and unfold it if it was hidden in a fold (`zv`). |

### Moving around

| Keys | What it does |
|---|---|
| `Ctrl+h` / `Ctrl+j` / `Ctrl+k` / `Ctrl+l` | Move to the split on the left, below, above or right. Replaces the two-key `Ctrl+w h` and friends. |
| `Ctrl+d` / `Ctrl+u` | Scroll half a page down or up, then center the cursor line (`zz`), so you do not lose your place. |

### Editing in Visual mode

| Keys | What it does |
|---|---|
| `J` / `K` | Move the selected lines down or up, re-indent them, and keep them selected. Select lines with `V`, then press `J` or `K` repeatedly. |
| `<` / `>` | Indent the selection left or right and keep it selected (`gv` reselects), so you can press `>` several times in a row. Plain Vim drops the selection after one indent. |

## Autocommand

```lua
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank() end,
})
```

An autocommand runs a function when an event happens. `TextYankPost` fires
right after you yank (copy) text, and `vim.hl.on_yank()` briefly highlights
what you copied. It confirms what `yap` or `yiw` just grabbed. The highlight
time can be changed with `vim.hl.on_yank({ timeout = 300 })`.

## Adding your own

- **Option:** add `o.<name> = <value>` in the options block. Find names with
  `:help options`.
- **Keymap:** add `map("<mode>", "<keys>", "<command>", { desc = "..." })`.
  `desc` is the text shown by `:map` and by which-key style plugins.
- **Plugins:** Neovim 0.12 has a built-in manager, `vim.pack.add()`
  (`:help vim.pack`). Add plugins there once you know what you want.

## Check your changes

Start Neovim with this file and nothing else, without touching `~/.config`:

```bash
nvim -u apps/nvim/init.lua
```

Inside, `:verbose set shiftwidth?` shows the value and where it was set, and
`:map <space>w` shows the mapping.
