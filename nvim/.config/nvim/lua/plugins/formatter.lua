return {
  "stevearc/conform.nvim",
  ---@module "conform"
  ---@type conform.setupOpts
  opts = {
    formatters_by_ft = {
      javascript = { "prettierd", "prettier", stop_after_first = true },
      javascriptreact = { "prettierd", "prettier", stop_after_first = true },
      typescript = { "prettierd", "prettier", stop_after_first = true },
      typescriptreact = { "prettierd", "prettier", stop_after_first = true },
    },
  },
}
