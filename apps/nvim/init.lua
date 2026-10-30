-- Plain Neovim, no plugins: learn the built-in motions first.
-- Docs for any option or key: :help <name>

vim.g.mapleader = " "

local o = vim.opt
o.number = true         -- line numbers
o.relativenumber = true -- distance to other lines, so 5j / 3dd are easy to count
o.cursorline = true
o.scrolloff = 8         -- keep context above and below the cursor
o.signcolumn = "yes"
o.termguicolors = true

o.expandtab = true -- tabs become spaces
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true

o.ignorecase = true -- search is case-insensitive unless it has a capital
o.smartcase = true
o.hlsearch = true
o.incsearch = true

o.splitright = true
o.splitbelow = true
o.undofile = true -- undo survives closing the file
o.clipboard = "unnamedplus" -- yank and paste use the system clipboard
o.updatetime = 250
o.timeoutlen = 400

local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit" })

-- Move between splits with Ctrl + h/j/k/l
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Keep the cursor centered when scrolling and searching
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Move selected lines up/down
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Keep the selection when indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Built-in file explorer
map("n", "<leader>e", "<cmd>Explore<cr>", { desc = "File explorer" })

-- Flash the text you just yanked
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank() end,
})
