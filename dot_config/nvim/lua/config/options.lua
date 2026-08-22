-- Opciones generales
-- =====================================

-- Desactivar netrw (usamos neo-tree) — debe ir antes de cargar plugins
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local opt = vim.opt

opt.number = true           -- Números de línea
opt.relativenumber = true   -- Números relativos
opt.cursorline = true       -- Resaltar línea actual
opt.signcolumn = "yes"      -- Columna de signos siempre visible

opt.tabstop = 4             -- Tab = 4 espacios
opt.shiftwidth = 4          -- Indentación = 4 espacios
opt.expandtab = true        -- Usar espacios en vez de tabs
opt.smartindent = true      -- Indentación inteligente

opt.wrap = false            -- No hacer wrap de líneas largas
opt.linebreak = true        -- Si se activa wrap, partir por palabras (no a mitad)
opt.breakindent = true      -- Líneas envueltas mantienen la indentación
opt.scrolloff = 8           -- Mantener 8 líneas de contexto
opt.sidescrolloff = 8

opt.ignorecase = true       -- Búsqueda sin importar mayúsculas
opt.smartcase = true        -- ...a menos que uses mayúsculas
opt.hlsearch = true         -- Resaltar resultados de búsqueda
opt.incsearch = true        -- Búsqueda incremental

opt.splitbelow = true       -- Splits nuevos abajo
opt.splitright = true       -- Splits nuevos a la derecha

opt.termguicolors = true    -- Colores 24-bit
opt.background = "dark"

opt.undofile = true         -- Undo persistente
opt.swapfile = false        -- Sin archivos swap
opt.backup = false          -- Sin backups

opt.updatetime = 250        -- Más rápido para CursorHold
opt.timeoutlen = 300        -- Timeout para secuencias de teclas

opt.mouse = "a"             -- Mouse habilitado

opt.showmode = false        -- No mostrar modo (ya se ve en statusline)
opt.laststatus = 3          -- Statusline global

opt.winborder = "rounded"   -- Borde redondeado en TODAS las ventanas flotantes (hover LSP, etc.)

-- Qué guarda persistence.nvim en cada sesión.
-- (persistence.nvim ya NO acepta opts.options: lee directamente sessionoptions)
opt.sessionoptions = "buffers,curdir,tabpages,winsize,help,globals,skiprtp,folds"

-- Clipboard del sistema
opt.clipboard = "unnamedplus"

-- En WSL, puente al portapapeles de Windows vía win32yank (rápido; evita powershell)
if vim.fn.has("wsl") == 1 then
  vim.g.clipboard = {
    name = "win32yank",
    copy = {
      ["+"] = "win32yank.exe -i --crlf",
      ["*"] = "win32yank.exe -i --crlf",
    },
    paste = {
      ["+"] = "win32yank.exe -o --lf",
      ["*"] = "win32yank.exe -o --lf",
    },
    cache_enabled = 0,
  }
end
