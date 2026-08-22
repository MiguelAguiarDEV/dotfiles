return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- la rama main NO soporta lazy-loading
  build = ":TSUpdate",
  config = function()
    local ensure = {
      "lua", "vim", "vimdoc", "bash",
      "json", "yaml", "toml", -- .jsonc usa el parser json vía filetype
      "markdown", "markdown_inline",
      "html", "css",
      "javascript", "typescript", "tsx",
      "python", "go",
    }

    -- Instala/actualiza parsers (asíncrono; no-op si ya están).
    -- En la rama main los parsers se compilan en stdpath('data')/site.
    require("nvim-treesitter").install(ensure)

    -- Sustituye a los antiguos módulos highlight.enable / indent.enable.
    -- En la rama main el resaltado lo arranca Neovim con vim.treesitter.start().
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        local buf = args.buf
        local ft = vim.bo[buf].filetype
        local lang = vim.treesitter.language.get_lang(ft)
        if not lang then
          return
        end
        -- Solo arranca si hay parser disponible para ese lenguaje.
        local ok, loaded = pcall(vim.treesitter.language.add, lang)
        if not (ok and loaded) then
          return
        end
        vim.treesitter.start(buf, lang)
        -- Indentación por treesitter (experimental en la rama main).
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
