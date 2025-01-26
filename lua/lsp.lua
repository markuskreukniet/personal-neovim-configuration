return {
  -- A plugin for managing LSP servers, DAP servers, linters, and formatters,
  -- simplifying their installation and configuration.
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup()
    end
  },

  -- This plugin simplifies the management and configuration of LSP servers
  -- by integrating 'Mason' with 'nvim-lspconfig' for automatic setup.
  {
    "williamboman/mason-lspconfig.nvim",
    -- "neovim/nvim-lspconfig" is one of the most popular plugins and is enough to have it only as a dependency.
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls" },
        automatic_installation = true
      })

      -- Configures the Lua Language Server
      require("lspconfig").lua_ls.setup({
        settings = {
          Lua = {
            runtime = {
                -- Specifies the Lua runtime version (Neovim uses LuaJIT for better performance).
              version = "LuaJIT",
                -- Splits Lua's module search paths into a table for the language server,
                -- ensuring it can resolve required modules correctly.
              path = vim.split(package.path, ";")
            },
            -- It prevents 'undefined global' warnings for the Neovim 'vim' global.
            diagnostics = {
              globals = { "vim" }
            },
            workspace = {
              -- Expand the workspace library by combining Neovim runtime files and external libraries
              -- to provide better API support for the Lua language server.
              library = vim.tbl_extend(
                "force",
                vim.api.nvim_get_runtime_file("", true),
                { "${3rd}/luv/library" }
              ),
              -- It turns off the automatic detection of third-party libraries or configurations
              -- to avoid unnecessary warnings or conflicts.
              checkThirdParty = false
            },
            -- It turns off telemetry to prevent the collection of usage and diagnostics data,
            -- ensuring better privacy and performance.
            telemetry = {
              enable = false
            }
          }
        }
      })
    end
  }
}
