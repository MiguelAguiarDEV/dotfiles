return {
  -- Mason: instala/gestiona los servidores LSP
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    opts = {
      ui = { border = "rounded" },
    },
  },

  -- Puente entre Mason y lspconfig
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      ensure_installed = { "lua_ls", "gopls" },
      -- automatic_enable = true por defecto (habilita los servidores vía vim.lsp.enable)
    },
  },

  -- Configuración de los servidores LSP
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      -- Diagnostics: virtual text + ordenar por severidad
      vim.diagnostic.config({
        float = { source = true },
        virtual_text = true,
        severity_sort = true,
      })

      -- Configurar servidores instalados
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = { enable = false },
          },
        },
      })

      -- Atajos cuando un LSP se conecta a un buffer
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local bufnr = args.buf
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end

          map("n", "K",  vim.lsp.buf.hover,          "Hover (info)")
          map("n", "gd", vim.lsp.buf.definition,     "Go to definition")
          map("n", "gD", vim.lsp.buf.declaration,    "Go to declaration")
          map("n", "gr", vim.lsp.buf.references,     "References")
          map("n", "gi", vim.lsp.buf.implementation, "Implementation")
          map("n", "gt", vim.lsp.buf.type_definition,"Type definition")

          map("n", "<leader>rn", vim.lsp.buf.rename,      "Rename symbol")
          map({"n","v"}, "<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("n", "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, "Format file")

          -- Auto-hover: cuando el cursor se queda quieto, mostrar info como en VSCode
          if vim.g.auto_hover_enabled == nil then
            vim.g.auto_hover_enabled = true
          end
          local hover_group = vim.api.nvim_create_augroup("AutoHover_" .. bufnr, { clear = true })
          vim.api.nvim_create_autocmd("CursorHold", {
            group = hover_group,
            buffer = bufnr,
            callback = function()
              if not vim.g.auto_hover_enabled then return end
              -- No abrir si ya hay un popup flotante visible
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_config(win).relative ~= "" then return end
              end
              vim.lsp.buf.hover()
            end,
          })

          -- Toggle del auto-hover
          map("n", "<leader>th", function()
            vim.g.auto_hover_enabled = not vim.g.auto_hover_enabled
            vim.notify(
              "Auto-hover: " .. (vim.g.auto_hover_enabled and "ON" or "OFF"),
              vim.log.levels.INFO
            )
          end, "Toggle auto-hover")
        end,
      })
    end,
  },
}
