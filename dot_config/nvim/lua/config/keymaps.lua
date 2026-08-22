-- Keymaps globales
-- =====================================
local map = vim.keymap.set

-- Limpiar búsqueda con Esc
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Moverse entre ventanas con Ctrl+hjkl
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Mover líneas en modo visual
map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

-- Mantener cursor centrado al scrollear
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Mejor pegar sobre selección (no pierde el registro)
map("x", "<leader>p", '"_dP')

-- Guardar / cerrar
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Close window" })

-- Picker de proyectos
map("n", "<leader>fp", function() require("projects").pick() end, { desc = "Projects" })

-- Toggle soft wrap (como Alt+Z en VSCode)
map("n", "<leader>uw", function()
  vim.opt.wrap = not vim.opt.wrap:get()
  vim.notify("Wrap: " .. (vim.opt.wrap:get() and "ON" or "OFF"), vim.log.levels.INFO)
end, { desc = "Toggle word wrap" })

-- Buffers (con leader)
map("n", "<leader>bn", "<cmd>bnext<CR>",     { desc = "Buffer next" })
map("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "Buffer prev" })
map("n", "<leader>bb", "<cmd>e #<CR>",       { desc = "Buffer alternate (último visitado)" })
map("n", "<leader>bd", "<cmd>bd<CR>",        { desc = "Buffer delete" })

-- Diagnósticos: Neovim ya provee [d / ]d por defecto (0.10+).
-- Mantenemos un par útil con la API nueva (vim.diagnostic.jump):
map("n", "<leader>dl", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "<leader>dq", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })
