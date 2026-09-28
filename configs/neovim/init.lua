return {
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      require("configs.lspconfig")
    end,
  },

  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "lua",
        "vim",
        "vimdoc",
        "python",
        "c",
        "cpp",
        "cmake",
        "rust",
        "json",
        "yaml",
        "toml",
        "bash",
        "markdown",
      },
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
  },

  {
    "hedyhli/outline.nvim",
    cmd = { "Outline", "OutlineOpen" },
    opts = {},
  },

  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",
    opts = {},
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
  },

  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    config = true,
  },

  {
    "linux-cultist/venv-selector.nvim",
    branch = "regexp",
    cmd = {
      "VenvSelect",
      "VenvSelectCached",
    },
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },

  {
    "Civitasv/cmake-tools.nvim",
    ft = {
      "c",
      "cpp",
      "cmake",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {},
  },

  {
    "mfussenegger/nvim-dap",
  },

  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      require("dapui").setup()
    end,
  },
}