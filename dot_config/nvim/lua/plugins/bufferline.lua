return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  opts = {
    options = {
      mode = "buffers",
      diagnostics = "nvim_lsp",
      diagnostics_indicator = function(count, level)
        local icon = level:match("error") and "✘" or "▲"
        return " " .. icon .. count
      end,
      offsets = {
        {
          filetype = "neo-tree",
          text = "Explorer",
          separator = true,
          text_align = "left",
        },
      },
      show_buffer_close_icons = false,
      show_close_icon = false,
      separator_style = "thin",
      always_show_bufferline = true,
      indicator = { style = "underline" },
      -- Comportamiento del ratón: click izquierdo enfoca, medio cierra, derecho no hace nada
      left_mouse_command = "buffer %d",
      right_mouse_command = false, -- false (no nil) para realmente desactivarlo
      middle_mouse_command = "bdelete! %d",
    },
  },
}
