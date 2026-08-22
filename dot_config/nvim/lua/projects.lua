-- Picker simple de proyectos.
-- Escanea carpetas configuradas, muestra solo directorios.
-- Al seleccionar: cd + cierra buffers + abre neo-tree.

local M = {}

-- EDITAR AQUÍ para añadir más carpetas a escanear (acepta globs).
local PROJECT_GLOBS = {
  "~/Work/*",
  "~/Work/*/projects/*",
  "~/projects/*",
  "~/.config/nvim",
  "~/.local/share/chezmoi",
  "~/Work/BySidecar2/projects/*"
}

local function list_dirs()
  local seen = {}
  local dirs = {}
  for _, glob in ipairs(PROJECT_GLOBS) do
    local matches = vim.fn.glob(glob, false, true)
    for _, path in ipairs(matches) do
      if vim.fn.isdirectory(path) == 1 and not seen[path] then
        seen[path] = true
        table.insert(dirs, path)
      end
    end
  end
  return dirs
end

local function session_file_for(cwd)
  local dir = vim.fn.stdpath("state") .. "/sessions/"
  local name = cwd:gsub("/", "%%") .. ".vim"
  return dir .. name
end

local function wipe_neotree_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      local ft = vim.bo[buf].filetype
      if ft == "neo-tree" or name:match("neo%-tree") then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

local function open_project(path)
  local persistence = require("persistence")

  -- 1) Cerrar neo-tree y guardar sesión del proyecto actual
  pcall(vim.cmd, "Neotree close")
  pcall(function() persistence.save() end)

  -- 2) Cerrar todos los buffers, incluido cualquier residuo de neo-tree
  vim.cmd("silent! %bdelete!")
  wipe_neotree_buffers()

  -- 3) Cambiar al nuevo directorio
  vim.cmd("cd " .. vim.fn.fnameescape(path))

  -- 4) Cargar sesión del nuevo proyecto si existe; si no, neo-tree limpio
  local session_path = session_file_for(vim.fn.getcwd())
  if vim.fn.filereadable(session_path) == 1 then
    pcall(function() persistence.load() end)
    -- Forzar cwd al proyecto raíz (la sesión puede haberlo dejado en un subdir)
    vim.cmd("cd " .. vim.fn.fnameescape(path))
    -- Limpiar fantasmas y abrir neo-tree con la raíz del proyecto (NO reveal)
    vim.defer_fn(function()
      wipe_neotree_buffers()
      vim.cmd("cd " .. vim.fn.fnameescape(path))
      pcall(vim.cmd, "Neotree show dir=" .. vim.fn.fnameescape(path))
    end, 80)
  else
    pcall(vim.cmd, "Neotree show dir=" .. vim.fn.fnameescape(path))
  end

  vim.notify("📁 " .. vim.fn.fnamemodify(path, ":~"), vim.log.levels.INFO)
end

function M.pick()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf    = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Projects",
    finder = finders.new_table({
      results = list_dirs(),
      entry_maker = function(entry)
        local short = vim.fn.fnamemodify(entry, ":~")
        local name = vim.fn.fnamemodify(entry, ":t")
        local parent = vim.fn.fnamemodify(entry, ":h:t")
        return {
          value = entry,
          display = name .. "  " .. short,
          ordinal = name .. " " .. parent,
          path = entry,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then open_project(entry.value) end
      end)
      return true
    end,
  }):find()
end

return M
