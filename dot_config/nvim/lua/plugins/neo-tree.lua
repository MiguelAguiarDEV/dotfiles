return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  lazy = true,
  cmd = "Neotree",
  keys = {
    {
      "<leader>E",
      "<cmd>Neotree toggle reveal<cr>",
      desc = "Explorer (toggle window)",
    },
    {
      "<leader>e",
      function()
        if vim.bo.filetype == "neo-tree" then
          vim.cmd("wincmd p")
        else
          vim.cmd("Neotree focus")
        end
      end,
      desc = "Explorer (toggle focus)",
    },
  },
  opts = {
    close_if_last_window = true,
    window = {
      width = 32,
      mappings = {
        ["<space>"] = "none",  -- liberar leader dentro del árbol
        ["f"]       = "none",  -- desactivar filter
        ["/"]       = "none",  -- desactivar fuzzy filter
      },
    },
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      filtered_items = {
        visible = false,
        hide_dotfiles = false,
        hide_gitignored = true,
      },
    },
    default_component_configs = {
      indent = { with_markers = true },
      git_status = {
        symbols = {
          added = "+", modified = "~", deleted = "-", renamed = "→",
          untracked = "?", ignored = "i", unstaged = "u", staged = "s", conflict = "!",
        },
      },
    },
  },
}
