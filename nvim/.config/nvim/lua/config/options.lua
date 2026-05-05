-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.o.ignorecase = true
vim.opt.wrap = true
vim.g.snacks_animate = false

vim.g.lazyvim_prettier_needs_config = true
vim.g.prettier_additional_supported_filetypes = { "javascript.glimmer", "typescript.glimmer" }
