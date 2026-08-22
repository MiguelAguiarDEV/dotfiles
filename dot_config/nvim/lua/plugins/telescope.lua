return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- Sorter nativo en C: ordenado mucho más rápido (requiere make + cc)
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  cmd = "Telescope",
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<cr>",  desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<cr>",   desc = "Grep in project" },
    { "<leader>fb", "<cmd>Telescope buffers<cr>",     desc = "Open buffers" },
    { "<leader>fr", "<cmd>Telescope oldfiles<cr>",    desc = "Recent files" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>",   desc = "Help tags" },
    { "<leader>fk", "<cmd>Telescope keymaps<cr>",     desc = "Keymaps" },
    { "<leader>/",  "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Search in file" },
    { "<leader>uc", "<cmd>Telescope colorscheme enable_preview=true<cr>", desc = "Colorscheme picker" },
  },
  opts = {
    defaults = {
      layout_strategy = "horizontal",
      layout_config = { prompt_position = "top" },
      sorting_strategy = "ascending",
      path_display = { "truncate" },
      file_ignore_patterns = { "%.git/", "node_modules/" },
    },
    pickers = {
      -- fd: respeta .gitignore, oculta .git, más rápido que el find por defecto
      find_files = {
        hidden = true,
        find_command = { "fd", "--type", "f", "--hidden", "--exclude", ".git" },
      },
    },
    extensions = {
      fzf = {
        fuzzy = true,
        override_generic_sorter = true,
        override_file_sorter = true,
        case_mode = "smart_case",
      },
    },
  },
  config = function(_, opts)
    local telescope = require("telescope")
    telescope.setup(opts)
    pcall(telescope.load_extension, "fzf")
  end,
}
