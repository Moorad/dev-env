return {
  {
    "snacks.nvim",
    ---@type snacks.Config
    opts = {
      scroll = {
        enabled = false,
      },
      picker = {
        matcher = {
          smartcase = false,
          ignorecase = true,
        },
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            layout = {
              layout = {
                position = "right",
              },
            },
          },
          files = {
            hidden = true,
            ignored = false,
          },
          live_grep = {
            hidden = true,
          },
        },
      },
    },
  },
}
