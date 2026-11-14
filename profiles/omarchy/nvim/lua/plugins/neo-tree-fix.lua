-- Neo-tree crashes with "duplicate node id" when hidden files are shown and a
-- gitignored file shares a name prefix with an untracked one (e.g. todo.md and
-- todo.md_hidden_message). Showing gitignored files avoids the bug.
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = { filtered_items = { hide_gitignored = false } },
  },
}
