# Neovim

Omarchy uses LazyVim. `init.lua` is two things: `require("config.lazy")`, which
loads lazy.nvim and LazyVim from `~/.config/nvim/lua/` (shipped by Omarchy, not
tracked here), and a rust-analyzer LSP setup that needs `rust-analyzer` on PATH.

Autocomplete comes from LazyVim's blink.cmp. `Tab` / `Enter` accept, `Ctrl+e`
dismisses. `<leader>` is Space; press it and wait for the which-key menu.
Run `:Lazy` to manage plugins and `:LazyExtras` to enable language extras.
Docs for any option or key: `:help <name>`.

## Install

Run `../../dotfiles.bash push nvim`. It copies `init.lua` to
`~/.config/nvim/init.lua`; an existing different one is moved to
`~/.local/state/dotfiles/backups/nvim/init.lua/` first. Restore it with
`../../dotfiles.bash restore nvim/init.lua`. Preview with
`../../dotfiles.bash push -n nvim`.

The plain, plugin-free config used on other profiles is in
[../../../apps/nvim](../../../apps/nvim/README.md).
