-- Persistencia del colorscheme elegido entre reinicios.
local state_file = vim.fn.stdpath("state") .. "/colorscheme.txt"
local DEFAULT = "catppuccin-mocha"

local function save_colorscheme(name)
  if name and name ~= "" then
    pcall(vim.fn.writefile, { name }, state_file)
  end
end

local function load_colorscheme()
  local ok, lines = pcall(vim.fn.readfile, state_file)
  if ok and lines and lines[1] and lines[1] ~= "" then
    return lines[1]
  end
  return DEFAULT
end

-- NOTA: los colorschemes se cargan de inmediato (lazy=false) para que el picker
-- de `<leader>uc` los liste todos y para poder restaurar el guardado al arrancar.
return {
  -- Catppuccin (default) — también orquesta la persistencia
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    opts = {
      flavour = "mocha", -- latte | frappe | macchiato | mocha
      transparent_background = false,
      integrations = {
        neotree = true,
        treesitter = true,
        telescope = { enabled = true },
        gitsigns = true,
        mason = true,
        which_key = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)

      -- Guardar la elección cada vez que cambie el colorscheme
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("ColorschemePersist", { clear = true }),
        callback = function(ev) save_colorscheme(ev.match) end,
      })

      -- Aplicar el default ya (evita flash); restaurar el guardado cuando
      -- todos los plugins de tema estén cargados.
      pcall(vim.cmd.colorscheme, DEFAULT)
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function() pcall(vim.cmd.colorscheme, load_colorscheme()) end,
      })
    end,
  },

  -- Tokyo Night
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night", -- night | storm | moon | day
      transparent = false,
    },
  },

  -- Rose Pine
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    opts = { variant = "main" }, -- main | moon | dawn
  },

  -- Gruvbox
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    opts = { contrast = "hard" },
  },

  -- Kanagawa
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
  },
}
