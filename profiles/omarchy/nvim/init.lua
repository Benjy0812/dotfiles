-- LazyVim (Omarchy default): lazy.nvim, plugins and blink.cmp autocomplete
-- are set up in ~/.config/nvim/lua/config/lazy.lua.
require("config.lazy")

-- Rust language server. Needs rust-analyzer on PATH.
vim.lsp.config("rust_analyzer", {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  root_markers = { "Cargo.toml" },
})
vim.lsp.enable("rust_analyzer")
