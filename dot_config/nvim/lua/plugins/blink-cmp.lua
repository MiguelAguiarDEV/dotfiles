return {
  "saghen/blink.cmp",
  version = "1.*",
  event = "InsertEnter",
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = {
    -- Atajos estilo VSCode: Tab/Shift+Tab navegan + aceptan
    keymap = { preset = "super-tab" },

    appearance = {
      nerd_font_variant = "mono",
    },

    completion = {
      -- Documentación auto al lado del menú
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
      },
      -- Menú con bordes
      menu = {
        border = "rounded",
        draw = { treesitter = { "lsp" } },
      },
      -- Aceptar el primer item con Tab si no hay nada seleccionado
      list = { selection = { preselect = false, auto_insert = true } },
      -- Ghost text (texto fantasma estilo Copilot, pero del LSP)
      ghost_text = { enabled = true },
    },

    signature = {
      enabled = true,
      window = { border = "rounded" },
    },

    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
  },
  opts_extend = { "sources.default" },
}
