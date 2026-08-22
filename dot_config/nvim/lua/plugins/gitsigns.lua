return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    signs = {
      add          = { text = "+" },
      change       = { text = "~" },
      delete       = { text = "_" },
      topdelete    = { text = "‾" },
      changedelete = { text = "~" },
      untracked    = { text = "?" },
    },
    signcolumn = true,
    numhl      = false,
    current_line_blame = false,
    on_attach = function(bufnr)
      local gs = require("gitsigns")
      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end

      map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
      map("n", "[h", function() gs.nav_hunk("prev") end, "Prev hunk")

      map("n", "<leader>gp", gs.preview_hunk,            "Preview hunk")
      map("n", "<leader>gs", gs.stage_hunk,              "Stage hunk")
      map("n", "<leader>gr", gs.reset_hunk,              "Reset hunk")
      map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
      map("n", "<leader>gd", gs.diffthis,                "Diff against index")
      map("n", "<leader>gB", function() gs.toggle_current_line_blame() end, "Toggle line blame")
    end,
  },
}
