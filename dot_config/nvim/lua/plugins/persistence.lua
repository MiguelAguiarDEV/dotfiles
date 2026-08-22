return {
  "folke/persistence.nvim",
  event = "BufReadPre",
  opts = {
    -- Qué se guarda se controla con vim.o.sessionoptions (ver config/options.lua).
    -- Borrar buffers de neo-tree antes de guardar (que no entren en la sesión)
    pre_save = function()
      pcall(vim.cmd, "Neotree close")
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "neo-tree" then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end,
  },
}
