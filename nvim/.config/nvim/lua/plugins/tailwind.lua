return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tailwindcss = {
          settings = {
            tailwindCSS = {
              classAttributes = {
                "class",
                "className",
                "class:list",
                "classList",
                "ngClass",
                "classNames",
                "tv",
              },
            },
          },
        },
      },
    },
  },
}
