return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern",
    delay = 300,
    spec = {
      { "<leader>f", group = "Find" },
      { "<leader>g", group = "Git" },
      { "<leader>b", group = "Buffers" },
      { "<leader>l", group = "LSP / Format" },
      { "<leader>d", group = "Diagnostics" },
      { "<leader>u", group = "UI / Toggles" },
      { "<leader>t", group = "Toggles" },
      { "<leader>c", group = "Code" },
      { "<leader>r", group = "Rename" },
      { "gp", group = "Goto-preview" },
    },
  },
  keys = {
    {
      "<leader>?",
      function() require("which-key").show({ global = false }) end,
      desc = "Buffer keymaps (which-key)",
    },
  },
}
