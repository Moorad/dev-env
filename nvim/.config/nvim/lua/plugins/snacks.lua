return {
  {
    "snacks.nvim",
    opts = {
      scroll = {
        enabled = false,
      },
      picker = {
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
        },
      },
    },
  },
}
