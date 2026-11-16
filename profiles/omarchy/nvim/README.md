# Neovim

Omarchy uses LazyVim. `init.lua` is two things: `require("config.lazy")`, which
loads lazy.nvim and LazyVim from `~/.config/nvim/lua/` (shipped by Omarchy, not
tracked here), and a rust-analyzer LSP setup that needs `rust-analyzer` on PATH.

Autocomplete comes from LazyVim's blink.cmp. `Tab` / `Enter` accept, `Ctrl+e`
dismisses. `<leader>` is Space; press it and wait for the which-key menu.
Run `:Lazy` to manage plugins and `:LazyExtras` to enable language extras.
Docs for any option or key: `:help <name>`.

## Install

Run `../../dotfiles.bash link` to link the profile, `init.lua` included, into
`~/.config/nvim/`. If a different `init.lua` is already there, use `adopt` once and
review with `git diff`. Preview with `../../dotfiles.bash link -n`.

The plain, plugin-free config used on other profiles is in
[../../../apps/nvim](../../../apps/nvim/README.md).
