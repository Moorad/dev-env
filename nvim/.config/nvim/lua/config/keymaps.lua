-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<leader><space>", LazyVim.pick("find_files", { root = false }), { desc = "Find Files (cwd)" })
vim.keymap.set("n", "<leader>/", LazyVim.pick("live_grep", { root = false }), { desc = "Grep (cwd)" })

vim.keymap.set("n", "<leader>e", LazyVim.pick("explorer", { root = false }), { desc = "Explorer Snacks (cwd)" })
vim.keymap.set("n", "<leader>E", LazyVim.pick("explorer", { root = false }), { desc = "Explorer Snacks (root dir)" })

vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })

vim.keymap.set("n", "<leader>fy", function()
  vim.fn.setreg("+", vim.fn.expand("%:f"))
  print("Copied: " .. vim.fn.expand("%:f"))
end, { desc = "Copy file path" })
