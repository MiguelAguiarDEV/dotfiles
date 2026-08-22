-- Autocomandos
-- =====================================
local augroup = vim.api.nvim_create_augroup

-- Highlight de la winbar (se redefine tras cada colorscheme para que sobreviva)
local function set_winbar_hl()
  vim.api.nvim_set_hl(0, "WinBarPath", { link = "Directory", default = true })
end
set_winbar_hl()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup("WinBarHl", { clear = true }),
  callback = set_winbar_hl,
})

-- Winbar: ruta del archivo en la parte superior de cada ventana
-- %f = ruta relativa  |  %m = modificado [+]  |  %r = readonly
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  group = augroup("Winbar", { clear = true }),
  callback = function()
    local ft = vim.bo.filetype
    -- No mostrar winbar en buffers especiales (neo-tree, telescope, popups, etc.)
    if ft == "" or ft == "neo-tree" or ft == "TelescopePrompt" or ft == "lazy"
        or ft == "mason" or ft == "help" or vim.bo.buftype ~= "" then
      vim.opt_local.winbar = ""
    else
      vim.opt_local.winbar = "%#WinBarPath# %f %m%r"
    end
  end,
})

-- Al abrir nvim con una carpeta (`nvim .`), arrancar con neo-tree enfocado
vim.api.nvim_create_autocmd("VimEnter", {
  group = augroup("OpenDirWithNeotree", { clear = true }),
  callback = function()
    local arg = vim.fn.argv(0)
    if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
      -- Capturar el buffer del directorio que crea nvim por defecto
      local dir_buf = vim.api.nvim_get_current_buf()
      -- Asegurar cwd correcto y abrir neo-tree con foco
      vim.cmd("cd " .. vim.fn.fnameescape(arg))
      vim.cmd("Neotree focus")
      -- Borrar el buffer-directorio residual (sin hardcodear su número)
      if vim.api.nvim_buf_is_valid(dir_buf) then
        pcall(vim.api.nvim_buf_delete, dir_buf, { force = true })
      end
    end
  end,
})
